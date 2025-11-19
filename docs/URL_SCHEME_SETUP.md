# URL Scheme 配置指南

## 問題
錯誤訊息：`Your app is missing support for the following URL schemes: com.googleusercontent.apps.566724358335-04e0heqf7hato4hv2kb62pkfk9fgd366`

## 解決方法

雖然 `Info.plist` 文件中已經有 URL Scheme 配置，但可能需要在 Xcode 專案設置中手動添加。

### 方法 1：在 Xcode 專案設置中配置（推薦）

1. **打開 Xcode 專案**
   - 打開 `tired/tired.xcodeproj`

2. **選擇專案和 Target**
   - 在專案導航器中，點擊最上層的專案（藍色圖標）
   - 在左側選擇你的 App target（例如：`tired`）

3. **打開 Info 標籤**
   - 點擊頂部的 `Info` 標籤

4. **添加 URL Types**
   - 找到 `URL Types` 部分
   - 如果沒有，點擊 `+` 按鈕添加一個新的 URL Type
   - 展開新添加的 URL Type

5. **配置 URL Scheme**
   - 在 `URL Schemes` 欄位中，點擊 `+` 按鈕
   - 輸入以下值：
     ```
     com.googleusercontent.apps.566724358335-04e0heqf7hato4hv2kb62pkfk9fgd366
     ```
   - 確認 `Role` 設置為 `Editor`（或留空）

6. **保存並重新編譯**
   - 按 `⌘S` 保存
   - 清理編譯：`Product` → `Clean Build Folder`（或按 `⌘⇧K`）
   - 重新編譯：`⌘B`

### 方法 2：確認 Info.plist 已正確添加到專案

1. **檢查 Info.plist 文件**
   - 在專案導航器中找到 `Info.plist` 文件
   - 確認文件存在於專案中

2. **確認 Target Membership**
   - 右鍵點擊 `Info.plist`
   - 選擇 `Show File Inspector`
   - 在 `Target Membership` 中確認勾選了你的 App target

3. **確認 Info.plist 內容**
   - 打開 `Info.plist` 文件
   - 確認包含以下內容：
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleTypeRole</key>
           <string>Editor</string>
           <key>CFBundleURLSchemes</key>
           <array>
               <string>com.googleusercontent.apps.566724358335-04e0heqf7hato4hv2kb62pkfk9fgd366</string>
           </array>
       </dict>
   </array>
   ```

### 方法 3：使用 Xcode 的 Build Settings

如果上述方法都不行，可以嘗試：

1. **選擇專案**
   - 在專案導航器中點擊專案（藍色圖標）

2. **選擇 Target**
   - 選擇你的 App target

3. **打開 Build Settings**
   - 點擊 `Build Settings` 標籤
   - 在搜尋框中輸入 `Info.plist File`
   - 確認 `Info.plist File` 路徑正確指向你的 `Info.plist` 文件

4. **確認 Info.plist 路徑**
   - 應該類似：`tired/Info.plist` 或 `$(SRCROOT)/tired/Info.plist`
   - 如果路徑不正確，雙擊並修改為正確路徑

## 驗證配置

配置完成後，可以通過以下方式驗證：

1. **檢查編譯輸出**
   - 重新編譯專案（⌘B）
   - 確認沒有 URL Scheme 相關的警告或錯誤

2. **檢查 Info.plist 輸出**
   - 在 Xcode 中，選擇 `Product` → `Show Build Folder in Finder`
   - 找到編譯後的 `.app` 文件
   - 右鍵點擊 → `Show Package Contents`
   - 打開 `Info.plist`
   - 確認 `CFBundleURLTypes` 存在且包含正確的 URL Scheme

3. **運行應用程式**
   - 運行應用程式（⌘R）
   - 嘗試使用 Google 登入功能
   - 確認可以正常處理 URL callback

## 常見問題

### Q: 為什麼需要 URL Scheme？
A: Google Sign-In 需要 URL Scheme 來處理 OAuth 回調。當用戶在瀏覽器中完成 Google 登入後，系統會使用這個 URL Scheme 將控制權返回給你的應用程式。

### Q: URL Scheme 從哪裡來？
A: URL Scheme 是從 `GoogleService-Info.plist` 文件中的 `REVERSED_CLIENT_ID` 值提取的。這個值對應於你的 Firebase 專案的 Google OAuth Client ID。

### Q: 如果修改了 GoogleService-Info.plist 怎麼辦？
A: 如果更新了 `GoogleService-Info.plist`，需要同步更新 URL Scheme。新的 URL Scheme 應該是 `REVERSED_CLIENT_ID` 的值（格式：`com.googleusercontent.apps.XXXXX-XXXXX`）。

## 注意事項

- URL Scheme 必須與 `GoogleService-Info.plist` 中的 `REVERSED_CLIENT_ID` 完全一致
- 配置完成後，需要清理並重新編譯專案
- 如果使用模擬器測試，確保模擬器已正確配置
- 如果使用實體設備測試，確保設備已正確配置開發者證書



