# 個人頁（Profile）規格摘要（P0 / P1 / P2）

本文件對應 PRD §16，供工程與設計對齊落地。

## P0（基本）

- 欄位：頭像、封面、顯示名稱、別名、Bio(≤140)、連結×2、興趣標籤×5
- 欄位級可見度：public / friends / group / org / private / custom
- 自訂清單（Audience List）：最多 10 個
- 群組視圖（Scoped Profile）：可為群組指定不同頭像/別名/可見度
- 預覽視角（Preview as）：陌生人 / 好友 / 同群 / 管理員
- DM/回覆權限：不允許 / 僅好友 / 同群 / 任何人（經同意）

## P1（進階）

- 臨時分享連結：選欄位＋對象＋有效期（24/48/72h），可撤銷
- 欄位歷程與回滾：最近 10 次編輯
- 存取紀錄（聚合）：近 30 天
- 徽章與驗證：校方/公司/幹部（可選顯示）

## 資料模型（Firestore 建議）

```
users/{uid}/profile_fields/{fieldId} {
  key, type, value,
  visibility: { mode, groups?, orgs?, listIds?, expiresAt? },
  scoped?: { [groupId]: { overrides... } },
  updatedAt, version
}

users/{uid}/audience_lists/{listId} { name, members:[uid], smartRule? }
profile_shares/{token} { ownerUid, fields:[key], scope:{uids?,groups?,listIds?}, expiresAt, revoked }
```

## API（節選）

- GET `/v1/profile/{uid}?viewer=:viewerUid&groupId=:gid` → 回傳對觀察者可見欄位
- PATCH `/v1/profile/fields` → 多欄位更新（含可見度設定）
- POST `/v1/profile/share`、DELETE `/v1/profile/share/{token}` → 臨時分享/撤銷

## 安全/隱私

- 雙層身分：RealID 租戶私域；對外顯示 Alias
- 欄位級加密：學號/工號等敏感欄位
- 預設最小曝光：敏感欄位預設 `private`
- 審計：可見度變更/臨時分享/揭示均記錄於 `audits`

