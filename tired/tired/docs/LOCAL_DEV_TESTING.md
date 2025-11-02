# Local Dev & Testing Guide

This guide helps you run the app locally, seed minimal data, test deep links, and verify uploads/attachments.

## 1) Backend (demo) setup

- Install deps and run server:

```
cd backend
npm i
npm run dev
```

- The server exposes:
  - POST /v1/upload (octet-stream or JSON base64)
  - POST /v1/clock/records, POST /v1/attendance/check
  - POST /v1/attendance/sessions, POST /v1/attendance/sessions/:id/close

- Optional seed for Firestore (uses a service account):

```
cd backend
GOOGLE_APPLICATION_CREDENTIALS=path/to/sa.json PROJECT_ID=YOUR_PROJECT npm run seed
```

## 2) iOS app configuration

- Ensure `TIRED_API_URL` is set for the run scheme (e.g., http://localhost:3000). In Xcode:
  - Edit Scheme → Run → Arguments → Environment Variables → Add `TIRED_API_URL=http://localhost:3000`

- Permissions in Info.plist:
  - NSCameraUsageDescription (QR scan)
  - NSPhotoLibraryUsageDescription / NSPhotoLibraryAddUsageDescription (save to photos)
  - URL Schemes: `tired` (deep links), Google Sign-In

## 3) Firestore rules + indexes

- Deploy rules & indexes:

```
cd tired/tired/firebase
firebase deploy --only firestore:rules,firestore:indexes --project YOUR_PROJECT
```

- Docs:
  - FIRESTORE_RULES.md
  - FIRESTORE_INDEXES.md

## 4) Deep link testing

- With iOS Simulator:

```
# Open a chat by conversation id
xcrun simctl openurl booted "tired://chat?cid=YOUR_CONVERSATION_ID"

# Open attendance with a session id
xcrun simctl openurl booted "tired://attendance?sessId=today-YOUR_GROUP_ID"
```

- Alternatively, use helper script:

```
./tired/tired/scripts/deeplink.sh chat YOUR_CONVERSATION_ID
./tired/tired/scripts/deeplink.sh attendance today-YOUR_GROUP_ID
```

## 5) Features to verify

- Offline + Outbox: Broadcast/Inbox/Clock/Attendance actions queue offline and flush on foreground.
- Chat:
  - Realtime conversations/messages (Firestore listener)
  - Unread badge with reads tracking
  - Start new conversation, user directory picker
  - Attachments: images/videos upload, percent progress, inline video playback, QuickLook preview, share, save-to-photos
- Attendance:
  - QR scanning, deep link submit
  - Start/close session (manager)
- Member management: role change + invite

## 6) Troubleshooting

- If deep link shows no content:
  - Ensure user is signed in
  - Verify conversation exists and user participates
  - Verify a membership is active for attendance deep link
- If uploads fail:
  - Confirm TIRED_API_URL points to backend server
  - Check upload size limits in Info.plist (MAX_* keys)

