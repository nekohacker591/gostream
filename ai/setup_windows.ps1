[CmdletBinding()]
param(
    [string]$AiDir = (Join-Path $env:LOCALAPPDATA 'GoStream\ai'),
    [string]$ModelUrl = 'https://huggingface.co/Qwen/Qwen3-0.6B-Q4_K_M-GGUF/resolve/main/Qwen3-0.6B-Q4_K_M.gguf'
)

$ErrorActionPreference = 'Stop'
$modelsDir = Join-Path $AiDir 'models'
$llamaDir = Join-Path $AiDir 'llama.cpp'
$modelFile = Join-Path $modelsDir 'Qwen_Qwen3-0.6B-Q4_K_M.gguf'
New-Item -ItemType Directory -Force -Path $modelsDir | Out-Null

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'git is required.' }
if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) { throw 'cmake is required.' }

if (-not (Test-Path $llamaDir)) { git clone https://github.com/ggerganov/llama.cpp $llamaDir }
cmake -S $llamaDir -B (Join-Path $llamaDir 'build') -DGGML_NATIVE=ON
cmake --build (Join-Path $llamaDir 'build') --config Release
if (-not (Test-Path $modelFile)) { Invoke-WebRequest -Uri $ModelUrl -OutFile $modelFile }
Write-Host 'AI setup complete.' -ForegroundColor Green
