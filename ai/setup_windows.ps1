param(
    [string]$AiDir = "$env:ProgramData\GoStream\ai",
    [string]$LlamaRepo = 'https://github.com/ggerganov/llama.cpp.git',
    [string]$ModelUrl = 'https://huggingface.co/Qwen/Qwen3-0.6B-Q4_K_M-GGUF/resolve/main/Qwen3-0.6B-Q4_K_M.gguf'
)
$ErrorActionPreference = 'Stop'
$models = Join-Path $AiDir 'models'
$llama = Join-Path $AiDir 'llama.cpp'
New-Item -ItemType Directory -Force -Path $models | Out-Null
if (-not (Test-Path $llama)) { git clone $LlamaRepo $llama }
cmake -S $llama -B (Join-Path $llama 'build')
cmake --build (Join-Path $llama 'build') --config Release
$modelFile = Join-Path $models 'Qwen_Qwen3-0.6B-Q4_K_M.gguf'
if (-not (Test-Path $modelFile)) { Invoke-WebRequest -Uri $ModelUrl -OutFile $modelFile }
Write-Host "AI setup complete: $modelFile"
