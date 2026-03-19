param([string]$ConfigPath = "$env:ProgramData\GoStream\config.json")
$ErrorActionPreference = 'Stop'
$env:MKV_PROXY_CONFIG_PATH = $ConfigPath
python "$PSScriptRoot\health-monitor.py"
