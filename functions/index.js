const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * 監聽成員資格申請的更新，並在申請被批准時發送通知。
 */
exports.onMembershipRequestApproved = functions
  .region("asia-east2") // 建議選擇離你使用者近的區域
  .firestore.document("membershipRequests/{requestId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // 檢查狀態是否從 'pending' 變為 'approved'
    if (
      beforeData.status === "pending" &&
      afterData.status === "approved"
    ) {
      const userId = afterData.userId;
      const organizationId = afterData.organizationId;

      console.log(
        `Membership request approved for user ${userId} to organization ${organizationId}. Preparing to send notification.`
      );

      // 1. 獲取使用者的 FCM token
      let userDoc;
      try {
        userDoc = await admin.firestore().collection("users").doc(userId).get();
      } catch (error) {
        console.error(`Error fetching user document for userId: ${userId}`, error);
        return;
      }

      if (!userDoc.exists) {
        console.log(`User document for user ${userId} does not exist. Cannot send notification.`);
        return;
      }

      const fcmToken = userDoc.data()?.fcmToken;
      if (!fcmToken) {
        console.log(`FCM token for user ${userId} is missing. Cannot send notification.`);
        return;
      }
      
      // 2. 獲取組織的名稱
      let orgDoc;
      try {
        orgDoc = await admin.firestore().collection("organizations").doc(organizationId).get();
      } catch (error) {
        console.error(`Error fetching organization document for orgId: ${organizationId}`, error);
        // 即使組織名稱獲取失敗，仍然可以發送通用通知
      }
      
      const orgName = orgDoc?.exists ? orgDoc.data()?.name : "一個組織";

      // 3. 準備通知內容
      const payload = {
        notification: {
          title: "申請已批准！",
          body: `恭喜！您加入「${orgName}」的申請已被批准。`,
        },
        // 你也可以在這裡添加 'data' payload 來進行 App 內的跳轉
        // data: {
        //   "organizationId": organizationId
        // }
      };

      // 4. 發送通知
      try {
        console.log(`Sending notification to token: ${fcmToken}`);
        const response = await admin.messaging().sendToDevice(fcmToken, payload);
        console.log("Successfully sent message:", response);
      } catch (error) {
        console.error("Error sending message:", error);
      }
    }
  });

const isDateToday = (date) => {
    if (!date) return false;
    const today = new Date();
    const someDate = date.toDate(); // Convert Firestore Timestamp to JS Date
    return someDate.getDate() == today.getDate() &&
        someDate.getMonth() == today.getMonth() &&
        someDate.getFullYear() == today.getFullYear();
};

const calculateIsToday = (taskData) => {
    if (taskData.isDone) return false;

    if (taskData.plannedDate && isDateToday(taskData.plannedDate)) {
        return true;
    }
    if (!taskData.plannedDate && taskData.deadlineAt && isDateToday(taskData.deadlineAt)) {
        return true;
    }
    return false;
};

exports.onTaskWriteSetTodayFlag = functions
    .region("asia-east2")
    .firestore.document("tasks/{taskId}")
    .onWrite(async (change, context) => {
        const taskData = change.after.exists ? change.after.data() : null;
        const oldTaskData = change.before.exists ? change.before.data() : null;

        if (!taskData) {
            // Task was deleted, no action needed
            return null;
        }

        const newIsToday = calculateIsToday(taskData);
        // "isToday" in taskData is a check to see if the field exists at all
        const oldIsToday = oldTaskData ? ("isToday" in oldTaskData ? oldTaskData.isToday : calculateIsToday(oldTaskData)) : false;

        if (newIsToday !== oldIsToday || !("isToday" in taskData)) {
            console.log(`Updating isToday for task ${context.params.taskId} from ${oldIsToday} to ${newIsToday}`);
            return change.after.ref.update({ isToday: newIsToday });
        }
        
        return null;
    });

exports.onTaskChangeSendNotification = functions
    .region("asia-east2")
    .firestore.document("tasks/{taskId}")
    .onWrite(async (change, context) => {
        const taskData = change.after.exists ? change.after.data() : null;
        const oldTaskData = change.before.exists ? change.before.data() : null;

        if (!taskData && !oldTaskData) {
            // Should not happen
            return null;
        }

        const task = taskData || oldTaskData;
        if (!task.sourceOrgId) {
            // Not an organization task, do nothing
            return null;
        }

        const orgId = task.sourceOrgId;
        const taskId = context.params.taskId;
        let orgName = "一個組織";
        try {
            const orgDoc = await admin.firestore().collection("organizations").doc(orgId).get();
            if (orgDoc.exists) {
                orgName = orgDoc.data().name;
            }
        } catch (error) {
            console.error(`Error fetching organization document for orgId: ${orgId}`, error);
        }

        // --- Helper to send notification ---
        const sendNotification = async (userIds, title, body) => {
            if (!userIds || userIds.length === 0) {
                return;
            }
            
            const tokens = [];
            for (const userId of userIds) {
                try {
                    const userDoc = await admin.firestore().collection("users").doc(userId).get();
                    if (userDoc.exists && userDoc.data().fcmToken) {
                        tokens.push(userDoc.data().fcmToken);
                    }
                } catch (error) {
                    console.error(`Error fetching user document for userId: ${userId}`, error);
                }
            }

            if (tokens.length > 0) {
                const payload = {
                    notification: { title, body },
                    data: { taskId, organizationId: orgId },
                };
                try {
                    await admin.messaging().sendToDevice(tokens, payload);
                    console.log(`Sent notification to ${tokens.length} users.`);
                } catch (error) {
                    console.error("Error sending message:", error);
                }
            }
        };
        // --- End Helper ---

        if (!oldTaskData && taskData) {
            // --- Task Created ---
            const title = `新任務: ${orgName}`;
            const body = `"${taskData.title}"`;
            await sendNotification(taskData.assigneeUserIds, title, body);
            return;
        }

        if (oldTaskData && taskData) {
            // --- Task Updated ---
            // 1. Check for assignee change
            const oldAssignees = new Set(oldTaskData.assigneeUserIds || []);
            const newAssignees = new Set(taskData.assigneeUserIds || []);
            const newlyAdded = [...newAssignees].filter(id => !oldAssignees.has(id));

            if (newlyAdded.length > 0) {
                const title = `新任務指派: ${orgName}`;
                const body = `您已被指派新任務: "${taskData.title}"`;
                await sendNotification(newlyAdded, title, body);
            }
            
            // 2. Check for other significant changes to notify existing assignees
            const notifiedUsers = new Set(newlyAdded);
            const existingAssignees = [...newAssignees].filter(id => !notifiedUsers.has(id));

            if (oldTaskData.title !== taskData.title) {
                const title = `任務更新: ${orgName}`;
                const body = `任務 "${oldTaskData.title}" 已更名為 "${taskData.title}"`;
                await sendNotification(existingAssignees, title, body);
            } else if (String(oldTaskData.deadlineAt) !== String(taskData.deadlineAt)) {
                const title = `任務更新: ${orgName}`;
                const deadline = taskData.deadlineAt ? taskData.deadlineAt.toDate().toLocaleDateString() : "沒有截止日期";
                const body = `任務 "${taskData.title}" 的截止日期已變更為 ${deadline}`;
                await sendNotification(existingAssignees, title, body);
            }
            return;
        }
        
        if (oldTaskData && !taskData) {
            // --- Task Deleted ---
            // Optional: notify about deletion. This can be noisy.
            // For now, we will not notify on deletion.
            return null;
        }

        return null;
    });
