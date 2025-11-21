<#
One-shot smoke test script (PowerShell) to run locally on a developer machine with Android SDK + Flutter.
Usage: run from an elevated or normal PowerShell prompt that has flutter/adb on PATH.
Adjust the variables below if your AVD name or APK path differ.
#>

$avdCandidates = @('Pixel_9','Pixel_8')
$apkPath = Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk\app-debug.apk'
$package = 'com.example.silent_sos'
$adb = 'adb'
$flutter = 'flutter'
$serverTest = Join-Path $PSScriptRoot 'server\test_triage_integration.ps1'
$logDir = Join-Path $PSScriptRoot 'smoke-test-logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

function Check-Command($cmd) {
  try { & where.exe $cmd > $null 2>&1; return $true } catch { return $false }
}

Write-Host "Smoke test starting. Ensure server (node index.js) is running in 'server' folder. Logs will be saved to $logDir"

if (-not (Check-Command 'flutter')) { Write-Error "flutter not found on PATH. Install Flutter and add to PATH."; exit 1 }
if (-not (Check-Command 'adb')) { Write-Error "adb not found on PATH. Ensure Android SDK platform-tools are installed and on PATH."; exit 1 }

Write-Host "1) Available emulators:";
& flutter emulators --list | Write-Host

Write-Host "2) Launching emulator from candidates: $($avdCandidates -join ', ')"
# Try each AVD candidate until one starts
$launched = $false
foreach ($candidate in $avdCandidates) {
  Write-Host "Attempting to start AVD: $candidate"
  try {
    & flutter emulators --launch $candidate 2>&1 | ForEach-Object { Write-Host $_ }
    Start-Sleep -Seconds 3
    $launched = $true
    break
  } catch {
    Write-Warning "flutter emulators launch for $candidate failed, trying emulator -avd fallback"
    try {
      Start-Process -FilePath emulator -ArgumentList "-avd", $candidate -NoNewWindow -PassThru | Out-Null
      Start-Sleep -Seconds 3
      $launched = $true
      break
    } catch {
      Write-Warning "Could not start AVD $candidate via emulator -avd. Trying next candidate."
    }
  }
}
if (-not $launched) { Write-Error "Could not launch any AVD from candidates: $($avdCandidates -join ', ')"; exit 1 }

# Wait for device
$timeout = 180
$elapsed = 0
Write-Host "Waiting for device (timeout ${timeout}s)..."
while ($elapsed -lt $timeout) {
  $devices = (& adb devices) -join "`n"
  if ($devices -match 'device$') { break }
  Start-Sleep -Seconds 2
  $elapsed += 2
}
if ($elapsed -ge $timeout) { Write-Error "Timed out waiting for emulator to appear."; exit 1 }

Write-Host "Connected devices:"
& adb devices -l | Write-Host
$deviceLine = (& adb devices -l | Select-String 'device$' -Quiet) 
# choose first device id
$deviceId = (& adb devices -l | Select-String 'device' | Select-Object -First 1).ToString().Split()[0]
Write-Host "Using device: $deviceId"

# Install APK
if (-not (Test-Path $apkPath)) { Write-Error "APK not found at $apkPath; ensure you built the debug APK."; exit 1 }
Write-Host "Installing APK: $apkPath"
& adb -s $deviceId install -r $apkPath

# Launch app
Write-Host "Launching app package: $package"
& adb -s $deviceId shell monkey -p $package -c android.intent.category.LAUNCHER 1

# Capture short logcat snippet and full log file
$logFile = Join-Path $logDir "logcat_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Write-Host "Capturing 30s of logcat to $logFile"
Start-Process -FilePath powershell -ArgumentList "-NoProfile","-Command","& { adb -s $deviceId logcat -v time > '$logFile' }" -WindowStyle Hidden
Start-Sleep -Seconds 30
# Kill background logcat process (best-effort)
Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*\adb.exe' -or $_.ProcessName -like 'adb' } | ForEach-Object { try { $_.Kill() } catch {} }

# Take a screenshot
$png = Join-Path $logDir "screenshot_$(Get-Date -Format 'yyyyMMdd_HHmmss').png"
Write-Host "Taking screenshot -> $png"
& adb -s $deviceId exec-out screencap -p > $png

# Optional: run server-side triage integration (if server is running locally)
if (Test-Path $serverTest) {
  Write-Host "Running server triage integration test: $serverTest"
  try { pwsh -NoProfile -File $serverTest } catch { Write-Warning "server triage test failed or returned error." }
} else {
  Write-Host "Server triage test script not found at $serverTest; skipping.";
}

Write-Host "Smoke test complete. Logs and screenshot are in: $logDir"
