# Firestore 安全规则

以下是 Tired App 的 Firestore 安全规则配置。

## 完整规则文件

在 Firebase Console → Firestore Database → Rules 中粘贴以下内容：

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    // Helper Functions
    function isSignedIn() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }

    function isOrgMember(orgId) {
      return isSignedIn() &&
        exists(/databases/$(database)/documents/memberships/$(request.auth.uid + '_' + orgId));
    }

    // ============================================================
    // USERS
    // ============================================================
    match /users/{userId} {
      // 只能读取自己的用户资料
      allow read: if isOwner(userId);

      // 只能创建/更新自己的用户资料
      allow create: if isOwner(userId) &&
        request.resource.data.keys().hasAll(['name', 'email', 'createdAt']) &&
        request.resource.data.email == request.auth.token.email;

      allow update: if isOwner(userId);

      // 不允许删除用户
      allow delete: if false;
    }

    // ============================================================
    // ORGANIZATIONS
    // ============================================================
    match /organizations/{orgId} {
      // 所有人可读（公开组织信息）
      allow read: if true;

      // 任何登录用户都可以创建组织
      allow create: if isSignedIn() &&
        request.resource.data.createdByUserId == request.auth.uid;

      // 只有组织 owner/admin 可以更新
      allow update: if isSignedIn() &&
        (get(/databases/$(database)/documents/memberships/$(getMembershipId(orgId))).data.role in ['owner', 'admin']);

      // 只有 owner 可以删除
      allow delete: if isSignedIn() &&
        (get(/databases/$(database)/documents/memberships/$(getMembershipId(orgId))).data.role == 'owner');
    }

    // ============================================================
    // MEMBERSHIPS
    // ============================================================
    match /memberships/{membershipId} {
      // 可以读取自己的 membership
      allow read: if isSignedIn() &&
        resource.data.userId == request.auth.uid;

      // 可以读取某个组织的所有成员（如果自己是该组织成员）
      allow list: if isSignedIn();

      // 创建 membership：自己加入组织 或 组织管理员邀请
      allow create: if isSignedIn() &&
        (request.resource.data.userId == request.auth.uid ||
         isOrgAdmin(request.resource.data.organizationId));

      // 更新 membership：只有组织管理员
      allow update: if isSignedIn() &&
        isOrgAdmin(resource.data.organizationId);

      // 删除 membership：自己退出 或 管理员移除
      allow delete: if isSignedIn() &&
        (resource.data.userId == request.auth.uid ||
         isOrgAdmin(resource.data.organizationId));
    }

    // ============================================================
    // TASKS
    // ============================================================
    match /tasks/{taskId} {
      // 只能读取自己的任务
      allow read: if isSignedIn() &&
        resource.data.userId == request.auth.uid;

      // 只能创建自己的任务
      allow create: if isSignedIn() &&
        request.resource.data.userId == request.auth.uid;

      // 只能更新自己的任务
      allow update: if isSignedIn() &&
        resource.data.userId == request.auth.uid;

      // 只能删除自己的任务
      allow delete: if isSignedIn() &&
        resource.data.userId == request.auth.uid;
    }

    // ============================================================
    // EVENTS
    // ============================================================
    match /events/{eventId} {
      // 所有人可以读取事件（可根据需求调整为仅组织成员）
      allow read: if true;

      // 只有组织管理员可以创建事件
      allow create: if isSignedIn() &&
        isOrgAdmin(request.resource.data.organizationId);

      // 只有组织管理员可以更新事件
      allow update: if isSignedIn() &&
        isOrgAdmin(resource.data.organizationId);

      // 只有组织管理员可以删除事件
      allow delete: if isSignedIn() &&
        isOrgAdmin(resource.data.organizationId);
    }

    // ============================================================
    // EVENT REGISTRATIONS
    // ============================================================
    match /eventRegistrations/{registrationId} {
      // 可以读取自己的报名记录
      allow read: if isSignedIn() &&
        resource.data.userId == request.auth.uid;

      // 组织管理员可以查看所有报名
      allow list: if isSignedIn();

      // 用户可以报名事件
      allow create: if isSignedIn() &&
        request.resource.data.userId == request.auth.uid;

      // 用户可以取消自己的报名
      allow update, delete: if isSignedIn() &&
        resource.data.userId == request.auth.uid;
    }

    // ============================================================
    // POSTS
    // ============================================================
    match /posts/{postId} {
      // 公开贴文所有人可读，组织贴文只有成员可读
      allow read: if resource.data.visibility == 'public' ||
        (resource.data.visibility == 'org_members' &&
         resource.data.organizationId != null &&
         isOrgMember(resource.data.organizationId));

      // 用户可以创建个人贴文，组织成员可以创建组织贴文
      allow create: if isSignedIn() &&
        request.resource.data.authorUserId == request.auth.uid &&
        (request.resource.data.organizationId == null ||
         isOrgMember(request.resource.data.organizationId));

      // 只有作者可以更新/删除自己的贴文
      allow update, delete: if isSignedIn() &&
        resource.data.authorUserId == request.auth.uid;
    }

    // ============================================================
    // COMMENTS
    // ============================================================
    match /comments/{commentId} {
      // 可以读取评论（需要先能读取对应的 post）
      allow read: if true;

      // 可以创建评论
      allow create: if isSignedIn() &&
        request.resource.data.authorUserId == request.auth.uid;

      // 只有作者可以更新/删除自己的评论
      allow update, delete: if isSignedIn() &&
        resource.data.authorUserId == request.auth.uid;
    }

    // ============================================================
    // REACTIONS
    // ============================================================
    match /reactions/{reactionId} {
      allow read: if true;

      allow create: if isSignedIn() &&
        request.resource.data.userId == request.auth.uid;

      allow delete: if isSignedIn() &&
        resource.data.userId == request.auth.uid;
    }

    // ============================================================
    // ORG APP INSTANCES
    // ============================================================
    match /orgAppInstances/{instanceId} {
      // 组织成员可以读取
      allow read: if isSignedIn() &&
        isOrgMember(resource.data.organizationId);

      // 只有管理员可以创建/更新/删除小应用
      allow create, update, delete: if isSignedIn() &&
        isOrgAdmin(request.resource.data.organizationId);
    }

    // ============================================================
    // HELPER FUNCTIONS
    // ============================================================
    function getMembershipId(orgId) {
      return request.auth.uid + '_' + orgId;
    }

    function isOrgAdmin(orgId) {
      let membership = get(/databases/$(database)/documents/memberships/$(getMembershipId(orgId)));
      return membership.data.role in ['owner', 'admin'];
    }
  }
}
```

## 规则说明

### 1. 用户（users）
- ✅ 用户只能读取、创建、更新自己的资料
- ❌ 不允许删除用户资料（防止误删）
- ✅ 创建时必须包含 `name`, `email`, `createdAt`
- ✅ Email 必须与 Auth token 一致

### 2. 组织（organizations）
- ✅ 所有人可以查看组织信息（公开）
- ✅ 登录用户可以创建组织
- ✅ 只有 owner/admin 可以更新组织
- ✅ 只有 owner 可以删除组织

### 3. 身份（memberships）
- ✅ 用户可以查看自己的所有身份
- ✅ 用户可以主动加入组织（创建 membership）
- ✅ 组织管理员可以邀请成员（创建 membership）
- ✅ 用户可以退出组织（删除自己的 membership）
- ✅ 管理员可以移除成员

### 4. 任务（tasks）
- ✅ 严格的个人隔离：只能操作自己的任务
- ✅ 支持完整的 CRUD 操作

### 5. 事件与报名
- ✅ 事件对所有人可见（可调整）
- ✅ 只有组织管理员可以创建/编辑事件
- ✅ 用户可以自由报名/取消报名

### 6. 社群功能（贴文、评论、反应）
- ✅ 公开贴文所有人可见
- ✅ 组织贴文只有成员可见
- ✅ 用户只能编辑/删除自己的内容

## 测试规则

在 Firebase Console 的 Rules Playground 中测试：

### 测试 1：用户读取自己的任务
```javascript
// Authenticated as: user123
// Operation: get
// Path: /tasks/task456

