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
