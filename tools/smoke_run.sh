#!/usr/bin/env bash
set -euo pipefail

# CONFIG - change these if needed
ADB=${ADB:-adb}
APK_PATH=${APK_PATH:-build/app/outputs/flutter-apk/app-release.apk}
SERVER_URL=${SERVER_URL:-http://10.0.2.2:3000} # emulator host -> backend node
VOSK_LOCAL_DIR=${VOSK_LOCAL_DIR:-./vosk-model-small-en-us-0.15}
MODEL_IMAGE_TFLITE=${MODEL_IMAGE_TFLITE:-training/output/danger_image_model.tflite}
MODEL_FALL_TFLITE=${MODEL_FALL_TFLITE:-training/output/fall_detector_model.tflite}
REMOTE_VOSK_PATH="/sdcard/vosk-model-small"

echo "1) Push Vosk model to device (if exists)"
if [ -d "$VOSK_LOCAL_DIR" ]; then
  echo "Pushing vosk model..."
  $ADB push "$VOSK_LOCAL_DIR" "$REMOTE_VOSK_PATH"
else
  echo "Vosk local folder not found at $VOSK_LOCAL_DIR — skip push (downloader can be used)"
fi

echo "2) Push TFLite models to device (flutter assets path and android assets)"
if [ -f "$MODEL_IMAGE_TFLITE" ]; then
  $ADB push "$MODEL_IMAGE_TFLITE" /sdcard/danger_image_model.tflite || true
fi
if [ -f "$MODEL_FALL_TFLITE" ]; then
  $ADB push "$MODEL_FALL_TFLITE" /sdcard/fall_detector_model.tflite || true
fi

echo "3) Install APK"
if [ -f "$APK_PATH" ]; then
  $ADB install -r "$APK_PATH"
else
  echo "APK not found at $APK_PATH. Please build your APK with 'flutter build apk --no-shrink'"
  exit 1
fi

echo "4) Grant permissions"
$ADB shell pm grant com.example.silent_sos android.permission.RECORD_AUDIO || true
$ADB shell pm grant com.example.silent_sos android.permission.CAMERA || true
$ADB shell pm grant com.example.silent_sos android.permission.ACCESS_FINE_LOCATION || true
$ADB shell pm grant com.example.silent_sos android.permission.RECEIVE_BOOT_COMPLETED || true

echo "5) Start app (bring to foreground)"
$ADB shell monkey -p com.example.silent_sos -c android.intent.category.LAUNCHER 1

echo "6) Quick upload test: upload a small file as recording"
echo "hello test" > /tmp/test_recording.txt
curl -v -F "recording=@/tmp/test_recording.txt" "$SERVER_URL/upload_recording"

echo "7) Send send-sos referencing returned path (replace <PATH_FROM_UPLOAD> with returned path manually if needed)"
cat <<EOF
Manual step:
 - After upload above note the returned "path" value (e.g. /path/to/uploads/...). Then run:
curl -X POST $SERVER_URL/send-sos -H "Content-Type: application/json" -d '{"meta":{"user":"Smoke Test","time":"'"$(date -Iseconds)"'","lat":0,"lon":0,"event":"smoke"},"recipients":[{"email":"test@example.com"}],"recordingPath":"<REPLACE_WITH_UPLOADED_PATH>"}'
EOF

echo "8) Simulate SAFE reply (mark resolved)"
echo "To mark resolved run:"
echo "curl -X POST $SERVER_URL/sms-webhook -d \"Body=SAFE\" -d \"From=+10000000000\""

echo "SMOKE SCRIPT completed. Follow printed manual steps above to finish full pipeline test."
