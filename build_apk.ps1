# build_apk.ps1 - build Flutter release APK and report artifact path
Set-StrictMode -Off
Push-Location 'C:\projects\silent_sos'

flutter build apk --release -v
$code = $LASTEXITCODE
if ($code -ne 0) {
    Write-Host "FLUTTER_BUILD_EXIT $code"
    exit $code
}

$apk = 'build\app\outputs\flutter-apk\app-release.apk'
if (-Not (Test-Path $apk)) {
    $found = Get-ChildItem -Path build -Recurse -Filter '*.apk' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $apk = $found.FullName } else { $apk = $null }
}

if ($apk) {
    $fi = Get-Item $apk
    Write-Host 'APK_FOUND'
    Write-Host $fi.FullName
    Write-Host ('SIZE_BYTES=' + $fi.Length)
} else {
    Write-Host 'APK_NOT_FOUND'
}

Pop-Location
