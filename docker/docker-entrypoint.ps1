$ErrorActionPreference = 'Stop'

$configPath = $env:MKV_PROXY_CONFIG_PATH; if (-not $configPath) { $configPath = 'C:\gostream\config.json' }
$rootPath = $env:GOSTREAM_ROOT_PATH; if (-not $rootPath) { $rootPath = 'C:\gostream' }
$sourcePath = $env:GOSTREAM_SOURCE_PATH; if (-not $sourcePath) { $sourcePath = 'C:\gostream\library' }
$mountPath = $env:GOSTREAM_MOUNT_PATH; if (-not $mountPath) { $mountPath = 'C:\gostream\mount' }
$stateDir = $env:GOSTREAM_STATE_DIR; if (-not $stateDir) { $stateDir = Join-Path $rootPath 'STATE' }
$logDir = $env:GOSTREAM_LOG_DIR; if (-not $logDir) { $logDir = Join-Path $rootPath 'logs' }
$healthPort = $env:HEALTH_MONITOR_PORT; if (-not $healthPort) { $healthPort = '8095' }

New-Item -ItemType Directory -Force -Path $rootPath, $sourcePath, $mountPath, $stateDir, $logDir | Out-Null
if (-not (Test-Path $configPath)) { throw "Missing required config file at $configPath" }

$health = Start-Process -FilePath 'python' -ArgumentList 'C:\app\scripts\health-monitor.py' -PassThru -WindowStyle Hidden
$gostream = Start-Process -FilePath 'C:\app\gostream.exe' -ArgumentList @('--path', $rootPath, $sourcePath, $mountPath) -PassThru -WindowStyle Hidden

while ($true) {
    Start-Sleep -Seconds 1
    if ($health.HasExited) { throw 'health-monitor exited; stopping container' }
    if ($gostream.HasExited) { exit $gostream.ExitCode }
}
