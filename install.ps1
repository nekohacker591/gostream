[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'GoStream'),
    [string]$PhysicalSourcePath = 'D:\GoStream\library-real',
    [string]$VirtualMountPath = 'R:\',
    [string]$GoVersion = '1.24.1',
    [switch]$SkipPythonDeps,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

function Write-Step($Message) { Write-Host "`n=== $Message ===" -ForegroundColor Cyan }
function Ensure-Dir($Path) { if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null } }

Write-Step 'Preparing directories'
Ensure-Dir $InstallDir
Ensure-Dir (Join-Path $InstallDir 'STATE')
Ensure-Dir (Join-Path $InstallDir 'logs')
Ensure-Dir $PhysicalSourcePath
if ($VirtualMountPath -match '^[A-Za-z]:\\?$') {
    cmd /c "if not exist $VirtualMountPath mkdir $VirtualMountPath" | Out-Null
} else {
    Ensure-Dir $VirtualMountPath
}

Write-Step 'Checking prerequisites'
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'git is required.' }
if (-not (Get-Command py -ErrorAction SilentlyContinue) -and -not (Get-Command python -ErrorAction SilentlyContinue)) { throw 'Python 3.9+ is required.' }
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Write-Warning 'winget not found. Install WinFSP and Go manually if missing.' }

Write-Step 'Installing WinFSP (required for the Windows filesystem layer)'
if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install --accept-package-agreements --accept-source-agreements WinFsp.WinFsp | Out-Host
}

Write-Step 'Installing Go toolchain'
if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --accept-package-agreements --accept-source-agreements GoLang.Go | Out-Host
    } else {
        throw 'Go is required and could not be auto-installed.'
    }
}

if (-not $SkipPythonDeps) {
    Write-Step 'Installing Python dependencies'
    $python = (Get-Command py -ErrorAction SilentlyContinue)?.Source
    if (-not $python) { $python = (Get-Command python).Source }
    & $python -m pip install --upgrade pip
    & $python -m pip install -r requirements.txt
}

Write-Step 'Writing Windows config.json'
$config = Get-Content config.json.example -Raw | ConvertFrom-Json
$config.physical_source_path = $PhysicalSourcePath
$config.fuse_mount_path = $VirtualMountPath
$config | Add-Member -NotePropertyName _log_dir -NotePropertyValue (Join-Path $InstallDir 'logs') -Force
$config | Add-Member -NotePropertyName _state_dir -NotePropertyValue (Join-Path $InstallDir 'STATE') -Force
$config | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $InstallDir 'config.json') -Encoding UTF8

if (-not $SkipBuild) {
    Write-Step 'Building GoStream for Windows'
    $env:CGO_ENABLED = '1'
    $env:GOOS = 'windows'
    $env:GOARCH = 'amd64'
    go build -o (Join-Path $InstallDir 'gostream.exe') .
}

Write-Step 'Registering Windows services'
$serviceScript = Join-Path $InstallDir 'Start-GoStream.ps1'
@"
`$env:MKV_PROXY_CONFIG_PATH = '$(Join-Path $InstallDir 'config.json')'
Set-Location '$InstallDir'
& '$InstallDir\gostream.exe' --path '$InstallDir'
"@ | Set-Content $serviceScript -Encoding UTF8

Write-Host 'Use one of the following service wrappers:' -ForegroundColor Green
Write-Host '  1. NSSM: nssm install GoStream powershell.exe -ExecutionPolicy Bypass -File' $serviceScript
Write-Host '  2. sc.exe with srvany / winsw if you already use those tools.'
Write-Host '  3. Scheduled Task for per-user startup if you do not need a machine service.'

Write-Step 'Done'
Write-Host "Config: $(Join-Path $InstallDir 'config.json')"
Write-Host "Logs:   $(Join-Path $InstallDir 'logs')"
