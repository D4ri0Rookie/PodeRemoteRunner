# SSH Remote Execution - Execute commands on remote Linux/Unix servers
# Uses Windows built-in OpenSSH (ssh.exe) - requires Windows 10 1809+ or Server 2019+
# Key-based authentication only (no passwords accepted or stored)
#
# API USAGE:
# POST /ssh/run
# Content-Type: application/json
# Body: {"hosts": ["server1.example.com", "192.168.1.10"], "username": "admin", "command": "df -h"}
#
# SETUP:
# 1. Ensure ssh.exe is available: Get-Command ssh.exe
# 2. Generate SSH key: ssh-keygen -t ed25519
# 3. Copy public key to each target: ssh-copy-id user@host
# 4. Optionally set $SSH_KEY_PATH below to a non-default key location

# Path to SSH private key - defaults to standard user key location
$SSH_KEY_PATH = "$env:USERPROFILE\.ssh\id_rsa"

# SSH web UI
Add-PodeRoute -Method Get -Path '/ssh' -ScriptBlock {
    Write-PodeHtmlResponse -Value @"
<!DOCTYPE html>
<html>
<head>
    <title>SSH Remote Executor - PodeRemoteRunner</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 50px; background: #f5f5f5; }
        .container {
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            max-width: 800px;
            margin: 0 auto;
            box-sizing: border-box;
        }
        .title { color: #6f42c1; font-size: 24px; margin-bottom: 20px; }
        .info { color: #666; margin-bottom: 25px; line-height: 1.6; }
        .form-group { margin-bottom: 20px; }
        label { display: block; margin-bottom: 8px; font-weight: bold; color: #333; }
        input[type="text"], textarea {
            width: 100%;
            padding: 10px;
            border: 2px solid #ddd;
            border-radius: 4px;
            font-size: 14px;
            box-sizing: border-box;
        }
        input[type="text"]:focus, textarea:focus { border-color: #6f42c1; outline: none; }
        .command-box { height: 100px; font-family: monospace; }
        .btn {
            background: #6f42c1;
            color: white;
            padding: 12px 20px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 16px;
        }
        .btn:hover { background: #5a32a3; }
        .btn-secondary { background: #6c757d; }
        .btn-secondary:hover { background: #5a6268; }
        .result { margin-top: 20px; padding: 15px; border-radius: 4px; display: none; }
        .success { background: #d4edda; border: 1px solid #c3e6cb; color: #155724; }
        .error { background: #f8d7da; border: 1px solid #f5c6cb; color: #721c24; }
        .loading { background: #d1ecf1; border: 1px solid #bee5eb; color: #0c5460; }
        .results-table { width: 100%; border-collapse: collapse; margin-top: 15px; background: white; border-radius: 4px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .results-table th { background: #6f42c1; color: white; padding: 12px; text-align: left; font-weight: bold; }
        .results-table td { padding: 10px 12px; border-bottom: 1px solid #eee; cursor: pointer; }
        .results-table tr:hover { background: #f8f9fa; }
        .status-success { color: #28a745; font-weight: bold; }
        .status-error { color: #dc3545; font-weight: bold; }
        .modal { display: none; position: fixed; z-index: 1000; left: 0; top: 0; width: 100%; height: 100%; background-color: rgba(0,0,0,0.5); }
        .modal-content { background: white; margin: 5% auto; border-radius: 8px; width: 90%; max-width: 800px; max-height: 80vh; overflow-y: auto; box-shadow: 0 4px 20px rgba(0,0,0,0.3); }
        .modal-header { background: #6f42c1; color: white; padding: 15px 20px; border-radius: 8px 8px 0 0; display: flex; justify-content: space-between; align-items: center; }
        .modal-header h3 { margin: 0; font-size: 18px; }
        .close { color: white; font-size: 24px; font-weight: bold; cursor: pointer; border: none; background: none; }
        .close:hover { opacity: 0.7; }
        .modal-body { padding: 20px; }
        .spinner { display: inline-block; width: 16px; height: 16px; border: 2px solid #ccc; border-top: 2px solid #6f42c1; border-radius: 50%; animation: spin 1s linear infinite; }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
        .button-container { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; }
        .examples { background: #f8f9fa; padding: 15px; border-radius: 4px; margin-top: 10px; }
        .example { background: white; padding: 8px; margin: 5px 0; border-radius: 4px; cursor: pointer; font-family: monospace; font-size: 12px; }
        .example:hover { background: #e9ecef; }
        .note { background: #fff3cd; border: 1px solid #ffc107; color: #856404; padding: 10px; border-radius: 4px; margin-bottom: 15px; font-size: 13px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="title">🐧 SSH Remote Executor</div>
        <div class="note">
            🔑 Uses SSH key authentication — no passwords accepted.<br>
            Ensure your public key (<code>~/.ssh/id_rsa.pub</code>) is in <code>~/.ssh/authorized_keys</code> on each target host.
        </div>
        <div class="info">
            Execute commands on remote Linux/Unix servers via SSH.<br>
            Uses your current user's SSH key (<code>~\.ssh\id_rsa</code>) for authentication.
        </div>

        <form id="sshForm">
            <div class="form-group">
                <label for="hosts">Hosts (comma-separated):</label>
                <input type="text" id="hosts" placeholder="server1.example.com,192.168.1.10,ubuntu-host" required>
            </div>
            <div class="form-group">
                <label for="username">Username:</label>
                <input type="text" id="username" placeholder="admin" required>
            </div>
            <div class="form-group">
                <label for="command">Command:</label>
                <textarea id="command" class="command-box" placeholder="df -h" required></textarea>
                <div class="examples">
                    <strong>Examples (click to use):</strong><br>
                    <div class="example" onclick="setCommand('df -h')">Disk usage</div>
                    <div class="example" onclick="setCommand('free -h')">Memory info</div>
                    <div class="example" onclick="setCommand('uptime && uname -r')">Uptime + kernel</div>
                    <div class="example" onclick="setCommand('ps aux --sort=-%cpu | head -6')">Top CPU processes</div>
                    <div class="example" onclick="setCommand('cat /etc/os-release | grep PRETTY_NAME')">OS version</div>
                </div>
            </div>
            <div class="form-group">
                <div class="button-container">
                    <button type="submit" class="btn">🚀 Execute</button>
                    <button type="button" class="btn btn-secondary" onclick="clearAll()">🧹 Clear</button>
                    <a href="/" class="btn btn-secondary">🏠 Home</a>
                </div>
            </div>
        </form>

        <div id="result" class="result"></div>
    </div>

    <div id="hostModal" class="modal">
        <div class="modal-content">
            <div class="modal-header">
                <h3 id="modalHostName">Host Details</h3>
                <button class="close" onclick="closeModal()">&times;</button>
            </div>
            <div class="modal-body">
                <div id="modalContent"></div>
            </div>
        </div>
    </div>

    <script>
        function setCommand(cmd) { document.getElementById('command').value = cmd; }
        function clearAll() {
            document.getElementById('sshForm').reset();
            document.getElementById('result').style.display = 'none';
        }
        function closeModal() { document.getElementById('hostModal').style.display = 'none'; }
        window.onclick = function(e) {
            if (e.target === document.getElementById('hostModal')) closeModal();
        }

        function showHostDetails(r) {
            document.getElementById('modalHostName').textContent = 'Host: ' + r.host;
            let content = '<div style="background:#1e1e1e;color:#fff;padding:15px;border-radius:4px;font-family:consolas,monospace;font-size:14px;">';
            content += '<div style="color:#a78bfa;font-weight:bold;">$ # Executing on ' + r.host + '</div>';
            if (r.success) {
                if (r.output && r.output.trim()) {
                    content += '<div style="color:#fff;margin-top:10px;white-space:pre-wrap;">' + r.output.replace(/</g,'&lt;').replace(/>/g,'&gt;') + '</div>';
                } else {
                    content += '<div style="color:#888;margin-top:10px;font-style:italic;"># Command executed (no output)</div>';
                }
                content += '<div style="color:#4ade80;margin-top:10px;">✅ SUCCESS (' + r.executionTime + 's)</div>';
            } else {
                content += '<div style="color:#f87171;margin-top:10px;">❌ ERROR: ' + r.error.replace(/</g,'&lt;').replace(/>/g,'&gt;') + '</div>';
                content += '<div style="color:#f87171;margin-top:5px;">⏱️ Failed after ' + r.executionTime + 's</div>';
            }
            content += '</div>';
            document.getElementById('modalContent').innerHTML = content;
            document.getElementById('hostModal').style.display = 'block';
        }

        function showResult(type, content) {
            const r = document.getElementById('result');
            r.className = 'result ' + type;
            r.innerHTML = content;
            r.style.display = 'block';
        }

        document.getElementById('sshForm').addEventListener('submit', function(e) {
            e.preventDefault();
            const btn = document.querySelector('button[type="submit"]');
            if (btn.disabled) return;

            const hosts = document.getElementById('hosts').value.trim().split(',').map(s => s.trim()).filter(s => s);
            const username = document.getElementById('username').value.trim();
            const command = document.getElementById('command').value.trim();

            if (!hosts.length || !username || !command) {
                showResult('error', '❌ Please fill in all fields');
                return;
            }

            btn.disabled = true;
            btn.innerHTML = '<div class="spinner"></div> Connecting...';
            showResult('loading', '<div class="spinner"></div> Connecting via SSH...');

            fetch('/ssh/run', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'X-Source': 'web-ui' },
                body: JSON.stringify({ hosts, username, command })
            })
            .then(r => r.json())
            .then(data => {
                if (data.success) {
                    window.sshResults = data.results;
                    let html = '<div style="margin-bottom:15px;"><strong>✅ Execution completed!</strong> (' + data.results.length + ' hosts)</div>';
                    html += '<table class="results-table"><thead><tr><th>Host</th><th>Status</th><th>Time</th><th>Details</th></tr></thead><tbody>';
                    data.results.forEach(function(r, i) {
                        const preview = r.success
                            ? (r.output && r.output.trim() ? 'Has output' : 'No output')
                            : r.error.substring(0, 50) + (r.error.length > 50 ? '...' : '');
                        html += '<tr onclick="showHostDetails(window.sshResults[' + i + '])">';
                        html += '<td><strong>' + r.host + '</strong></td>';
                        html += '<td><span class="' + (r.success ? 'status-success' : 'status-error') + '">' + (r.success ? '✅ Success' : '❌ Failed') + '</span></td>';
                        html += '<td>' + r.executionTime + 's</td>';
                        html += '<td style="font-size:12px;color:#666;">' + preview + ' <strong style="color:#6f42c1;">→ Click for details</strong></td>';
                        html += '</tr>';
                    });
                    html += '</tbody></table>';
                    showResult('success', html);
                } else {
                    showResult('error', '❌ ' + data.message);
                }
            })
            .catch(err => showResult('error', '❌ Communication error: ' + err.message))
            .finally(function() { btn.disabled = false; btn.innerHTML = '🚀 Execute'; });
        });
    </script>
</body>
</html>
"@ -StatusCode 200
}

# SSH run endpoint
Add-PodeRoute -Method Post -Path '/ssh/run' -ScriptBlock {
    try {
        $requestData = $WebEvent.Data
        $hosts    = $requestData.hosts
        $username = $requestData.username
        $command  = $requestData.command

        if (-not $hosts -or $hosts.Count -eq 0) {
            Write-PodeJsonResponse -Value @{ success = $false; message = "No hosts specified" } -StatusCode 400
            return
        }
        if (-not $username) {
            Write-PodeJsonResponse -Value @{ success = $false; message = "No username specified" } -StatusCode 400
            return
        }
        # Valid Linux usernames: start with letter or underscore, max 32 chars
        if ($username -notmatch '^[a-z_][a-z0-9_\-\.]{0,31}$') {
            Write-PodeJsonResponse -Value @{ success = $false; message = "Invalid username format" } -StatusCode 400
            return
        }
        if (-not $command) {
            Write-PodeJsonResponse -Value @{ success = $false; message = "No command specified" } -StatusCode 400
            return
        }

        # Verify ssh.exe is available (OpenSSH, built-in on Windows 10 1809+ / Server 2019+)
        $sshExe = (Get-Command ssh.exe -ErrorAction SilentlyContinue)?.Source
        if (-not $sshExe) {
            Write-PodeJsonResponse -Value @{
                success = $false
                message = "ssh.exe not found. Enable OpenSSH via: Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0"
            } -StatusCode 500
            return
        }

        $executionId = if ($WebEvent['TraceId']) { $WebEvent['TraceId'] } else { [System.Guid]::NewGuid().ToString().Split('-')[0] }
        $source      = if ($WebEvent['RequestSource']) { $WebEvent['RequestSource'] } else { 'api' }
        $timestamp   = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

        $logDir = Join-Path $PSScriptRoot "logs\ssh"
        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        $logFile = Join-Path $logDir "execution_$($timestamp)_$executionId.log"

        function Write-SshLog {
            param($Message, [switch]$NoTimestamp)
            $entry = if ($NoTimestamp) { $Message } else { "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message" }
            Add-Content -Path $logFile -Value $entry -ErrorAction SilentlyContinue
            Write-Host $entry -ForegroundColor Magenta
        }

        Write-SshLog "=== SSH EXECUTION START ==="
        Write-SshLog "ID: $executionId | Source: $source | IP: $($WebEvent.Request.RemoteEndPoint.Address) | User: $username"
        Write-SshLog "Hosts: $($hosts -join ', ')"
        Write-SshLog "Command: $command"

        $results    = @()
        $validHosts = @()

        foreach ($h in $hosts) {
            if ($h -notmatch '^[a-zA-Z0-9\.\-]+$') {
                $results += @{ host = $h; success = $false; output = ""; error = "Invalid host format"; executionTime = 0 }
                Write-SshLog "❌ Invalid host name: $h"
            } else {
                $validHosts += $h
            }
        }

        if ($validHosts.Count -gt 0) {
            $sshKeyPath = $SSH_KEY_PATH

            $jobs = foreach ($h in $validHosts) {
                Write-SshLog "Launching SSH job for $h"
                Start-Job -Name "SSH_$h" -ScriptBlock {
                    param($targetHost, $username, $command, $sshExe, $sshKeyPath, $executionId)

                    $startTime = Get-Date
                    $jobLogs   = @()
                    function Write-JobLog { param($msg)
                        $script:jobLogs += "[$(Get-Date -Format 'HH:mm:ss')] [$targetHost] $msg"
                    }

                    $result = @{ host = $targetHost; success = $false; output = ""; error = ""; logs = @(); executionTime = 0 }

                    try {
                        Write-JobLog "Connecting as $username@$targetHost"

                        # Build ssh arguments
                        $sshArgs = @(
                            '-o', 'StrictHostKeyChecking=no',
                            '-o', 'BatchMode=yes',          # fail fast if key auth is not set up
                            '-o', 'ConnectTimeout=20',
                            '-o', 'LogLevel=ERROR'
                        )
                        if (Test-Path $sshKeyPath) {
                            $sshArgs += '-i', $sshKeyPath
                            Write-JobLog "Using key: $sshKeyPath"
                        }
                        $sshArgs += "$username@$targetHost"
                        $sshArgs += $command

                        # Use .NET Process to capture stdout/stderr separately (avoids temp files)
                        $psi = [System.Diagnostics.ProcessStartInfo]::new($sshExe)
                        $psi.ArgumentList.Clear()
                        foreach ($a in $sshArgs) { $psi.ArgumentList.Add($a) }
                        $psi.RedirectStandardOutput = $true
                        $psi.RedirectStandardError  = $true
                        $psi.UseShellExecute        = $false
                        $psi.CreateNoWindow         = $true

                        $proc = [System.Diagnostics.Process]::new()
                        $proc.StartInfo = $psi
                        $null = $proc.Start()

                        # Read streams asynchronously to prevent deadlock
                        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
                        $stderrTask = $proc.StandardError.ReadToEndAsync()

                        $finished = $proc.WaitForExit(30000)
                        if (-not $finished) {
                            $proc.Kill()
                            throw "SSH connection timed out after 30 seconds"
                        }

                        $stdout   = $stdoutTask.GetAwaiter().GetResult()
                        $stderr   = $stderrTask.GetAwaiter().GetResult()
                        $exitCode = $proc.ExitCode
                        $proc.Dispose()

                        if ($exitCode -eq 0) {
                            $result.success = $true
                            $result.output  = $stdout.Trim()
                            Write-JobLog "✅ Success (exit code 0)"
                        } else {
                            $errMsg = if ($stderr -and $stderr.Trim()) { $stderr.Trim() } else { "SSH exit code $exitCode" }
                            $result.error = $errMsg
                            Write-JobLog "❌ Failed: $errMsg"
                        }
                    }
                    catch {
                        $result.error = $_.Exception.Message
                        Write-JobLog "❌ Exception: $($_.Exception.Message)"
                    }

                    $result.executionTime = [Math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)
                    $result.logs = $jobLogs
                    return $result
                } -ArgumentList $h, $username, $command, $sshExe, $sshKeyPath, $executionId
            }

            $timeout = [Math]::Max(120, 40 + ($validHosts.Count * 35))
            Write-SshLog "Waiting for $($validHosts.Count) jobs (timeout: $timeout seconds)"
            $null = Wait-Job -Job $jobs -Timeout $timeout

            foreach ($job in $jobs) {
                try {
                    if ($job.State -eq "Completed") {
                        $jr = Receive-Job -Job $job
                        if ($jr -and $jr.host) {
                            if ($jr.logs) { foreach ($l in $jr.logs) { Write-SshLog $l -NoTimestamp } }
                            $results += @{
                                host          = $jr.host
                                success       = $jr.success
                                output        = $jr.output
                                error         = $jr.error
                                executionTime = $jr.executionTime
                            }
                            Write-SshLog "$(if ($jr.success) { '✅' } else { '❌' }) $($jr.host): $(if ($jr.success) { 'success' } else { $jr.error })"
                        }
                    } elseif ($job.State -eq "Running") {
                        Stop-Job -Job $job
                        $results += @{ host = $job.Name.Replace("SSH_",""); success = $false; output = ""; error = "Timed out"; executionTime = $timeout }
                        Write-SshLog "❌ Timeout: $($job.Name)"
                    } else {
                        $results += @{ host = $job.Name.Replace("SSH_",""); success = $false; output = ""; error = "Job failed unexpectedly"; executionTime = 0 }
                        Write-SshLog "❌ Job failed: $($job.Name)"
                    }
                }
                catch { Write-SshLog "❌ Error collecting $($job.Name): $($_.Exception.Message)" }
                finally { Remove-Job -Job $job -Force -ErrorAction SilentlyContinue }
            }
        }

        $successCount = ($results | Where-Object { $_.success }).Count
        Write-SshLog "=== END | Total: $($results.Count) | Success: $successCount | Failed: $($results.Count - $successCount) ==="

        Write-PodeJsonResponse -Value @{
            success     = $true
            message     = "SSH execution completed"
            executionId = $executionId
            results     = $results
        }
    }
    catch {
        Write-Host "❌ SSH general error: $($_.Exception.Message)" -ForegroundColor Red
        Write-PodeJsonResponse -Value @{
            success = $false
            message = "Internal error: $($_.Exception.Message)"
        } -StatusCode 500
    }
}
