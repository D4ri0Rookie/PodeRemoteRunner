#Requires -Version 7.0

<#
    RrLogging.psm1 - Centralized structured logging for PodeRemoteRunner.

    Design goals (replaces the duplicated Write-ServerLog / Write-InternalLog /
    Write-ExecutionLog / Write-SshLog / Write-JobLog functions with one source):

      * Timestamps : UTC, ISO-8601 with milliseconds and explicit 'Z'
                     (e.g. 2025-08-28T14:30:15.123Z).
      * File       : JSON Lines (one compact JSON object per line) -> parsable.
      * Console    : single colored line -> human-friendly live debugging.
      * Levels     : INFO / WARN / ERROR (alternate spellings are normalized).

    This module is meant to be imported in every execution context:
      - the top-level server script               -> Import-Module
      - the Start-PodeServer runspace + routes     -> Import-PodeModule
      - Start-Job child processes (parallel work)  -> Import-Module

    File writes never throw: a logging failure must not take down a request.
#>

Set-StrictMode -Version Latest

# --- Internal lookup tables ---------------------------------------------------

$script:LevelMap = @{
    'INFO'        = 'INFO'
    'INFORMATION' = 'INFO'
    'WARN'        = 'WARN'
    'WARNING'     = 'WARN'
    'ERROR'       = 'ERROR'
    'ERR'         = 'ERROR'
}

$script:LevelColor = @{
    'INFO'  = 'Gray'
    'WARN'  = 'Yellow'
    'ERROR' = 'Red'
}

# Reserved core fields that callers cannot override via -Data.
$script:ReservedFields = @('timestamp', 'level', 'message')

# --- Helpers ------------------------------------------------------------------

function Get-RrTimestamp {
    <#
    .SYNOPSIS
        Returns the current time as a UTC ISO-8601 string with milliseconds.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return [DateTime]::UtcNow.ToString(
        'yyyy-MM-ddTHH:mm:ss.fffZ',
        [System.Globalization.CultureInfo]::InvariantCulture
    )
}

function ConvertTo-RrLevel {
    [CmdletBinding()]
    [OutputType([string])]
    param([string] $Level)

    if ([string]::IsNullOrWhiteSpace($Level)) { return 'INFO' }
    $key = $Level.Trim().ToUpperInvariant()
    if ($script:LevelMap.ContainsKey($key)) { return $script:LevelMap[$key] }
    return 'INFO'
}

function Get-RrEntryField {
    # Reads a field from a log entry regardless of its concrete type.
    # A record built here is an OrderedDictionary, but once returned from a
    # Start-Job it is deserialized into a Hashtable or PSCustomObject.
    [CmdletBinding()]
    param($Entry, [string] $Name, $Default = $null)

    if ($null -eq $Entry) { return $Default }

    if ($Entry -is [System.Collections.IDictionary]) {
        if ($Entry.Contains($Name)) { return $Entry[$Name] }
        return $Default
    }

    $prop = $Entry.PSObject.Properties[$Name]
    if ($prop) { return $prop.Value }
    return $Default
}

# --- Public API ---------------------------------------------------------------

function New-RrLogEntry {
    <#
    .SYNOPSIS
        Builds a structured log record (ordered) WITHOUT performing any I/O.
    .DESCRIPTION
        Use this inside Start-Job child processes to collect entries in memory,
        then return them to the parent which flushes them in order with
        Write-RrLogEntry. Keeping a single writer per file avoids interleaved /
        raced writes from parallel jobs.
    .PARAMETER Message
        Human-readable message.
    .PARAMETER Level
        INFO (default) / WARN / ERROR. Alternate spellings are normalized.
    .PARAMETER Data
        Optional extra structured fields (e.g. traceId, server, host, ip).
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory, Position = 0)] [AllowEmptyString()] [string] $Message,
        [string]    $Level = 'INFO',
        [hashtable] $Data
    )

    $entry = [ordered]@{
        timestamp = Get-RrTimestamp
        level     = ConvertTo-RrLevel $Level
        message   = $Message
    }

    if ($Data) {
        foreach ($key in $Data.Keys) {
            if ($script:ReservedFields -contains $key) { continue }
            $entry[$key] = $Data[$key]
        }
    }

    return $entry
}

function Write-RrLogEntry {
    <#
    .SYNOPSIS
        Persists a pre-built entry as one JSON line and echoes it to the console.
    .DESCRIPTION
        Preserves the entry's original timestamp/level. Used by the parent to
        flush entries returned by jobs, and internally by Write-RrLog.
    .PARAMETER Entry
        A record from New-RrLogEntry (or its deserialized form from a job).
    .PARAMETER Path
        Optional JSONL file to append to. If omitted, console only.
    .PARAMETER NoConsole
        Suppress the console echo (file-only).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Entry,
        [string] $Path,
        [switch] $NoConsole
    )

    $timestamp = Get-RrEntryField -Entry $Entry -Name 'timestamp' -Default (Get-RrTimestamp)
    $level     = Get-RrEntryField -Entry $Entry -Name 'level'     -Default 'INFO'
    $message   = Get-RrEntryField -Entry $Entry -Name 'message'   -Default ''

    if ($Path) {
        try {
            $dir = Split-Path -Path $Path -Parent
            if ($dir -and -not (Test-Path -LiteralPath $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
            $json = $Entry | ConvertTo-Json -Compress -Depth 8
            Add-Content -LiteralPath $Path -Value $json -Encoding utf8 -ErrorAction Stop
        }
        catch {
            # A logging failure must never break the caller.
            Write-Host "[logging] write failed for '$Path': $($_.Exception.Message)" -ForegroundColor DarkYellow
        }
    }

    if (-not $NoConsole) {
        $color = if ($script:LevelColor.ContainsKey($level)) { $script:LevelColor[$level] } else { 'Gray' }
        Write-Host ("[{0}] [{1,-5}] {2}" -f $timestamp, $level, $message) -ForegroundColor $color
    }
}

function Write-RrLog {
    <#
    .SYNOPSIS
        Builds, persists and echoes a structured log entry in one call.
    .PARAMETER Message
        Human-readable message.
    .PARAMETER Level
        INFO (default) / WARN / ERROR.
    .PARAMETER Path
        Optional JSONL file to append to. If omitted, console only.
    .PARAMETER Data
        Optional extra structured fields (traceId, server, ip, ...).
    .PARAMETER NoConsole
        Suppress the console echo (file-only).
    .OUTPUTS
        The structured entry, so callers may also collect / return it.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)] [AllowEmptyString()] [string] $Message,
        [string]    $Level = 'INFO',
        [string]    $Path,
        [hashtable] $Data,
        [switch]    $NoConsole
    )

    $entry = New-RrLogEntry -Message $Message -Level $Level -Data $Data
    Write-RrLogEntry -Entry $entry -Path $Path -NoConsole:$NoConsole
    return $entry
}

function Get-RrDailyLogPath {
    <#
    .SYNOPSIS
        Builds a UTC-dated JSONL path under a root, e.g. server-2025-08-28.jsonl.
    .PARAMETER Root
        Logs root directory.
    .PARAMETER Prefix
        File name prefix (e.g. 'server', 'requests').
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string] $Root,
        [Parameter(Mandatory)] [string] $Prefix
    )

    $date = [DateTime]::UtcNow.ToString('yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture)
    return Join-Path $Root ("{0}-{1}.jsonl" -f $Prefix, $date)
}

Export-ModuleMember -Function `
    Get-RrTimestamp, `
    New-RrLogEntry, `
    Write-RrLogEntry, `
    Write-RrLog, `
    Get-RrDailyLogPath
