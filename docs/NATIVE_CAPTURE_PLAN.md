# Native Background Capture Design (draft)

Goal
- Provide a robust plan to record front+back video+audio around an SOS event while minimizing user friction and respecting platform restrictions.

Constraints & Reality
- Android OEMs increasingly restrict background camera access while the screen is off or the device is locked.
- Background services cannot reliably open camera APIs without a foreground Activity on many devices.
- Permissions (CAMERA, RECORD_AUDIO) must be requested and accepted by the user at runtime.
- Recording while on lock screen is possible if a full-screen Activity is presented with proper window flags (showWhenLocked / setTurnScreenOn) and app has camera/mic permissions.

Options

1) Foreground Activity recording (recommended)
- Flow: When fall detected, show full-screen Activity (already implemented for countdown). While Activity is visible, start simultaneous front+back camera recording using CameraX or Camera2 API in the Activity process. Stop after configured duration and upload.
- Pros: Reliable across OEMs, user-visible (better privacy), easier permission handling.
- Cons: Requires UI to be shown (but that's acceptable for most SOS flows).
- Implementation notes:
  - Use CameraX with two separate Preview/VideoCapture instances (one for front, one for back). CameraX's simultaneous use of two cameras may be device-dependent; as a fallback, capture sequentially (short two clips) when impossible.
  - Use the same MediaMuxer-based pipeline for audio mixing or use camera's VideoCapture with audio capture from a shared AudioRecord stream.
  - Record to temporary files and upload using existing server/upload flow.

2) Foreground Service with Camera2 (risky prototype)
- Flow: Start a foreground service which opens Camera2 directly and records while app is in background. Use a media projection or system overlay if needed.
- Pros: Can record without visible UI in some devices.
- Cons: Highly OEM-dependent and often restricted on Android 10+/OEMs; requires careful testing and may fail silently.
- Implementation notes:
  - Must show a persistent notification for foreground service.
  - Use Camera2 API and MediaRecorder; ensure proper permission checks for camera and microphone.
  - Implement heavy fallbacks — if camera open fails, surface to Activity approach.

3) Server-side merge / multi-clip approach (complementary)
- Record small clips (front + back) even if sequential, upload both to server and perform server-side merge/transcoding into one single clip for sharing.
- Pros: Less reliance on device-side advanced APIs; server can handle codecs and merging reliably.
- Cons: Requires network and increases server cost; privacy considerations (user must consent to uploads).

Recommended approach
- Implement Option 1 as primary: show full-screen Activity (already in place) and record front+back while Activity is visible. Use CameraX and attempt simultaneous capture; if not possible, fall back to sequential capture with short overlap.
- Implement Option 3 on the server (we added a `/merge` endpoint) to merge uploaded clips reliably. This reduces client complexity and handles devices that cannot record two cameras at once.
- Reserve Option 2 as an experimental branch only after the above are in place and tested on target OEMs.

Privacy & UX
- Always show a clear toggle in Settings to opt into automatic media recording.
- Show a pre-send confirmation if user has opted-in to media uploads (or provide an explicit 'include media' quick toggle in the CountdownDialog).
- Persist a short retention policy for server-side media (documented on server and in the app).

Next steps & checklist
- [ ] Implement CameraX-based dual-record in the full-screen Activity (prototype branch).
- [ ] Test simultaneous capture on Pixel, Samsung, Xiaomi, and Oppo devices; document failures and fallback.
- [ ] Wire server-side `/merge` endpoint and verify merged output quality/size.
- [ ] Add Settings toggle for 'auto include media in SOS' and explicit preview.
- [ ] Add telemetry/logging for failed captures to help triage OEM issues.

Estimated effort
- Client dual-record prototype: 3-5 days (including testing across 4 devices).
- Server-side merging: 0.5-1 day (already scaffolded & ffmpeg added).
- Safety/UX (settings + privacy notice): 0.5 day.

Notes
- Because of OEM fragmentation, the safest production approach is Activity-visible recording + server-side merge. Background silent capture should not be relied upon as the primary flow.

