// Seed Firestore with minimal demo data for tired app
// Usage:
//   GOOGLE_APPLICATION_CREDENTIALS=path/to/sa.json PROJECT_ID=your-project npm run seed

import { Firestore } from '@google-cloud/firestore'

const projectId = process.env.PROJECT_ID || process.env.GCLOUD_PROJECT
if (!projectId) {
  console.error('Missing PROJECT_ID env var')
  process.exit(1)
}

const db = new Firestore({ projectId })

async function ensureUser(uid, displayName, email) {
  const ref = db.collection('users').doc(uid)
  await ref.set({ displayName, email }, { merge: true })
  return ref
}

async function createConversation(title, participantIds) {
  const ref = db.collection('conversations').doc()
  await ref.set({ title, participantIds, updatedAt: new Date(), lastMessagePreview: '' })
  return ref.id
}

async function addMessage(conversationId, senderId, senderName, text) {
  const ref = db.collection('conversations').doc(conversationId).collection('messages').doc()
  await ref.set({ senderId, senderName, text, createdAt: new Date() })
}

async function addFriendRequest(toUid, fromUid, fromDisplayName, fromPhotoURL) {
  const ref = db.collection('users').doc(toUid).collection('friend_requests').doc()
  await ref.set({ fromUid, fromDisplayName, fromPhotoURL: fromPhotoURL || null, createdAt: new Date() })
}

async function main() {
  const uMe = 'u_demo_me'
  const uAlex = 'u_alex'
  const uMia = 'u_mia'
  await ensureUser(uMe, 'Demo Me', 'me@example.com')
  await ensureUser(uAlex, 'Alex', 'alex@example.com')
  await ensureUser(uMia, 'Mia', 'mia@example.com')

  const cid = await createConversation('產品小組', [uMe, uAlex, uMia])
  await addMessage(cid, uAlex, 'Alex', '歡迎加入！')
  await addMessage(cid, uMe, 'Demo Me', '大家好～')

  await addFriendRequest(uMe, uMia, 'Mia')

  console.log('Seed completed')
}

main().catch((e) => { console.error(e); process.exit(1) })

