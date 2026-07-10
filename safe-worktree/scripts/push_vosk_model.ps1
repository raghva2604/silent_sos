Param(
  [string]$LocalModelPath = "./vosk-model-small-en-us-0.15",
  [string]$DevicePath = "/sdcard/vosk-model-small-en-us-0.15"
)

if (-Not (Test-Path $LocalModelPath)) {
  Write-Error "Local model path not found: $LocalModelPath"
  exit 1
}

Write-Host "Pushing Vosk model from $LocalModelPath to device:$DevicePath"
adb push $LocalModelPath $DevicePath
if ($LASTEXITCODE -ne 0) {
  Write-Error "adb push failed (exit $LASTEXITCODE). Ensure adb is in PATH and device is connected."
  exit $LASTEXITCODE
}
Write-Host "Model pushed successfully."
