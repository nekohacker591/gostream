param()
$ErrorActionPreference = 'Stop'
$rootPath = $env:GOSTREAM_ROOT_PATH
if (-not $rootPath) { $rootPath = 'C:\gostream' }
$configPath = $env:MKV_PROXY_CONFIG_PATH
if (-not $configPath) { $configPath = Join-Path $rootPath 'config.json' }
Set-Location $rootPath
$env:MKV_PROXY_CONFIG_PATH = $configPath
& (Join-Path $rootPath 'gostream.exe') --path $rootPath
