# WinRM Remote Execution - Execute PowerShell code on remote servers
# Simple template for beginners with detailed logging for error debugging
# 
# API USAGE:
# You can call /winrm/run directly without using the web form:
#
# POST /winrm/run
# Content-Type: application/json
# Body: {"servers": ["SERVER01", "SERVER02"], "command": "Get-Service"}
#
# Examples:
# curl -X POST -H "Content-Type: application/json" -d '{"servers":["SERVER01"],"command":"Get-ComputerInfo"}' http://localhost:8080/winrm/run
# Invoke-RestMethod -Uri "http://localhost:8080/winrm/run" -Method POST -ContentType "application/json" -Body '{"servers":["SERVER01"],"command":"Get-Service"}'

# Main WinRM web page
Add-PodeRoute -Method Get -Path '/winrm' -ScriptBlock {
    Write-PodeHtmlResponse -Value @"
<!DOCTYPE html>
<html>
<head>
    <title>WinRM Remote Scheduler - PodeRemoteRunner</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 50px; background: #f5f5f5; }
        .container { 
            background: white; 
            padding: 30px; 
            border-radius: 8px; 
            box-shadow: 0 2px 10px rgba(0,0,0,0.1); 
            max-width: 800px; 
            margin: 0 auto; 
            position: relative;
            box-sizing: border-box;
        }
        .title { color: #17a2b8; font-size: 24px; margin-bottom: 20px; }
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
        input[type="text"]:focus, textarea:focus { border-color: #17a2b8; outline: none; }
        .servers-box { height: 80px; }
        .command-box { height: 120px; font-family: monospace; }
        .btn { 
            background: #17a2b8; 
            color: white; 
            padding: 12px 20px; 
            border: none; 
            border-radius: 4px; 
            cursor: pointer; 
            font-size: 16px; 
            margin-right: 10px;
        }
        .btn:hover { background: #138496; }
        .btn-secondary { background: #6c757d; }
        .btn-secondary:hover { background: #5a6268; }
        .result { 
            margin-top: 20px; 
            padding: 15px; 
            border-radius: 4px; 
            display: none;
        }
        .success { background: #d4edda; border: 1px solid #c3e6cb; color: #155724; }
        .error { background: #f8d7da; border: 1px solid #f5c6cb; color: #721c24; }
        .loading { background: #d1ecf1; border: 1px solid #bee5eb; color: #0c5460; }
        .server-result { 
            margin: 10px 0; 
            padding: 10px; 
            border: 1px solid #ddd; 
            border-radius: 4px; 
            background: #f8f9fa;
        }
        .server-name { font-weight: bold; color: #333; }
        .server-output { 
            font-family: monospace; 
            font-size: 12px; 
            white-space: pre-wrap; 
            margin-top: 10px; 
            padding: 10px; 
            background: white; 
            border: 1px solid #ddd; 
            border-radius: 4px;
        }
        .examples { 
            background: #f8f9fa; 
            padding: 15px; 
            border-radius: 4px; 
            margin-top: 10px;
        }
        .example { 
            background: white; 
            padding: 8px; 
            margin: 5px 0; 
            border-radius: 4px; 
            cursor: pointer; 
            font-family: monospace; 
            font-size: 12px;
        }
        .example:hover { background: #e9ecef; }
        .spinner { 
            display: inline-block; 
            width: 16px; 
            height: 16px; 
            border: 2px solid #ccc;
            border-top: 2px solid #17a2b8;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
        
        /* Results table styles */
        .results-table { 
            width: 100%; 
            border-collapse: collapse; 
            margin-top: 15px; 
            background: white; 
            border-radius: 4px; 
            overflow: hidden; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1); 
        }
        .results-table th { 
            background: #17a2b8; 
            color: white; 
            padding: 12px; 
            text-align: left; 
            font-weight: bold; 
        }
        .results-table td { 
            padding: 10px 12px; 
            border-bottom: 1px solid #eee; 
            cursor: pointer; 
        }
        .results-table tr:hover { 
            background: #f8f9fa; 
        }
        .status-success { 
            color: #28a745; 
            font-weight: bold; 
        }
        .status-error { 
            color: #dc3545; 
            font-weight: bold; 
        }
        .exec-time { 
            color: #666; 
            font-size: 12px; 
        }
        
        /* Modal styles */
        .modal { 
            display: none; 
            position: fixed; 
            z-index: 1000; 
            left: 0; 
            top: 0; 
            width: 100%; 
            height: 100%; 
            background-color: rgba(0,0,0,0.5); 
        }
        .modal-content { 
            background: white; 
            margin: 5% auto; 
            padding: 0; 
            border-radius: 8px; 
            width: 90%; 
            max-width: 800px; 
            max-height: 80vh; 
            overflow-y: auto; 
            box-shadow: 0 4px 20px rgba(0,0,0,0.3); 
        }
        .modal-header { 
            background: #17a2b8; 
            color: white; 
            padding: 15px 20px; 
            border-radius: 8px 8px 0 0; 
            display: flex; 
            justify-content: space-between; 
            align-items: center; 
        }
        .modal-header h3 { 
            margin: 0; 
            font-size: 18px; 
        }
        .close { 
            color: white; 
            font-size: 24px; 
            font-weight: bold; 
            cursor: pointer; 
            border: none; 
            background: none; 
        }
        .close:hover { 
            opacity: 0.7; 
        }
        .modal-body { 
            padding: 20px; 
        }
        
        /* Button container - prevents movement on zoom */
        .button-container {
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
            align-items: center;
            width: 100%;
            position: relative;
        }
        
        .container .button-container .btn {
            margin: 0 !important; /* Force override any margin */
            flex-shrink: 0; /* Prevent buttons from shrinking */
            position: relative; /* Keep in document flow */
            white-space: nowrap; /* Prevent text wrapping */
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="title">🖥️ WinRM Simple</div>
        <div class="info">
            Execute PowerShell code on remote servers. Enter servers (one per line) and the code to execute.<br>
            <strong>Note:</strong> Uses your current Windows credentials to connect to servers.
        </div>
        
        <form id="winrmForm">
            <div class="form-group">
                <label for="servers">Servers (comma-separated):</label>
                <input type="text" id="servers" placeholder="SERVER01,SERVER02,192.168.1.100" required>
            </div>
            
            <div class="form-group">
                <label for="command">PowerShell Code:</label>
                <textarea id="command" class="command-box" placeholder="Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion" required></textarea>
                
            </div>
            
            <div class="form-group">
                <div class="button-container">
                    <button type="submit" class="btn">🚀 Execute</button>
                    <button type="button" class="btn btn-secondary" onclick="clearAll()">🧹 Clear</button>
                    <a href="/" class="btn btn-secondary">🏠 Home</a>
                </div>
            </div>
            
                
                <div class="examples">
                    <strong>Examples (click to use):</strong><br>
                    <div class="example" onclick="setCommand('Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion')">
                        Windows Information
                    </div>
                    <div class="example" onclick="setCommand('Get-Service | Where-Object Status -eq \'Running\' | Select-Object Name, Status')">
                        Running Services
                    </div>
                    <div class="example" onclick="setCommand('Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 Name, CPU')">
                        Top 5 CPU Processes
                    </div>
                </div>
            </div>
        </form>
        
        <div id="result" class="result"></div>
    </div>

    <!-- Modal for server details -->
    <div id="serverModal" class="modal">
        <div class="modal-content">
            <div class="modal-header">
                <h3 id="modalServerName">Server Details</h3>
                <button class="close" onclick="closeModal()">&times;</button>
            </div>
            <div class="modal-body">
                <div id="modalContent"></div>
            </div>
        </div>
    </div>

    <script>
        function setCommand(cmd) {
            document.getElementById('command').value = cmd;
        }

        function clearAll() {
            document.getElementById('winrmForm').reset();
            document.getElementById('result').style.display = 'none';
        }

        function showServerDetails(serverResult) {
            document.getElementById('modalServerName').textContent = 'Server: ' + serverResult.server;
            
            let content = '';
            if (serverResult.success) {
                content = '<div style="background: #1e1e1e; color: #ffffff; padding: 15px; border-radius: 4px; font-family: consolas, monospace; font-size: 14px;">';
                content += '<div style="color: #00ff00; font-weight: bold;">PS C:\\> # Executing on ' + serverResult.server + '</div>';
                
                if (serverResult.output && serverResult.output.trim()) {
                    content += '<div style="color: #ffffff; margin-top: 10px; white-space: pre-wrap;">' + serverResult.output.replace(/</g, '&lt;').replace(/>/g, '&gt;') + '</div>';
                } else {
                    content += '<div style="color: #888; margin-top: 10px; font-style: italic;"># Command executed successfully (no output)</div>';
                }
                content += '<div style="color: #00ff00; margin-top: 10px;">✅ SUCCESS (' + serverResult.executionTime + 's)</div>';
                content += '</div>';
            } else {
                content = '<div style="background: #1e1e1e; color: #ffffff; padding: 15px; border-radius: 4px; font-family: consolas, monospace; font-size: 14px;">';
                content += '<div style="color: #00ff00; font-weight: bold;">PS C:\\> # Executing on ' + serverResult.server + '</div>';
                content += '<div style="color: #ff4444; margin-top: 10px;">❌ ERROR: ' + serverResult.error.replace(/</g, '&lt;').replace(/>/g, '&gt;') + '</div>';
                content += '<div style="color: #ff4444; margin-top: 10px;">⏱️ Failed after ' + serverResult.executionTime + 's</div>';
                content += '</div>';
            }
            
            document.getElementById('modalContent').innerHTML = content;
            document.getElementById('serverModal').style.display = 'block';
        }

        function closeModal() {
            document.getElementById('serverModal').style.display = 'none';
        }

        // Close modal when clicking outside of it
        window.onclick = function(event) {
            const modal = document.getElementById('serverModal');
            if (event.target == modal) {
                closeModal();
            }
        }

        function showResult(type, content) {
            const result = document.getElementById('result');
            result.className = 'result ' + type;
            result.innerHTML = content;
            result.style.display = 'block';
        }

        document.getElementById('winrmForm').addEventListener('submit', function(e) {
            e.preventDefault();
            
            const submitButton = document.querySelector('button[type="submit"]');
            
            // Prevent multiple submissions
            if (submitButton.disabled) {
                return;
            }
            
            // Parse comma-separated servers (like curl format)
            const serversInput = document.getElementById('servers').value.trim();
            const servers = serversInput.split(',').map(s => s.trim()).filter(s => s);
            const command = document.getElementById('command').value.trim();
            
            if (servers.length === 0 || !command) {
                showResult('error', '❌ Please enter at least one server and a command');
                return;
            }
            
            // Disable submit button during execution
            submitButton.disabled = true;
            submitButton.innerHTML = '<div class="spinner"></div> Executing...';
            
            showResult('loading', '<div class="spinner"></div> Execution in progress...');
            
            
            fetch('/winrm/run', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'X-Source': 'web-ui' },
                body: JSON.stringify({ servers: servers, command: command })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    // Store results globally for modal access
                    window.executionResults = data.results;
                    
                    // Show compact results table
                    let html = '<div style="margin-bottom: 15px;"><strong>✅ Execution completed!</strong> (' + data.results.length + ' servers)</div>';
                    html += '<table class="results-table">';
                    html += '<thead><tr><th>Server</th><th>Status</th><th>Time</th><th>Details</th></tr></thead>';
                    html += '<tbody>';
                    
                    data.results.forEach((result, index) => {
                        const statusClass = result.success ? 'status-success' : 'status-error';
                        const statusText = result.success ? '✅ Success' : '❌ Failed';
                        const preview = result.success 
                            ? (result.output && result.output.trim() ? 'Has output' : 'No output')
                            : result.error.substring(0, 50) + (result.error.length > 50 ? '...' : '');
                        
                        html += '<tr onclick="showServerDetails(window.executionResults[' + index + '])">';
                        html += '<td><strong>' + result.server + '</strong></td>';
                        html += '<td><span class="' + statusClass + '">' + statusText + '</span></td>';
                        html += '<td><span class="exec-time">' + result.executionTime + 's</span></td>';
                        html += '<td style="font-size: 12px; color: #666;">' + preview + ' <strong style="color: #17a2b8;">→ Click for details</strong></td>';
                        html += '</tr>';
                    });
                    
                    html += '</tbody></table>';
                    
                    showResult('success', html);
                } else {
                    showResult('error', '❌ ' + data.message);
                }
            })
            .catch(error => {
                showResult('error', '❌ Communication error: ' + error.message);
            })
            .finally(() => {
                // Re-enable submit button
                submitButton.disabled = false;
                submitButton.innerHTML = '🚀 Execute';
            });
        });
    </script>
</body>
</html>
"@ -StatusCode 200
}

# Endpoint to execute commands
Add-PodeRoute -Method Post -Path '/winrm/run' -ScriptBlock {
    try {
        # Read data from request
        $requestData = $WebEvent.Data
        $servers = $requestData.servers
        $command = $requestData.command
        
        
        # Check that we have data
        if (-not $servers -or $servers.Count -eq 0) {
            Write-PodeJsonResponse -Value @{
                success = $false
                message = "No servers specified"
            } -StatusCode 400
            return
        }
        
        if (-not $command) {
            Write-PodeJsonResponse -Value @{
                success = $false
                message = "No command specified"
            } -StatusCode 400
            return
        }
        
        # Reuse the TraceId set by RequestLogger middleware so request log and execution log share the same ID
        $executionId = if ($WebEvent['TraceId']) { $WebEvent['TraceId'] } else { [System.Guid]::NewGuid().ToString().Split('-')[0] }
        $source      = if ($WebEvent['RequestSource']) { $WebEvent['RequestSource'] } else { 'api' }
        $timestamp   = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        
        # Create folder for logs
        $logDir = Join-Path $PSScriptRoot "logs\winrm"
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        
        # Log file for this execution
        $logFile = Join-Path $logDir "execution_$($timestamp)_$executionId.log"
        
        # Function to write to log
        function Write-ExecutionLog {
            param($Message, [switch]$NoTimestamp)
            if ($NoTimestamp) {
                $logEntry = $Message
            } else {
                $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
            }
            Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
            Write-Host $logEntry -ForegroundColor Cyan
        }
        
        Write-ExecutionLog "=== EXECUTION START ==="
        Write-ExecutionLog "ID: $executionId | Source: $source | IP: $($WebEvent.Request.RemoteEndPoint.Address)"
        Write-ExecutionLog "Servers: $($servers -join ', ')"
        Write-ExecutionLog "Command: $command"
        
        # Array to collect results
        $results = @()
        
        # Validate all server names before launching jobs
        $validServers = @()
        foreach ($server in $servers) {
            if ($server -notmatch '^[a-zA-Z0-9\.\-]+$') {
                $serverResult = @{
                    server = $server
                    success = $false
                    output = ""
                    error = "Invalid server name format"
                }
                Write-ExecutionLog "❌ Invalid server name: $server"
                $results += $serverResult
            } else {
                $validServers += $server
            }
        }
        
        # Skip job execution if no valid servers remain
        if ($validServers.Count -eq 0) {
            Write-ExecutionLog "No valid servers to process"
        } else {
            Write-ExecutionLog "Starting parallel execution on $($validServers.Count) servers: $($validServers -join ', ')"
            
            # One background job per server — run all in parallel
            $jobs = foreach ($server in $validServers) {
                Write-ExecutionLog "Launching job for $server"
                
                Start-Job -Name "WinRM_$server" -ScriptBlock {
                    param($server, $command, $executionId)
                    
                    # Collects log entries in memory; returned with job result for main log
                    $jobLogs = @()
                    function Write-JobLog {
                        param($Message)
                        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        $logEntry = "[$timestamp] [$server] $Message"
                        $script:jobLogs += $logEntry
                    }
                    
                    $serverResult = @{
                        server = $server
                        success = $false
                        output = ""
                        error = ""
                        logs = @()
                        executionTime = 0
                        startTime = Get-Date
                    }
                    
                    # Retry up to 2 times before marking the server as failed
                    $maxRetries = 2
                    $success = $false
                    
                    for ($retry = 0; $retry -le $maxRetries -and -not $success; $retry++) {
                        try {
                            if ($retry -gt 0) {
                                Write-JobLog "Retry attempt $retry"
                                Start-Sleep -Seconds 2
                            }
                            
                            # Skip certificate checks for self-signed WinRM certs
                            $sessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck
                            
                            # Test WinRM HTTPS connection
                            Write-JobLog "Testing WinRM HTTPS connection (port 5986)"
                            $null = Test-WSMan -ComputerName $server -UseSSL -ErrorAction Stop
                            Write-JobLog "✅ WinRM HTTPS connection OK (port 5986)"
                            
                            # Execute command via WinRM HTTPS with timeout
                            Write-JobLog "Executing command via HTTPS (port 5986)"
                            $scriptBlock = [scriptblock]::Create($command)
                            
                            # Create session with timeout management
                            $session = $null
                            $job = $null
                            
                            try {
                                Write-JobLog "Creating PSSession"
                                $session = New-PSSession -ComputerName $server -UseSSL -SessionOption $sessionOption -ErrorAction Stop
                                Write-JobLog "PSSession created successfully"
                                
                                # Execute with timeout using job
                                Write-JobLog "Starting command execution job"
                                $job = Invoke-Command -Session $session -ScriptBlock $scriptBlock -AsJob
                                $output = Wait-Job -Job $job -Timeout 120 | Receive-Job
                                
                                if ($job.State -eq "Running") {
                                    Write-JobLog "Command timeout - stopping job"
                                    Stop-Job -Job $job -Force
                                    throw "Command timeout after 120 seconds"
                                }
                                
                                Write-JobLog "Command completed successfully"
                            }
                            catch {
                                Write-JobLog "Error during execution: $($_.Exception.Message)"
                                throw
                            }
                            finally {
                                # Cleanup job first
                                if ($job) {
                                    try {
                                        Write-JobLog "Cleaning up job"
                                        Stop-Job -Job $job -ErrorAction SilentlyContinue
                                        Remove-Job -Job $job -ErrorAction SilentlyContinue
                                        Write-JobLog "Job cleanup completed"
                                    }
                                    catch {
                                        Write-JobLog "Warning: Job cleanup failed: $($_.Exception.Message)"
                                    }
                                }
                                
                                # Cleanup session
                                if ($session) {
                                    try {
                                        Write-JobLog "Closing PSSession"
                                        Remove-PSSession -Session $session -ErrorAction Stop
                                        Write-JobLog "PSSession closed successfully"
                                    }
                                    catch {
                                        Write-JobLog "Warning: PSSession cleanup failed: $($_.Exception.Message)"
                                        # Force disconnect if normal removal fails
                                        try {
                                            Disconnect-PSSession -Session $session -ErrorAction SilentlyContinue
                                            Remove-PSSession -Session $session -ErrorAction SilentlyContinue
                                        }
                                        catch {
                                            Write-JobLog "Warning: Force cleanup also failed"
                                        }
                                    }
                                }
                            }
                            
                            # Convert output to string - keep original PowerShell format
                            $outputString = ($output | Out-String).Trim()
                            
                            $serverResult.success = $true
                            $serverResult.output = $outputString
                            $success = $true
                            
                            Write-JobLog "✅ Command executed successfully"
                        }
                        catch {
                            $errorMessage = $_.Exception.Message
                            Write-JobLog "❌ Error (attempt $($retry + 1)): $errorMessage"
                            
                            # Last retry: record the final error and classify it
                            if ($retry -eq $maxRetries) {
                                $serverResult.success = $false
                                $serverResult.error = $errorMessage

                                # Classify error for easier troubleshooting
                                if ($errorMessage -like "*cannot resolve*" -or $errorMessage -like "*not found*") {
                                    Write-JobLog "Cause: Invalid server name or DNS resolution failed"
                                }
                                elseif ($errorMessage -like "*access*denied*" -or $errorMessage -like "*unauthorized*") {
                                    Write-JobLog "Cause: Insufficient permissions or authentication failed"
                                }
                                elseif ($errorMessage -like "*timeout*" -or $errorMessage -like "*unreachable*") {
                                    Write-JobLog "Cause: Network timeout or server unreachable (check firewall/port 5986)"
                                }
                                elseif ($errorMessage -like "*ssl*" -or $errorMessage -like "*certificate*") {
                                    Write-JobLog "Cause: SSL/Certificate error (check WinRM HTTPS configuration)"
                                }
                                else {
                                    Write-JobLog "Cause: WinRM service not running or HTTPS not configured"
                                }
                            }
                        }
                    }
                    
                    $serverResult.executionTime = [Math]::Round(((Get-Date) - $serverResult.startTime).TotalSeconds, 2)
                    $serverResult.logs = $jobLogs
                    $serverResult.Remove('startTime')
                    
                    return $serverResult
                } -ArgumentList $server, $command, $executionId
            }
            
            # Calculate dynamic timeout based on server count
            # Base: 5 minutes + 30 seconds per server (minimum 10 minutes)
            $baseTimeout = 300 # 5 minutes
            $perServerTimeout = 30 # 30 seconds per server
            $timeout = [Math]::Max(600, $baseTimeout + ($validServers.Count * $perServerTimeout)) # minimum 10 minutes
            
            Write-ExecutionLog "Waiting for all jobs to complete (timeout: $([Math]::Round($timeout/60, 1)) minutes for $($validServers.Count) servers)"
            $null = Wait-Job -Job $jobs -Timeout $timeout
            
            # Collect results from each completed job
            foreach ($job in $jobs) {
                try {
                    if ($job.State -eq "Completed") {
                        $jobResult = Receive-Job -Job $job
                        # Ensure we only add the server result object, not any stray output
                        if ($jobResult -and $jobResult.server) {
                            # Write detailed job logs to main log (without adding timestamp)
                            if ($jobResult.logs) {
                                foreach ($logEntry in $jobResult.logs) {
                                    Write-ExecutionLog $logEntry -NoTimestamp
                                }
                            }
                            
                            # Remove logs from result before adding to results (to keep JSON clean)
                            $cleanResult = @{
                                server = $jobResult.server
                                success = $jobResult.success
                                output = $jobResult.output
                                error = $jobResult.error
                                executionTime = $jobResult.executionTime
                            }
                            $results += $cleanResult
                            Write-ExecutionLog "✅ Job completed for $($jobResult.server)"
                        } else {
                            Write-ExecutionLog "⚠️ Job completed but no valid result received for $($job.Name.Replace('WinRM_', ''))"
                        }
                    }
                    elseif ($job.State -eq "Running") {
                        # Still running after timeout — kill it
                        Stop-Job -Job $job
                        $serverResult = @{
                            server = $job.Name.Replace("WinRM_", "")
                            success = $false
                            output = ""
                            error = "Operation timed out after $timeout seconds"
                        }
                        $results += $serverResult
                        Write-ExecutionLog "❌ Job for $($job.Name.Replace('WinRM_', '')) timed out"
                    }
                    else {
                        # Job ended in a failed state
                        $jobErrors = $job.ChildJobs[0].Error
                        $errorMessage = if ($jobErrors) { $jobErrors[-1].ToString() } else { "Job failed with unknown error" }
                        $serverResult = @{
                            server = $job.Name.Replace("WinRM_", "")
                            success = $false
                            output = ""
                            error = $errorMessage
                        }
                        $results += $serverResult
                        Write-ExecutionLog "❌ Job for $($job.Name.Replace('WinRM_', '')) failed: $errorMessage"
                    }
                }
                catch {
                    Write-ExecutionLog "❌ Error processing job $($job.Name): $($_.Exception.Message)"
                }
                finally {
                    # Clean up job
                    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                }
            }
        }
        
        # Calculate execution time from the original start timestamp
        $executionStartTime = [DateTime]::ParseExact($timestamp, "yyyy-MM-dd_HH-mm-ss", $null)
        $executionTime = (Get-Date) - $executionStartTime
        
        Write-ExecutionLog "=== EXECUTION SUMMARY ==="
        Write-ExecutionLog "Total execution time: $($executionTime.TotalSeconds.ToString('F1')) seconds"
        Write-ExecutionLog "Servers processed: $($results.Count)"
        
        
        $successfulResults = $results | Where-Object { $_.success -eq $true }
        $failedResults = $results | Where-Object { $_.success -eq $false }
        
        Write-ExecutionLog "✅ Successful: $($successfulResults.Count)"
        Write-ExecutionLog "❌ Failed: $($failedResults.Count)"
        
        # Detailed results with per-server timing
        foreach ($result in $results) {
            if ($result.success) {
                $outputLength = if ($result.output) { $result.output.Length } else { 0 }
                Write-ExecutionLog "✅ $($result.server): Success ($($result.executionTime)s, output: $outputLength chars)"
            } else {
                Write-ExecutionLog "❌ $($result.server): Failed ($($result.executionTime)s) - $($result.error)"
            }
        }
        
        Write-ExecutionLog "=== END ==="
        
        # Detailed output section for each server
        if ($results.Count -gt 0) {
            Write-ExecutionLog ""
            Write-ExecutionLog "=== DETAILED SERVER OUTPUT ==="
            
            foreach ($result in $results) {
                Write-ExecutionLog ""
                Write-ExecutionLog "--- SERVER: $($result.server) ---"
                Write-ExecutionLog "Status: $(if ($result.success) { 'SUCCESS' } else { 'FAILED' })"
                Write-ExecutionLog "Execution Time: $($result.executionTime) seconds"
                
                if ($result.success -and $result.output) {
                    Write-ExecutionLog "Output:"
                    Write-ExecutionLog $result.output
                } elseif (-not $result.success) {
                    Write-ExecutionLog "Error: $($result.error)"
                } else {
                    Write-ExecutionLog "No output produced"
                }
                Write-ExecutionLog "--- END $($result.server) ---"
            }
            Write-ExecutionLog ""
            Write-ExecutionLog "=== END DETAILED OUTPUT ==="
        }
        
        # JSON response - always clean JSON for API
        Write-PodeJsonResponse -Value @{
            success = $true
            message = "Execution completed"
            executionId = $executionId
            logFile = $logFile
            results = $results
        }
    }
    catch {
        Write-Host "❌ General error: $($_.Exception.Message)" -ForegroundColor Red
        
        Write-PodeJsonResponse -Value @{
            success = $false
            message = "Internal error: $($_.Exception.Message)"
        } -StatusCode 500
    }
}