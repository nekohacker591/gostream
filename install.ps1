param(
    [string]$InstallDir = "$env:ProgramData\GoStream",
    [string]$LibraryPath = "C:\GoStream\library",
    [string]$MountPath = "G:\",
    [string]$GoVersion = "1.24.0"
)

$ErrorActionPreference = 'Stop'

function Write-Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Ensure-Command($name, $hint) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) { throw "$name not found. $hint" }
}

Write-Step 'Preparing directories'
New-Item -ItemType Directory -Force -Path $InstallDir, $LibraryPath, (Join-Path $LibraryPath 'movies'), (Join-Path $LibraryPath 'tv'), (Join-Path $InstallDir 'STATE'), (Join-Path $InstallDir 'logs') | Out-Null

Write-Step 'Checking Windows dependencies'
Ensure-Command git 'Install Git for Windows first.'
Ensure-Command python 'Install Python 3.9+ first.'
Ensure-Command go 'Install Go first or rerun after updating PATH.'
if (-not (Get-Service -Name WinFsp.Launcher -ErrorAction SilentlyContinue)) {
    Write-Warning 'WinFsp service not detected. Install WinFsp before starting GoStream.'
}

Write-Step 'Writing sample config'
$configPath = Join-Path $InstallDir 'config.json'
if (-not (Test-Path $configPath)) {
@" 
{
  "physical_source_path": "$($LibraryPath -replace '\\','\\\\')",
  "fuse_mount_path": "$($MountPath -replace '\\','\\\\')",
  "gostorm_url": "http://127.0.0.1:8090",
  "proxy_listen_port": 8080,
  "metrics_port": 8096
}
"@ | Set-Content -Encoding UTF8 $configPath
}

Write-Step 'Installing Python requirements'
pip install -r requirements.txt

Write-Step 'Building GoStream'
$env:CGO_ENABLED='1'
go build -pgo=auto -o (Join-Path $InstallDir 'gostream.exe') .

Write-Step 'Registering Windows services'
$gostreamExe = Join-Path $InstallDir 'gostream.exe'
$gostreamBin = '"{0}" --path "{1}" "{2}" "{3}"' -f $gostreamExe, $InstallDir, $LibraryPath, $MountPath
sc.exe create GoStream binPath= $gostreamBin start= auto | Out-Null
$healthBin = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{0}" -ConfigPath "{1}"' -f (Join-Path (Get-Location) 'scripts\Start-HealthMonitor.ps1'), $configPath
sc.exe create GoStreamHealthMonitor binPath= $healthBin start= auto | Out-Null

Write-Step 'Done'
Write-Host "GoStream Windows port files prepared in $InstallDir" -ForegroundColor Green
