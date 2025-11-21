<#
Downloads and extracts Vosk language models into `backend/models/vosk_<code>/model`.
Usage examples:
  # download English (default)
  pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\download_vosk_models.ps1

  # download multiple languages
  pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\download_vosk_models.ps1 -Languages en,hi,te,gu

This script is idempotent: if the target model folder already exists it will be skipped.
#>
param(
    [string]$Languages = "en"
)

$ErrorActionPreference = 'Stop'
$cwd = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $cwd

# Map language codes to Vosk model zip URLs (small models where available)
$MODEL_URLS = @{
    en = 'https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip'
    hi = 'https://alphacephei.com/vosk/models/vosk-model-small-hi-0.22.zip'
    te = 'https://alphacephei.com/vosk/models/vosk-model-small-te-0.42.zip'
    gu = 'https://alphacephei.com/vosk/models/vosk-model-small-gu-0.22.zip'
}

# ensure models directory exists
$modelsRoot = Join-Path $cwd 'models'
if (-not (Test-Path $modelsRoot)) { New-Item -ItemType Directory -Path $modelsRoot | Out-Null }

$requested = $Languages -split '[,\s]+' | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ -ne '' }

foreach ($code in $requested) {
    if (-not $MODEL_URLS.ContainsKey($code)) {
        Write-Warning "No download URL configured for language code '$code'; skipping."
        continue
    }

    $targetDir = Join-Path $modelsRoot "vosk_$code\model"
    if (Test-Path $targetDir) {
        Write-Host "Model for '$code' already installed at $targetDir — skipping."
        continue
    }

    $url = $MODEL_URLS[$code]
    $zipPath = Join-Path $modelsRoot "vosk_$code.zip"

    Write-Host "Downloading model for '$code' from $url..."
    Invoke-WebRequest -Uri $url -OutFile $zipPath

    Write-Host "Extracting $zipPath..."
    $tempDir = Join-Path $modelsRoot "vosk_${code}_temp"
    if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
    Expand-Archive -LiteralPath $zipPath -DestinationPath $tempDir -Force

    # find the extracted top-level directory (some zips include nested folder)
    $firstDir = Get-ChildItem -Path $tempDir -Directory | Select-Object -First 1
    if ($null -eq $firstDir) {
        Write-Error "Extraction failed or unexpected structure for $zipPath"
        Remove-Item -Recurse -Force $tempDir
        Remove-Item -Force $zipPath
        continue
    }

    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Write-Host "Moving extracted contents to $targetDir..."
    Get-ChildItem -Path $firstDir.FullName -Force | ForEach-Object { Move-Item -Path $_.FullName -Destination $targetDir -Force }

    # cleanup
    Remove-Item -Recurse -Force $tempDir
    Remove-Item -Force $zipPath

    Write-Host "Installed model for '$code' to $targetDir"
}

Write-Host 'All requested models processed.'
