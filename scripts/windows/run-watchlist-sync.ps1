param([string]$Python='python')
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$env:MKV_PROXY_CONFIG_PATH = Join-Path $repoRoot 'config.json'
& $Python (Join-Path $repoRoot 'scripts\plex-watchlist-sync.py') @Args
