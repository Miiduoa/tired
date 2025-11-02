# Firestore Security Rules (draft)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() {
      return request.auth != null;
    }

    // Conversations a user participates in
    match /conversations/{cid} {
      allow read, update: if isSignedIn() && request.auth.uid in resource.data.participantIds;
      allow create: if isSignedIn();

      match /messages/{mid} {
        allow read: if isSignedIn() && request.auth.uid in get(/databases/$(database)/documents/conversations/$(cid)).data.participantIds;
        allow create: if isSignedIn() && request.auth.uid in get(/databases/$(database)/documents/conversations/$(cid)).data.participantIds;
        allow update, delete: if false; // immutable
      }
    }

    // Friend graph under user namespace
    match /users/{uid} {
      allow read, write: if isSignedIn() && request.auth.uid == uid;

      match /friends/{fid} {
        allow read, write: if isSignedIn() && request.auth.uid == uid;
      }

      match /friend_requests/{rid} {
        allow read, delete: if isSignedIn() && request.auth.uid == uid;
        allow create: if isSignedIn();
        allow update: if false;
      }
    }

    // Groups and members (tenants)
    match /groups/{gid} {
      allow read: if isSignedIn();
      allow write: if false; // restrict to server or admins via custom claims

      match /members/{uid} {
        allow read: if isSignedIn();
        allow write: if false; // use callable function or server
      }

      match /invites/{inv} {
        allow read, write: if isSignedIn();
      }
    }

    // Posts (feed)
    match /posts/{pid} {
      allow read: if isSignedIn();
      allow create: if isSignedIn();
      allow update, delete: if false;
    }
  }
}
```

Notes:
- Tighten `groups/*` writes using Cloud Functions or admin SDK; above is permissive for demo.
- Consider custom claims or membership lookup to gate admin operations.

