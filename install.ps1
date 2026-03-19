Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Header([string]$Message) {
    Write-Host "`n=== $Message ===`n" -ForegroundColor Cyan
}

function Test-Command([string]$Name) {
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Ensure-WingetPackage([string]$Id, [string]$Name) {
    if (-not (Test-Command winget)) {
        throw "winget is required to install $Name automatically. Install App Installer from Microsoft Store first."
    }
    Write-Host "Installing $Name ($Id)..." -ForegroundColor Yellow
    winget install --id $Id --accept-package-agreements --accept-source-agreements --silent
}

Write-Header 'GoStream Windows installer'

if (-not (Test-Command git)) { Ensure-WingetPackage 'Git.Git' 'Git' }
if (-not (Test-Command python)) { Ensure-WingetPackage 'Python.Python.3.12' 'Python 3' }
if (-not (Test-Command go)) { Ensure-WingetPackage 'GoLang.Go' 'Go' }

$winfsp = Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like 'WinFsp*' } |
    Select-Object -First 1
if (-not $winfsp) {
    Write-Warning 'WinFsp is not installed. Install it manually from https://winfsp.dev/ before building any Windows filesystem layer.'
}

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$configExample = Join-Path $repoRoot 'config.json.example'
$configPath = Join-Path $repoRoot 'config.json'
if ((Test-Path $configExample) -and -not (Test-Path $configPath)) {
    Copy-Item $configExample $configPath
    Write-Host "Created $configPath from config.json.example" -ForegroundColor Green
}

$stateDir = Join-Path $repoRoot 'STATE'
$logsDir = Join-Path $repoRoot 'logs'
$sourceDir = Join-Path $repoRoot 'library'
$mountDir = Join-Path $repoRoot 'mount'
New-Item -ItemType Directory -Force -Path $stateDir, $logsDir, $sourceDir, $mountDir | Out-Null

Write-Header 'Python dependencies'
python -m pip install --upgrade pip
python -m pip install -r (Join-Path $repoRoot 'requirements.txt')

Write-Header 'Build notes'
Write-Host 'Use PowerShell scripts in scripts\windows\ to run sync jobs and health monitor.' -ForegroundColor Green
Write-Host 'Before building the filesystem layer on Windows, install WinFsp and adapt the Go FUSE layer to a Windows-compatible backend.' -ForegroundColor Yellow
