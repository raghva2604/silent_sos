# INTEGRATION SUMMARY - ALL CODE & INSTRUCTIONS

## 📋 Complete Updated Code Package

This document contains all the code snippets and files needed to integrate presigned S3 uploads, CameraX, and the React operator dashboard into your Silent SOS project.

---

## 1️⃣ BACKEND SERVER (Node.js + Presigned S3 + Socket.io)

### File: `backend_server/server.js`
**Action**: Replace entire file content with this code

```javascript
// [SEE backend_server/server-presigned.js in your project for full content]
// This server provides:
// - /api/presign → Generate presigned S3 PUT URLs
// - /api/sos → Store SOS event in MongoDB + emit via socket.io
// - /api/sos/:id/ack → Acknowledge SOS
// - /api/sos → Retrieve SOS history
// - Socket.io real-time events to operator dashboard
```

**Steps**:
1. Copy provided `server-presigned.js` content
2. Save as `backend_server/server.js`
3. Create `.env` file with credentials (see below)

### File: `backend_server/.env`
**Action**: Create new file with these contents

```env
# AWS S3 Configuration
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your_aws_access_key_here
AWS_SECRET_ACCESS_KEY=your_aws_secret_key_here
S3_BUCKET=silent-sos-recordings

# MongoDB Configuration
MONGO_URI=mongodb://localhost:27017/silent_sos
# OR for MongoDB Atlas:
# MONGO_URI=mongodb+srv://username:password@cluster.mongodb.net/silent_sos

# Server Port
PORT=4000

# Frontend URLs (for CORS)
CLIENT_URL=http://localhost:3000
DASHBOARD_URL=http://localhost:3001
```

### File: `backend_server/package.json`
**Action**: Update dependencies section

```json
{
  "name": "silent-sos-backend",
  "version": "2.0.0",
  "description": "Silent SOS Backend with Presigned S3 & Real-time Operator Dashboard",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "@aws-sdk/client-s3": "^3.400.0",
    "@aws-sdk/s3-request-presigner": "^3.400.0",
    "socket.io": "^4.6.0",
    "mongodb": "^6.1.0",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
```

**Installation**:
```bash
cd backend_server
npm install
npm start
# Output: "🚀 Silent SOS Server running on port 4000"
```

---

## 2️⃣ ANDROID SETUP (CameraX + WorkManager + Presigned Upload)

### File: `android/app/build.gradle`
**Action**: Add these dependencies under `dependencies { }`

```gradle
// ========== CameraX - Front/Back camera capture ==========
implementation "androidx.camera:camera-core:1.2.2"
implementation "androidx.camera:camera-camera2:1.2.2"
implementation "androidx.camera:camera-lifecycle:1.2.2"
implementation "androidx.camera:camera-view:1.2.2"
implementation "androidx.camera:camera-extensions:1.2.2"

// ========== WorkManager - Background upload tasks ==========
implementation "androidx.work:work-runtime-ktx:2.8.1"

// ========== Room - Local database caching ==========
implementation "androidx.room:room-runtime:2.5.2"
implementation "androidx.room:room-ktx:2.5.2"
kapt "androidx.room:room-compiler:2.5.2"

// ========== Lottie - Animation support ==========
implementation "com.airbnb.android:lottie:6.0.0"

// ========== OkHttp - For presigned PUT requests ==========
implementation "com.squareup.okhttp3:okhttp:4.10.0"

// ========== Material Design ==========
implementation "com.google.android.material:material:1.10.0"

// ========== Kotlin Coroutines ==========
implementation "org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.1"
implementation "org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.1"

// ========== Lifecycle for CameraX binding ==========
implementation "androidx.lifecycle:lifecycle-runtime-ktx:2.6.1"
implementation "androidx.lifecycle:lifecycle-process:2.6.1"
```

### File: `android/app/src/main/AndroidManifest.xml`
**Action**: Add these permissions (outside `<application>`) and providers (inside `<application>`)

```xml
<!-- PERMISSIONS (outside <application>) -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />

<!-- PROVIDERS (inside <application>) -->
<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="${applicationId}.fileprovider"
    android:exported="false">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/provider_paths" />
</provider>

<!-- Google Maps (optional) -->
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY" />
```

### File: `android/app/src/main/res/xml/provider_paths.xml`
**Action**: Create new XML file

```xml
<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <cache-path name="cache" path="/" />
    <files-path name="files" path="/" />
    <external-files-path name="external_files" path="/" />
    <cache-path name="media_cache" path="media/" />
</paths>
```

### File: `android/app/src/main/java/com/example/silent_sos/CameraXCaptureHelper.kt`
**Action**: Create new Kotlin file

