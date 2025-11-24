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
