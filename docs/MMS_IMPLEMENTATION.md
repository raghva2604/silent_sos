# MMS Implementation Plan (Option B Hybrid)

This document describes the hybrid MMS implementation: a native PDU-based MMS sender (carrier-friendly) plus a server-side media upload + SMS short-link fallback. It outlines design, API, permissions, testing, and acceptance criteria.

## Goals

- Provide programmatic, silent sending of rich media (images/videos) to emergency contacts.
- Maximize delivery reliability across devices and carriers by combining a native PDU MMS flow with a server fallback that uploads media and sends SMS links.
- Provide detailed diagnostics for each recipient (success/failure, attempts, error codes).

## Overview

Two parallel tracks:

1. Native PDU MMS (long-term): Build SMIL + MIME parts, generate MMS PDU, insert into Telephony/MMS provider (content://mms) or use platform APIs and trigger send. This offers the best chance for true MMS delivery but is device/carrier dependent and requires extensive testing.

2. Server-side fallback (fast, reliable): If native MMS fails (or permissions missing), upload media to a server, return short links, and send an SMS containing the link(s). SMS delivery is far more predictable across carriers.

The app will attempt native MMS first. On failure or when native send is infeasible, it will upload and send SMS links.

---

## MethodChannel: `silent_sos/foreground` — `sendMms` (native PDU path) and server fallback

Existing `sendMms` handler accepts a Map with keys:
- `to` (String) — recipient phone number (required)
- `body` (String) — optional text
- `subject` (String) — optional
- `mediaPaths` (List<String>) — local file paths or content URIs

Behavior:
1. If `mediaPaths` contains local files/URIs, native code will attempt to prepare an MMS payload.
2. Try `SmsManager.sendMultimediaMessage` when feasible (best-effort).
3. If send fails, fallback to SMS with appended URLs (server) or appended file URIs.

New server-flow: the Dart side can POST files to `POST /upload` and receive short URLs; then call native `sendSms` with body that includes returned URLs.

---

## Server PoC API (in-repo `/server`)

- POST /upload
  - Accepts `multipart/form-data` with field `files` (one or more files).
  - Stores files in `/server/uploads` and maps an ID to each upload.
  - Returns JSON: `{ uploads: [{ id, url, filename }] }` where `url` is `http://<host>:<port>/u/<id>`.

- GET /u/:id
  - Redirects (302) to the underlying file URL, or streams the file.

Notes: PoC uses local storage and simple short IDs. Production should use authenticated uploads and durable storage (S3/GCS) with expiring signed URLs.

---

## Native PDU design notes (scoping)

- Build SMIL document referencing MIME parts.
- Construct MIME parts for each media item: correct Content-Type, Content-Location.
- Create MMS submission PDU and insert into Telephony provider (content://mms) with  `message_box` = 2 (outbox) then call Telephony to send, or use `SmsManager.sendMultimediaMessage` with prepared contentUri when available.
- Observe send results via `content://mms` columns or SENT broadcasts.
- Fallback to server upload if insert/send fails or permissions missing.

Risks: vendor-specific behavior; many devices require MMSC settings and may reject programmatic PDU submission; testing required.

---

## Permissions

- SEND_SMS (already declared) — required for silent sends.
- READ_EXTERNAL_STORAGE / or Android 13+ READ_MEDIA_IMAGES / READ_MEDIA_VIDEO — required to read files before sending or to provide content URIs.
- INTERNET — required for server upload (Flutter side will need network permissions; Android apps have network by default).

The app should gracefully request these at runtime via Flutter UI and present fallbacks when denied.

---

## Acceptance criteria

- Native PDU PoC can send a single-image MMS on at least 2 tested devices/carriers (logcat shows MMS submission and successful send OR documented failures).
- Server PoC accepts uploads and returns working short URLs that are reachable from a test device.
- Fallback flow: when native MMS fails, the server fallback is triggered and the SMS containing link(s) is sent; receipt verified via logcat and/or manual confirmation.

---

## Testing plan

- Local server test (localhost): run `/server`, POST via `curl` to /upload, confirm returned URLs work.
- Emulator test: emulator -> server (use host IP or `10.0.2.2` for Android emulator) to upload and receive URLs. Confirm SMS fallback shows link in message body.
- Real device tests: validate native PDU path and server fallback across carriers.

---

## Next steps (short-term)

1. Implement server PoC in `/server` (simple Express + Multer upload + short URL redirect). Done as PoC.
2. Add Dart UI to select files and call `/upload` (PoC) then call native `sendSms` with returned links (PoC). (I'll implement this after server PoC is in repo.)
3. Scope and implement native PDU PoC (design + small prototype) and run tests on real devices.

---

## Contacts / Notes

- This is a safety-critical flow: test carefully on real devices, and ensure users explicitly opt-in for automatic sends. The app already stores an `auto_send_opt_in` flag and checks permissions. Use the Debug UI to trigger tests and collect `debugAutoSendResult` maps from native logs.

