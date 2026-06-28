<#
.SYNOPSIS
    Installs TikZoom Bot Host on Windows. Designed for VPSes that can only
    talk OUTBOUND (no inbound 80/443) -- uses Telegram long-polling and a
    Cloudflare Tunnel (`cloudflared`) for the Mini App.

.PARAMETER BotToken
    Telegram bot token for the main platform bot.

.PARAMETER AdminIds
    Comma-separated Telegram user IDs of platform admins.

.EXAMPLE
    PowerShell -ExecutionPolicy Bypass -File install.ps1 `
        -BotToken "123:ABC" -AdminIds "111,222"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$BotToken,
    [Parameter(Mandatory=$true)][string]$AdminIds,
    [string]$InstallDir = "C:\TikZoom",
    [int]$AppPort = 8000
)

$ErrorActionPreference = "Stop"
function Info($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "[OK] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[!!] $m" -ForegroundColor Yellow }

# 1. Chocolatey
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Info "Installing Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = `
        [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    $env:Path += ";C:\ProgramData\chocolatey\bin"
    Ok "Chocolatey installed."
} else { Ok "Chocolatey already present." }

# 2. Tooling
Info "Installing tooling (python, node, php, nssm, cloudflared)..."
choco install -y --no-progress python --version=3.12.7 | Out-Null
choco install -y --no-progress nodejs-lts             | Out-Null
choco install -y --no-progress php                    | Out-Null
choco install -y --no-progress nssm                   | Out-Null
choco install -y --no-progress cloudflared            | Out-Null
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + `
            [System.Environment]::GetEnvironmentVariable("Path","User")
Ok "Tooling installed."

# 3. Project layout
if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir | Out-Null }
$Repo = Join-Path $InstallDir "tikzoom-bot-host"
if (-not (Test-Path $Repo)) {
    Warn "Project not found at $Repo -- please upload the source first."
    exit 1
}
Set-Location $Repo

# 4. venv + deps
$Py = $null
foreach ($candidate in @(
    "C:\Python314\python.exe", "C:\Python313\python.exe",
    "C:\Python312\python.exe", "C:\Python311\python.exe"
)) {
    if (Test-Path $candidate) { $Py = $candidate; break }
}
if (-not $Py) {
    $cmd = Get-Command python.exe -ErrorAction SilentlyContinue |
        Where-Object { $_.Source -notlike "*WindowsApps*" } | Select-Object -First 1
    if ($cmd) { $Py = $cmd.Source }
}
if (-not $Py) { throw "No real python.exe found. Install Python first." }
Info "Using Python at: $Py"
if (-not (Test-Path .venv)) { & $Py -m venv .venv }
$VenvPy = Join-Path $Repo ".venv\Scripts\python.exe"
& $VenvPy -m pip install --upgrade pip wheel
& $VenvPy -m pip install -e .
Ok "Python deps installed."

# 5. .env
$EnvPath       = Join-Path $Repo ".env"
$FernetKey     = & $VenvPy -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
$WebhookSecret = -join ((1..40) | ForEach-Object { (65..90 + 97..122 + 48..57) | Get-Random | ForEach-Object { [char]$_ } })

$EnvBody = @"
BOT_TOKEN=$BotToken
ADMIN_IDS=$AdminIds
PUBLIC_BASE_URL=
WEBHOOK_SECRET=$WebhookSecret
FERNET_KEY=$FernetKey
HOST=127.0.0.1
PORT=$AppPort
DATA_DIR=$InstallDir\data
BOTS_DIR=$InstallDir\bots_storage
DB_PATH=$InstallDir\data\platform.db
DEFAULT_LANG=ar
TIKZOOM_POLL=1
"@
Set-Content -Path $EnvPath -Value $EnvBody -Encoding UTF8
Ok ".env written."

# 6. NSSM services -- TikZoomApp + TikZoomTunnel
$Nssm   = (Get-Command nssm).Source
$LogDir = Join-Path $InstallDir "data\logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Set-NssmService {
    param(
        [string]$Name,
        [string]$Exe,
        [string]$AppArgs,
        [string]$Cwd,
        [string]$EnvLine = ""
    )
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($svc) {
        & $Nssm stop $Name 2>&1 | Out-Null
        & $Nssm remove $Name confirm 2>&1 | Out-Null
    }
    & $Nssm install $Name $Exe $AppArgs 2>&1 | Out-Null
    & $Nssm set $Name AppDirectory $Cwd 2>&1 | Out-Null
    & $Nssm set $Name Start SERVICE_AUTO_START 2>&1 | Out-Null
    & $Nssm set $Name AppStdout (Join-Path $LogDir "$Name.log") 2>&1 | Out-Null
    & $Nssm set $Name AppStderr (Join-Path $LogDir "$Name.err") 2>&1 | Out-Null
    & $Nssm set $Name AppRotateFiles 1 2>&1 | Out-Null
    if ($EnvLine) { & $Nssm set $Name AppEnvironmentExtra $EnvLine 2>&1 | Out-Null }
    & $Nssm start $Name 2>&1 | Out-Null
    Ok "Service $Name registered + started."
}

# App service: uvicorn + polling loop
Set-NssmService `
    -Name "TikZoomApp" `
    -Exe $VenvPy `
    -AppArgs "-m uvicorn app.main:app --host 127.0.0.1 --port $AppPort" `
    -Cwd $Repo `
    -EnvLine "TIKZOOM_POLL=1"

# Tunnel service: cloudflared trycloudflare
$Cloudflared = (Get-Command cloudflared).Source
$CFLog = Join-Path $LogDir 'cloudflared.log'
Set-NssmService `
    -Name "TikZoomTunnel" `
    -Exe $Cloudflared `
    -AppArgs "tunnel --url http://127.0.0.1:$AppPort --logfile $CFLog --no-autoupdate" `
    -Cwd $InstallDir

Ok "Services registered: TikZoomApp + TikZoomTunnel."

# 7. Wait for cloudflared to assign a URL, then save it as PUBLIC_BASE_URL
Info "Waiting for Cloudflare Tunnel URL..."
$TunnelUrl = $null
$LogFile   = Join-Path $LogDir "cloudflared.log"
$Deadline  = (Get-Date).AddSeconds(60)
while ((Get-Date) -lt $Deadline -and -not $TunnelUrl) {
    Start-Sleep -Seconds 2
    if (Test-Path $LogFile) {
        $hit = Select-String -Path $LogFile -Pattern "https://[a-z0-9-]+\.trycloudflare\.com" `
                              -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) { $TunnelUrl = ([regex]"https://[a-z0-9-]+\.trycloudflare\.com").Matches($hit.Line)[0].Value }
    }
}
if ($TunnelUrl) {
    Ok "Cloudflare Tunnel: $TunnelUrl"
    # Update .env
    (Get-Content $EnvPath) -replace "^PUBLIC_BASE_URL=.*$", "PUBLIC_BASE_URL=$TunnelUrl" |
        Set-Content $EnvPath -Encoding UTF8
    & $Nssm restart TikZoomApp | Out-Null
} else {
    Warn "Did not find cloudflared URL within 60s -- check $LogFile and restart TikZoomApp once captured."
}

Write-Host ""
Ok "Install complete."
Write-Host "Logs: $LogDir"
Write-Host "Manage: nssm restart TikZoomApp / TikZoomTunnel"
Write-Host "Cloudflare URL: $TunnelUrl"
Write-Host ""
Write-Host 'Open Telegram and message your bot with /start to verify.'
