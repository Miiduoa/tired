# Firebase Functions for "Tired" App

This document outlines the necessary Firebase Functions required to support the security model of the application.

## 1. Denormalize User Permissions

**Trigger:** On write (create, update, delete) to any document in the `/memberships/{membershipId}` collection.

**Action:**

When a user's membership details change (specifically their `roleIds`), this function must recalculate their complete set of permissions for that organization and save it to a denormalized document.

**Target Document:** `/organizations/{orgId}/members/{userId}`

**Data Structure of Target Document:**
```json
{
  "userId": "string",
  "organizationId": "string",
  "name": "string", // User's name
  "permissions": {
    "create_post_in_org": true,
    "manage_org_members": false,
    "delete_organization": false,
    // ... and so on for all permissions
  }
}
```

### Logic Steps:

1.  **Get the `organizationId` and `userId`** from the modified `membership` document.
2.  **If the membership was deleted,** delete the corresponding `/organizations/{orgId}/members/{userId}` document.
3.  **If the membership was created or updated:**
    a. Fetch all roles for the organization from `/organizations/{orgId}/roles`.
    b. Get the `roleIds` from the `membership` document.
    c. Create a new, empty permission map (e.g., `allPermissions = {}`).
    d. Iterate through the fetched organization roles. If a role's ID is in the user's `roleIds`, add all of that role's `permissions` strings to the `allPermissions` map.
    e. Write the final, aggregated `allPermissions` map to the `permissions` field of the `/organizations/{orgId}/members/{userId}` document.

**Reasoning:**

Firestore security rules cannot perform complex "join" operations. It is not possible for a rule to read a `membership` document, then read multiple `role` documents, and aggregate the permissions from them in real-time.

By denormalizing the aggregated permissions into a single document per user/org, our security rules can perform a fast, efficient, and secure check with a single `get()` call. This is the standard, recommended practice for implementing role-based access control in Firestore.

## 2. Send @Mention Notifications

This function is responsible for sending push notifications when a user is mentioned in a comment. Since comments are stored differently for Tasks and Posts, two triggers are required.

### Trigger A: On Task Comment

**Trigger:** On update (`onUpdate`) of any document in the `/tasks/{taskId}` collection.

**Action:**

1.  Get the `before` and `after` data snapshots of the `Task` document.
2.  Compare the `comments` array before and after the change to find the newly added comment.
3.  If a new comment is found, check if its `mentionedUserIds` field exists and is not empty.
4.  If it is, iterate through the `mentionedUserIds`:
    a. For each `userId`, fetch that user's document from `/users/{userId}` to get their `fcmToken`.
    b. Fetch the profile of the comment author (`authorUserId`) to get their name.
    c. Construct a notification payload (e.g., Title: "Tired App", Body: `"{authorName} mentioned you in the task '{taskTitle}'"`).
    d. Send the push notification to the user's `fcmToken` using Firebase Cloud Messaging (FCM).

### Trigger B: On Post Comment

**Trigger:** On create (`onCreate`) of any document in the `/comments/{commentId}` collection. (Assuming a top-level `comments` collection for posts).

**Action:**

1.  Get the data from the newly created `Comment` document.
2.  Check if its `mentionedUserIds` field exists and is not empty.
3.  If it is, iterate through the `mentionedUserIds`:
    a. For each `userId`, fetch their `fcmToken` from `/users/{userId}`.
    b. Fetch the comment author's profile and the post title (`/posts/{postId}`).
    c. Construct a notification payload (e.g., Title: "Tired App", Body: `"{authorName} mentioned you in the post '{postTitle}'"`).
    d. Send the push notification via FCM.
