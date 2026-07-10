# Uninstall existing app and install new APK on the emulator
# Usage: .\scripts\install_apk.ps1 -DeviceId emulator-5554 -ApkPath build\app\outputs\flutter-apk\app-release.apk
param(
    [string]$DeviceId = "emulator-5554",
    [string]$ApkPath = "build\app\outputs\flutter-apk\app-release.apk"
)

function Find-ADB {
    if (Get-Command adb -ErrorAction SilentlyContinue) { return "adb" }
    $sdk = $env:ANDROID_SDK_ROOT
    if (-not $sdk) { $sdk = "$env:LOCALAPPDATA\Android\Sdk" }
    $adbPath = Join-Path $sdk "platform-tools\adb.exe"
    if (Test-Path $adbPath) { return $adbPath }
    return $null
}

$adb = Find-ADB
if (-not $adb) {
    Write-Host "adb not found on PATH or ANDROID_SDK_ROOT. Falling back to 'flutter install'."
    flutter install -d $DeviceId
    exit $LASTEXITCODE
}

Write-Host "Using adb: $adb"

# Ensure device connected
& $adb devices | Out-Null

# If package installed, uninstall first to avoid signature mismatch
$pkg = "com.example.silent_sos"
$installed = & $adb -s $DeviceId shell pm list packages $pkg 2>&1
if ($installed -like "*package:$pkg*") {
    Write-Host "Uninstalling existing package $pkg from $DeviceId"
    & $adb -s $DeviceId uninstall $pkg
}

# Install the APK
if (-not (Test-Path $ApkPath)) { Write-Error "APK not found at $ApkPath"; exit 1 }
Write-Host "Installing $ApkPath to $DeviceId"
& $adb -s $DeviceId install -r $ApkPath
$code = $LASTEXITCODE
if ($code -ne 0) { Write-Error "adb install failed with exit code $code"; exit $code }

# Launch the app
Write-Host "Launching app"
& $adb -s $DeviceId shell monkey -p $pkg -c android.intent.category.LAUNCHER 1

Write-Host "Done."