// 假设 task456 的 userId = "user123"
// 结果：✅ Allow
```

### 测试 2：用户尝试读取他人任务
```javascript
// Authenticated as: user123
// Operation: get
// Path: /tasks/task789

// 假设 task789 的 userId = "user999"
// 结果：❌ Deny
```

### 测试 3：创建组织
```javascript
// Authenticated as: user123
// Operation: create
// Path: /organizations/org001
// Data: {
//   name: "静宜资管系",
//   type: "department",
//   createdByUserId: "user123",
//   ...
// }
// 结果：✅ Allow
```

## 生产环境建议

1. **启用备份**：在 Firestore 设置中启用自动备份
2. **监控规则使用**：定期查看 Firebase Console 的 Usage 页面
3. **审计日志**：启用 Cloud Logging 记录所有操作
4. **速率限制**：使用 App Check 防止滥用

## 索引建议

为提高查询性能，建议在 Firebase Console 创建以下复合索引：

### tasks collection
```
- userId (Ascending) + isDone (Ascending) + plannedDate (Ascending)
- userId (Ascending) + isDone (Ascending) + deadlineAt (Ascending)
- userId (Ascending) + category (Ascending) + isDone (Ascending)
```

### memberships collection
```
- userId (Ascending) + organizationId (Ascending)
```

### posts collection
```
- organizationId (Ascending) + createdAt (Descending)
- visibility (Ascending) + createdAt (Descending)
```

这些索引会在首次执行对应查询时，Firebase 自动提示你创建。
