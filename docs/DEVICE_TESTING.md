# Device Testing Checklist

This checklist helps validate the core SilentSOS flows on a device/emulator.

Prerequisites
- Android device (recommended: Pixel, Samsung, Xiaomi for OEM variety)
- Ensure the app is installed (debug/release build as needed)
- Network access (for Firebase uploads and server tests)

Permissions
- Verify the app requests and is granted:
  - Location (foreground; optionally background for background location)
  - Camera & Microphone (if recording enabled)
  - SEND_SMS (if native auto-send desired)
  - POST_NOTIFICATIONS (Android 13+)

Tests
1. Basic boot
- Launch the app, observe splash and Home screen.
- Go to Settings and confirm values load.

2. Fall detection and full-screen alert
- Start fall detection (if app exposes control) or simulate device acceleration via adb/sensor tools.
- Confirm native full-screen notification appears and wakes the device/lock-screen.
- Tap the notification and confirm CountdownDialog opens in the app.

3. Auto-send SMS behavior
- In Settings, enable 'Native auto-send SMS'. Ensure SEND_SMS permission is granted.
- Trigger a fall and let countdown elapse.
- Confirm SMS were sent (check recipient device OR use logs).
- If SEND_SMS not granted: confirm SMS composer opens per recipient as fallback.

4. Media recording and upload
- Enable automatic video and audio in Settings.
- Trigger a manual SOS and allow recording when prompted.
- After send, confirm media URLs are present in sent SMS (links).
- Verify uploaded media is accessible (check Firebase Storage console or open the URL).

5. Per-recipient status
- After send, check the CountdownDialog shows which contacts were Sent/Queued/Failed.

6. WhatsApp backend (mock)
- If using mock server mode, send an SOS and confirm the backend responded with a simulated OK.
- When ready to test real WhatsApp, provide server credentials and retest end-to-end.

7. Edge cases
- Reject camera/mic permissions and confirm app gracefully queues or falls back.
- Deny SEND_SMS and confirm fallback works.
- Test with long SMS (message with media links + place info) to confirm multipart SMS delivery.

Logs and debugging

Notes

If you'd like, I can produce a small shell/PowerShell script that automates some of these adb-based checks (simulate sensor, pull logs).
Script: `server/scripts/device_test.ps1`
- This PowerShell helper collects logs and artifacts and now compresses them into a ZIP file for easier sharing.
- Usage examples:
  - Run locally and save artifacts:
    powershell -File server\scripts\device_test.ps1 -OutDir .\out
  - Run and upload the artifact to a dev server (the script supports `-UploadUrl` and reads `DEVICE_TEST_UPLOAD_URL` env var):
    powershell -File server\scripts\device_test.ps1 -OutDir .\out -UploadUrl https://dev.example.com/upload -ApiKey YOUR_API_KEY

Notes on upload
- The upload is a simple HTTP POST with Content-Type: application/zip. If your dev server needs a specific shape (multipart form with metadata), tell me and I'll adapt the script to send form data instead.