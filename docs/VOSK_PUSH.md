Push Vosk model to device

This repository includes two helper scripts to place a Vosk wakeword model onto an Android device:

- `scripts/push_vosk_model.ps1` — pushes an existing local model folder to device (requires `adb`).
- `scripts/download_and_push_vosk.ps1` — downloads the official `vosk-model-small-en-us-0.15.zip`, extracts it into `tools/vosk-models/vosk-model-small-en-us-0.15`, and then pushes it to the device (requires `adb`).

Quick checklist

1. Install `adb` (Android platform-tools) and ensure it's in PATH.
   - Official: https://developer.android.com/studio/releases/platform-tools
   - Chocolatey (if installed): `choco install adb`
   - Scoop (if installed): `scoop install adb`

2. If you have the model locally, push it:

```powershell
# From repository root, replace with your real path:
.\scripts\push_vosk_model.ps1 -LocalModelPath 'C:\models\vosk-model-small-en-us-0.15' -DevicePath '/sdcard/vosk-model-small-en-us-0.15'
```

3. To download & push in a single step (default):

```powershell
.\scripts\download_and_push_vosk.ps1
```

4. Verify files on device:

```powershell
adb devices
adb shell ls -la /sdcard/vosk-model-small-en-us-0.15
```

Notes

- The helper scripts run `adb push` and expect a connected & authorized device (USB debugging enabled).
- If your model is a zip, the download helper will extract it; if you have another archive, extract locally first.
- The HotwordService expects a model directory on device and a `model` / `am` style files depending on the Vosk package.

If you want, I can:
- Download the model into the repo for you (requires internet access); or
- Attempt to push the model from this machine (requires `adb` + a connected device here).

If you prefer I can also try upgrading Flutter dependencies (`flutter pub upgrade --major-versions`) and run `flutter analyze`/`flutter test` after — say the word and I'll start that next.