Param(
  [string]$ModelUrl = "https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip",
  [string]$LocalParent = "tools/vosk-models",
  [string]$LocalName = "vosk-model-small-en-us-0.15",
  [string]$DevicePath = "/sdcard/vosk-model-small-en-us-0.15"
)

$LocalDir = Join-Path $LocalParent $LocalName
$zipPath = Join-Path $env:TEMP "vosk_model.zip"

if (-Not (Test-Path $LocalDir)) {
  Write-Host "Local model not found at $LocalDir. Will download $ModelUrl to $zipPath and extract."
  if (-Not (Test-Path $LocalParent)) { New-Item -ItemType Directory -Path $LocalParent -Force | Out-Null }
  try {
    Write-Host "Downloading model..."
    Invoke-WebRequest -Uri $ModelUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
  } catch {
    Write-Error "Failed to download $ModelUrl. Error: $_"
    exit 2
  }

  try {
    Write-Host "Extracting archive to temp folder..."
    $extractDir = Join-Path $env:TEMP "vosk_model_extract"
    if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue }
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

    # Try to locate the extracted model folder
    $candidate = Get-ChildItem -Directory -Path $extractDir | Where-Object {
      Test-Path (Join-Path $_.FullName 'am') -or Test-Path (Join-Path $_.FullName 'model')
    } | Select-Object -First 1

    if (-Not $candidate) {
      # Fallback: use extractDir itself
      $candidatePath = $extractDir
    } else {
      $candidatePath = $candidate.FullName
    }

    Write-Host "Moving extracted model to $LocalDir"
    if (Test-Path $LocalDir) { Remove-Item $LocalDir -Recurse -Force -ErrorAction SilentlyContinue }
    Move-Item -Path $candidatePath -Destination $LocalDir -Force
  } catch {
    Write-Error "Failed to extract/move model: $_"
    exit 3
  }
} else {
  Write-Host "Local model found at $LocalDir. Skipping download." 
}

# Find adb
$adb = (Get-Command adb -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-Not $adb) {
  $commonPaths = @("$Env:ProgramFiles\Android\platform-tools\adb.exe","$Env:ProgramFiles(x86)\Android\platform-tools\adb.exe","$Env:LocalAppData\Android\Sdk\platform-tools\adb.exe")
  foreach ($p in $commonPaths) { if (Test-Path $p) { $adb = $p; break } }
}

if (-Not $adb) {
  Write-Error "adb not found in PATH. Install Android platform-tools and ensure 'adb' is available. See https://developer.android.com/studio/releases/platform-tools"
  exit 4
}

Write-Host "Using adb: $adb"
# Check devices
& $adb devices | Out-String | Write-Host
$devices = (& $adb devices) -split "`n" | Where-Object { 
  ($_ -match "\tdevice$")
}
if (-Not $devices) {
  Write-Error "No connected device found. Make sure device is connected and authorized (USB debugging)."
  exit 5
}

Write-Host "Pushing $LocalDir -> $DevicePath"
& $adb push $LocalDir $DevicePath
if ($LASTEXITCODE -ne 0) {
  Write-Error "adb push failed (exit $LASTEXITCODE)."
  exit $LASTEXITCODE
}

Write-Host "Model pushed successfully to device: $DevicePath"
Write-Host "You can verify with: adb shell ls -la $DevicePath"
