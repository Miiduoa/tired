# REST Adapter 串接指南

以下說明企業或學校如何透過「REST API」整合 tired App 的公告 / 收件匣等模組。

## 1. 建立租戶設定

1. 在管理後台或 Firestore `tenant_configs` 建立一筆設定文件。
2. `adapter` 欄位設為 `rest`。
3. 提供對應欄位（可參考 `tenant-config.sample.json`）：

```jsonc
{
  "id": "sample-company",
  "adapter": "rest",
  "rest": {
    "baseURL": "https://api.example.com/v1",
    "authMethod": "bearerToken",
    "headers": {
      "X-Client-ID": "your-client-id"
    },
    "credentials": {
      "token": "YOUR_ACCESS_TOKEN"
    }
  },
  "options": {
    "broadcasts.path": "/broadcasts",
    "inbox.path": "/inbox",
    "inbox.ackPath": "/inbox/{id}/ack"
  }
}
```

## 2. API 規格需求

### 2.1 公告（Broadcasts）
- `GET /broadcasts`
- 回傳 `BroadcastListItem` 陣列：
```json
[
  {
    "id": "123",
    "title": "公告標題",
    "body": "公告內容",
    "deadline": "2025-01-01T00:00:00Z",
    "requiresAck": true,
    "acked": false,
    "eventId": "ABC123"
  }
]
```

### 2.2 收件匣（Inbox）
- `GET /inbox` 取得 `InboxItem` 陣列。
- `POST /inbox/{id}/ack` 標記完成（回傳 200 即視為成功）。

`InboxItem` JSON 範例：
```json
{
  "id": "task-001",
  "kind": "ack",
  "title": "簽署 NDA",
  "subtitle": "請於今日完成",
  "deadline": "2025-02-01T12:00:00Z",
  "isUrgent": true,
  "priority": "urgent",
  "eventId": "nda-req-2025"
}
```

> `kind` 與 `priority` 必須使用 tired App 定義的枚舉值：  
> `kind`: ack / rollcall / clockin / assignment / esgTask  
> `priority`: low / normal / high / urgent

## 3. 權杖與安全性

- `rest.authMethod` 支援 `none | apiKey | bearerToken | basic`。  
- 若使用 `apiKey`，需在 `credentials` 提供 `apiKey` 與 `apiKeyHeader`。  
- 若使用 `bearerToken`，在 `credentials.token` 填入 access token。

## 4. 佈署流程

1. 建立租戶設定並填入 REST API 相關欄位。
2. 在後台啟用公告 / 收件匣模組。
3. 於測試模式下執行 APP，確認可讀取 / Ack 成功。
4. 監控 API log 與 APP log，若有錯誤可透過管理後台檢視。

## 5. 可選功能

- `options.broadcasts.path`, `options.inbox.path` 等可以自訂不同 API 路徑。
- 若 API 需要查詢參數，可在 `rest.queries` 中定義，支援 `{{TENANT_ID}}`, `{{MEMBERSHIP_ID}}`, `{{ROLE}}` 佔位符。
- 若要擴充其他模組（例如出勤、ESG），只需在設定中新增對應 path，並於後端提供對應 API。

---

如需進一步自訂功能（例如分頁、批次操作、Webhook），可依照 `TenantIntegrationProtocol` 撰寫自定義 Adapter。歡迎持續回饋所需欄位，我們會擴充官方模板。***