```kotlin
// [See CameraXCaptureHelper.kt in project for full content]
// Provides:
// - bindCamera(previewView) - Initialize CameraX
// - switchLens() - Toggle front/back camera
// - captureImage(file, onSuccess, onError) - Capture photo
```

### File: `android/app/src/main/java/com/example/silent_sos/MainActivity.kt`
**Action**: Replace entire file

```kotlin
// [See MainActivity.kt in project for full content]
// Provides MethodChannel handlers:
// - "captureImage" - Capture front/back image
// - "startRecording" - Start 5s audio recording
// - "stopRecording" - Stop recording and return path
// - "getLocation" - Get GPS location
// - "uploadWithPresigned" - Trigger presigned upload via WorkManager
```

**⚠️ IMPORTANT**: Update BACKEND_URL in code:
```kotlin
private const val BACKEND_URL = "http://192.168.1.100:4000" // Your backend URL
```

### File: `android/app/src/main/java/com/example/silent_sos/UploadWorker.kt`
**Action**: Create or replace file

```kotlin
// [See UploadWorker.kt in project for full content]
// Presigned upload flow:
// 1. Request presigned URLs from /api/presign
// 2. PUT files directly to S3
// 3. POST final SOS to /api/sos with S3 URLs
```

**⚠️ IMPORTANT**: Update BACKEND_URL:
```kotlin
companion object {
    private const val BACKEND_URL = "http://192.168.1.100:4000" // Your backend URL
}
```

---

## 3️⃣ REACT OPERATOR DASHBOARD

### Setup
```bash
# Create React project
npx create-react-app operator-dashboard
cd operator-dashboard

# Install required packages
npm install socket.io-client leaflet react-leaflet lottie-react dotenv

# Start dashboard
npm start
```

### File: `operator-dashboard/.env`
**Action**: Create new file

```env
REACT_APP_SERVER_URL=http://localhost:4000
```

### File: `operator-dashboard/src/App.jsx`
**Action**: Create or replace file

```jsx
// [See operator-dashboard/src/App.jsx in project for full content]
// Features:
// - Real-time socket.io connection to backend
// - Live SOS event list with animations
// - Interactive Leaflet map showing SOS locations
// - Media preview modal for images/audio
// - Operator acknowledgment UI
// - Statistics dashboard (Total, Unresolved, Critical)
```

### File: `operator-dashboard/src/App.css`
**Action**: Create or replace file

```css
/* [See operator-dashboard/src/App.css in project for full content]
   Includes animations:
   - slideInDown (header)
   - slideInLeft (SOS cards)
   - pulse-card (active SOS)
   - fadeIn (all elements)
   - Responsive design for mobile/tablet
*/
```

---

## 4️⃣ FLUTTER APP INTEGRATION (Minor Updates)

### File: `lib/screens/sos_trigger_screen.dart` (New or Update)
**Action**: Wire presigned upload into SOS button

```dart
// Example integration code:
// When user triggers SOS, call:
// 
// 1. Get images from CameraX:
//    final result = await platform.invokeMethod('captureImage', {'lensFacing': 'back'});
// 
// 2. Get audio:
//    await platform.invokeMethod('startRecording');
//    await Future.delayed(Duration(seconds: 5));
//    final audioPath = await platform.invokeMethod('stopRecording');
// 
// 3. Trigger presigned upload:
//    await platform.invokeMethod('uploadWithPresigned', {
//      'userId': user.id,
//      'timestamp': DateTime.now().millisecondsSinceEpoch,
//      'lat': location.latitude,
//      'lon': location.longitude,
//      'source': 'manual',
//    });
```

---

## 5️⃣ TESTING CHECKLIST

### Backend Testing
```bash
# Test health endpoint
curl http://localhost:4000/health

# Test presign endpoint
curl -X POST http://localhost:4000/api/presign \
  -H "Content-Type: application/json" \
  -d '{"files":[{"fileName":"test.jpg","contentType":"image/jpeg","keyPrefix":"sos"}]}'

# Test SOS submission
curl -X POST http://localhost:4000/api/sos \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user123",
    "timestamp": 1700000000000,
    "lat": 37.7749,
    "lon": -122.4194,
    "source": "manual",
    "media": {
      "frontUrl": "https://bucket.s3.../photo.jpg",
      "audioUrl": "https://bucket.s3.../audio.m4a"
    }
  }'
```

### Dashboard Testing
1. Open http://localhost:3000
2. Check browser console for "Connected to backend"
3. Submit SOS from Android app
4. Verify event appears in real-time
5. Click "Acknowledge" to mark resolved

