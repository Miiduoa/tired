const functions = require("firebase-functions");
const algoliasearch = require("algoliasearch");

// --- Algolia 設定 ---
// 重要：請在部署前，在 Firebase Functions 的環境變數中設定好 Algolia 的設定
// firebase functions:config:set algolia.app_id="YOUR_APP_ID"
// firebase functions:config:set algolia.api_key="YOUR_ADMIN_API_KEY"
const APP_ID = functions.config().algolia.app_id;
const ADMIN_KEY = functions.config().algolia.api_key;

const client = algoliasearch(APP_ID, ADMIN_KEY);
const index = client.initIndex("organizations"); // 假設你的 Algolia index 名稱為 'organizations'


/**
 * 當有新組織在 Firestore 中建立時，將其同步到 Algolia
 */
exports.onOrganizationCreated = functions.firestore
  .document("organizations/{organizationId}")
  .onCreate((snap, context) => {
    // 獲取新建立的組織資料
    const organization = snap.data();
    organization.objectID = context.params.organizationId; // Algolia 需要一個 objectID

    // 寫入到 Algolia
    return index.saveObject(organization).then(() => {
      console.log(`Algolia: Indexed organization ${organization.objectID}`);
    }).catch(error => {
      console.error(`Algolia: Error indexing organization ${organization.objectID}`, error);
    });
  });

/**
 * 當有組織在 Firestore 中更新時，將其變更同步到 Algolia
 */
exports.onOrganizationUpdated = functions.firestore
  .document("organizations/{organizationId}")
  .onUpdate((change, context) => {
    const newOrganization = change.after.data();
    newOrganization.objectID = context.params.organizationId;

    return index.saveObject(newOrganization).then(() => {
      console.log(`Algolia: Updated index for organization ${newOrganization.objectID}`);
    }).catch(error => {
      console.error(`Algolia: Error updating index for ${newOrganization.objectID}`, error);
    });
  });

/**
 * 當有組織在 Firestore 中被刪除時，將其從 Algolia 中移除
 */
exports.onOrganizationDeleted = functions.firestore
  .document("organizations/{organizationId}")
  .onDelete((snap, context) => {
    const objectID = context.params.organizationId;

    return index.deleteObject(objectID).then(() => {
      console.log(`Algolia: Deleted organization ${objectID} from index.`);
    }).catch(error => {
      console.error(`Algolia: Error deleting organization ${objectID} from index.`, error);
    });
  });
