Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$aiDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modelsDir = Join-Path $aiDir 'models'
$llamaDir = Join-Path $aiDir 'llama.cpp'
$modelUrl = 'https://huggingface.co/Qwen/Qwen3-0.6B-Q4_K_M-GGUF/resolve/main/Qwen3-0.6B-Q4_K_M.gguf'
$modelFile = Join-Path $modelsDir 'Qwen_Qwen3-0.6B-Q4_K_M.gguf'

New-Item -ItemType Directory -Force -Path $modelsDir | Out-Null

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    winget install --id Git.Git --accept-package-agreements --accept-source-agreements --silent
}
if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) {
    winget install --id Kitware.CMake --accept-package-agreements --accept-source-agreements --silent
}

if (-not (Test-Path $llamaDir)) {
    git clone https://github.com/ggerganov/llama.cpp $llamaDir
}

cmake -S $llamaDir -B (Join-Path $llamaDir 'build')
cmake --build (Join-Path $llamaDir 'build') --config Release

if (-not (Test-Path $modelFile)) {
    Invoke-WebRequest -Uri $modelUrl -OutFile $modelFile
}

Write-Host 'AI setup complete.' -ForegroundColor Green