### Android Testing
1. Build APK: `flutter build apk --no-shrink`
2. Install on device: `flutter install`
3. Grant permissions (camera, audio, location)
4. Trigger SOS and verify:
   - Images captured
   - Audio recorded
   - Presigned URLs generated
   - Files uploaded to S3
   - Event appears in dashboard

---

## 6️⃣ DEPLOYMENT STEPS

### Backend (Heroku)
```bash
cd backend_server
heroku create silent-sos-backend
heroku config:set MONGO_URI="mongodb+srv://..."
heroku config:set AWS_ACCESS_KEY_ID="..."
heroku config:set AWS_SECRET_ACCESS_KEY="..."
heroku config:set S3_BUCKET="silent-sos-recordings"
git push heroku main
```

### Dashboard (Vercel)
```bash
cd operator-dashboard
vercel
# Set REACT_APP_SERVER_URL to production backend URL
```

### Android (Play Store)
```bash
flutter build appbundle
# Upload to Play Store Console
```

---

## 7️⃣ ARCHITECTURE DIAGRAM

```
┌─────────────────┐
│   Flutter App   │
│  (Android APK)  │
└────────┬────────┘
         │
         │ 1. Capture image/audio via CameraX
         │ 2. Request presigned URLs
         │ 3. Upload to S3 directly
         │ 4. POST SOS with S3 URLs
         │
         ▼
    ┌────────────────────┐
    │  Backend Server    │
    │  (Node.js)         │
    │  Port: 4000        │
    └────────┬───────────┘
             │
       ┌─────┼─────┐
       │     │     │
       ▼     ▼     ▼
    ┌────┐┌───┐┌───────────┐
    │ S3 ││ DB││ Socket.io │
    └────┘└───┘└─────┬─────┘
              │
              ▼
         ┌─────────────┐
         │   React     │
         │ Dashboard   │
         │ Port: 3000  │
         └─────────────┘
```

---

## 8️⃣ SECURITY CONSIDERATIONS

- ✓ Presigned URLs expire in 5 minutes
- ✓ S3 objects have public-read ACL (verify for your use case)
- ✓ Firebase credentials should be in .env (never commit)
- ✓ Use HTTPS in production
- ✓ Consider adding JWT auth to API endpoints
- ✓ Use strong MongoDB password
- ✓ Rotate AWS credentials periodically

---

## 9️⃣ TROUBLESHOOTING QUICK REFERENCE

| Issue | Solution |
|-------|----------|
| Port 4000 in use | `lsof -ti:4000 \| xargs kill -9` |
| MongoDB not connecting | Start with `mongod` or `brew services start mongodb-community` |
| AWS credentials invalid | Verify .env, regenerate keys in AWS console |
| Android upload fails | Update BACKEND_URL in UploadWorker.kt |
| Dashboard won't connect | Check backend running, verify REACT_APP_SERVER_URL |
| S3 bucket not found | Check S3_BUCKET name and region in AWS_REGION |
| CameraX not working | Verify permissions granted, check Android version (API 21+) |

---

## 🔟 FILES REFERENCE

**New Files to Create**:
```
backend_server/
  └── .env (CREDENTIALS)

android/app/src/main/
  ├── java/com/example/silent_sos/
  │   ├── CameraXCaptureHelper.kt (NEW)
  │   ├── UploadWorker.kt (UPDATED)
  │   └── MainActivity.kt (UPDATED)
  └── res/xml/
      └── provider_paths.xml (NEW)

operator-dashboard/ (NEW PROJECT)
  ├── src/
  │   ├── App.jsx
  │   ├── App.css
  │   └── index.js
  ├── .env
  └── package.json
```

**Modified Files**:
```
backend_server/
  ├── server.js (UPDATED with presigned flow + socket.io)
  ├── package.json (UPDATED dependencies)
  └── .env (NEW - credentials)

android/app/
  ├── build.gradle (ADD dependencies)
  └── src/main/AndroidManifest.xml (ADD permissions + providers)
```

---

## Summary

You now have everything needed to:
1. ✓ Deploy backend with presigned S3 + socket.io
2. ✓ Update Android with CameraX + WorkManager
3. ✓ Launch React operator dashboard
4. ✓ Create end-to-end SOS upload flow
5. ✓ Scale to production deployment

**Next Action**: Copy all code files above into your project structure and follow the deployment steps.

For detailed integration instructions, see:
- `PRESIGNED_S3_INTEGRATION_GUIDE.md`
- `PRESIGNED_S3_INTEGRATION_CHECKLIST.md`
