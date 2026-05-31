# PodeRemoteRunner

**Run commands on multiple remote servers in parallel — Windows and Linux.**

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell&logoColor=white)](https://github.com/PowerShell/PowerShell)
[![Pode](https://img.shields.io/badge/Pode-2.x-brightgreen?logo=powershell&logoColor=white)](https://github.com/Badgerati/Pode)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows-0078d4?logo=windows&logoColor=white)](https://www.microsoft.com/windows)

[Quick Start](#quick-start) · [API](#api) · [Prerequisites](#prerequisites) · [Troubleshooting](#troubleshooting)

</div>

---

One command. Any number of servers. All at the same time.

PodeRemoteRunner is a lightweight PowerShell HTTP server that executes commands on remote **Windows servers via WinRM** and **Linux servers via SSH** in parallel. It exposes a clean REST API and an optional web UI — no agents, no dependencies on the target machines.

<br>

![Architecture](image.png)

<br>

---

## Features

**Execution**
- Parallel execution across unlimited servers simultaneously
- WinRM over HTTPS (port 5986) for Windows — uses your current Windows identity, no passwords
- SSH key authentication for Linux/Unix — passwords never accepted or stored
- Auto-retry with up to 2 attempts per server before marking it as failed

**Observability**
- Unique TraceId per request — returned in the `X-Request-Id` response header
- Per-execution log file — command, output, and timing saved for every run
- Daily-rotated request logs in plain text and structured JSON (JSONL)

**Security**
- OWASP security headers on every response (CSP, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy)
- Input validation — server names and hostnames sanitized before use
- Rate limiting — 60 requests per minute per IP (Pode built-in)

---

## Quick Start

**1. Install Pode**
```powershell
Install-Module -Name Pode -Scope CurrentUser
```

**2. Run setup** — checks requirements and creates the `logs/` folder
```powershell
.\scripts\setup.ps1
```

**3. Start the server**
```powershell
# Foreground (recommended for first run)
.\server.ps1

# Background
.\start-background.ps1
```

**4. Open your browser**
```
http://localhost:8080
```

---

## API

| Method | Endpoint | Description |
|:------:|----------|-------------|
| `GET` | `/` | Server status page |
| `GET` | `/health` | Health check |
| `GET` | `/winrm` | WinRM web UI |
| `POST` | `/winrm/run` | Execute PowerShell on Windows servers |
| `GET` | `/ssh` | SSH web UI |
| `POST` | `/ssh/run` | Execute commands on Linux servers |

> Every response includes `X-Request-Id: <traceId>`. Use this ID to locate the matching execution log file instantly.

<details>
<summary><strong>POST /winrm/run</strong> — request and response</summary>

```json
// Request
{
  "servers": ["SERVER01", "SERVER02"],
  "command": "Get-Service W3SVC | Select-Object Name, Status"
}
```

```json
// Response
{
  "success": true,
  "executionId": "a1b2c3d4",
  "logFile": "logs/winrm/execution_2025-08-28_14-30-15_a1b2c3d4.log",
  "results": [
    {
      "server": "SERVER01",
      "success": true,
      "output": "Name  Status\n----  ------\nW3SVC Running",
      "error": "",
      "executionTime": 2.1
    }
  ]
}
```

</details>

<details>
<summary><strong>POST /ssh/run</strong> — request and response</summary>

```json
// Request
{
  "hosts": ["ubuntu-01.example.com", "192.168.1.20"],
  "username": "admin",
  "command": "df -h"
}
```

```json
// Response
{
  "success": true,
  "executionId": "a1b2c3d4",
  "results": [
    {
      "host": "ubuntu-01.example.com",
      "success": true,
      "output": "Filesystem  Size  Used Avail Use% Mounted on\n/dev/sda1    50G   12G   36G  25% /",
      "error": "",
      "executionTime": 1.23
    }
  ]
}
```

</details>

---

## Prerequisites

### Windows targets — WinRM

Enable WinRM HTTPS on each target server:
```powershell
winrm quickconfig -transport:https
```

Add the account that runs PodeRemoteRunner to the **Remote Management Users** group on each target. Then verify connectivity:
```powershell
Test-WSMan -ComputerName "YOUR-SERVER" -UseSSL
```

### Linux targets — SSH

OpenSSH client must be available on the machine running PodeRemoteRunner:
```powershell
Get-Command ssh.exe
# If missing:
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

Copy your public key to each target host:
```bash
ssh-copy-id admin@your-linux-host
```

> The key path defaults to `~/.ssh/id_rsa`. Set `$SSH_KEY_PATH` at the top of `routes/ssh.ps1` to use a different key.

---

## Project Structure

```
PodeRemoteRunner/
│
├── server.ps1                 # HTTP server entry point
├── start-background.ps1       # Run server as a background job
│
├── routes/
│   ├── health.ps1             # GET  /health
│   ├── winrm.ps1              # GET  /winrm       POST /winrm/run
│   └── ssh.ps1                # GET  /ssh         POST /ssh/run
│
├── scripts/
│   ├── setup.ps1              # Requirements check and first-run setup
│
└── logs/                      
    ├── server-YYYY-MM-DD.log
    ├── requests-YYYY-MM-DD.log
    ├── requests-structured-YYYY-MM-DD.log
    ├── winrm/                 # One log file per WinRM execution
    └── ssh/                   # One log file per SSH execution
```

---

## Troubleshooting

**Find any request by TraceId across all logs:**
```powershell
Get-ChildItem "logs\" -Recurse -Filter "*.log" | Select-String "a1b2c3d4"
```

**WinRM**

| Problem | Likely cause | Solution |
|---------|-------------|----------|
| Connection refused | WinRM HTTPS not enabled | `winrm quickconfig -transport:https` on target |
| Access denied | Missing permissions | Add user to **Remote Management Users** on target |
| SSL / certificate error | Listener misconfigured | `winrm enumerate winrm/config/listener` |
| Timeout | Firewall blocking port 5986 | Open port 5986 on target firewall |

**SSH**

| Problem | Likely cause | Solution |
|---------|-------------|----------|
| `ssh.exe` not found | OpenSSH not installed | `Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0` |
| Permission denied | Key not authorized on target | `ssh-copy-id user@host` from the server machine |
| Connection timed out | Port 22 blocked or wrong host | Verify port 22 and host reachability |

**General**

| Problem | Solution |
|---------|----------|
| Port 8080 already in use | Stop the existing process or change the port in `server.ps1` |
| Pode module not found | `Install-Module -Name Pode -Scope CurrentUser` |

---

## Security

PodeRemoteRunner is designed to run inside a trusted network — not exposed to the public internet.

- **No credentials stored** — WinRM inherits the current Windows session identity; SSH uses private key files only
- **Input validation** — server names and hostnames are validated against strict patterns before use
- **Rate limiting** — 60 requests per minute per IP, enforced by Pode
- **OWASP headers** — every response includes CSP, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, and Permissions-Policy

---

## License
MIT — see [LICENSE](LICENSE)
Built on [Pode](https://github.com/Badgerati/Pode) (MIT) · Requires PowerShell 5.1+ · Windows only
