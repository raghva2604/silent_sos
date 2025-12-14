# Silent SOS — Manual SOS / Background Recording Integration

This document explains how to run the example backend and how the Flutter app integrates with the Android foreground recording service.

1) Backend

- Install dependencies:

```powershell
cd backend_server
npm install
```

- Copy `.env.example` to `.env` and fill SMTP credentials and optionally an SMS gateway URL.

- Start server:

```powershell
npm start
```

The server listens on port `3000` by default and exposes:

- `POST /send-sos` — body: `{ meta: {...}, recipients: [{name, phone?, email?}, ...] }`
- `POST /upload-recording` — multipart upload with field `recording`

2) Flutter app integration

- The Flutter app writes `server_url` to `SharedPreferences`. `lib/services/sos_integration.dart` reads that URL and posts to `/send-sos` and `/upload-recording`.
- The native Android `ForegroundRecordingService` writes the last recording path to `FlutterSharedPreferences` key `last_native_recording_path` and broadcasts `ForegroundRecordingService.ACTION_COMPLETE` with the `path` extra. `MainActivity` forwards this to Dart via method channel `silent_sos/foreground` event `nativeRecordingComplete`.

3) Privacy & Consent

Always show the consent dialog before enabling background recording. The built-in `permission_screen.dart` includes a privacy banner and warning text for camera/microphone.
