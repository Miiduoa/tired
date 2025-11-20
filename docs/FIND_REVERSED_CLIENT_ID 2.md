# 如何找到 REVERSED_CLIENT_ID

## 位置

`REVERSED_CLIENT_ID` 位於 `GoogleService-Info.plist` 文件中。

## 方法 1：在 Xcode 中查看

1. **打開 Xcode 專案**
   - 打開 `tired/tired.xcodeproj`

2. **找到 GoogleService-Info.plist**
   - 在專案導航器中，找到 `GoogleService-Info.plist` 文件
   - 點擊打開

3. **查看內容**
   - 在 Xcode 中，plist 文件可能以兩種方式顯示：
     - **Property List 視圖**（表格形式）：查找 `REVERSED_CLIENT_ID` 鍵
     - **Source Code 視圖**（XML 形式）：查找 `<key>REVERSED_CLIENT_ID</key>`

4. **切換視圖方式**
   - 右鍵點擊 plist 文件
   - 選擇 `Open As` → `Source Code` 或 `Property List`

## 方法 2：直接查看文件內容

在你的專案中，`REVERSED_CLIENT_ID` 的值是：

```
com.googleusercontent.apps.566724358335-04e0heqf7hato4hv2kb62pkfk9fgd366
```

這個值位於：
- 文件：`tired/tired/tired/GoogleService-Info.plist`
- 鍵：`REVERSED_CLIENT_ID`
- 值：`com.googleusercontent.apps.566724358335-04e0heqf7hato4hv2kb62pkfk9fgd366`

## 方法 3：使用終端查看

在終端中運行以下命令（從專案根目錄）：

```bash
cd /Users/handemo/Desktop/tired
grep -A 1 "REVERSED_CLIENT_ID" tired/tired/tired/GoogleService-Info.plist
```

或者直接查看完整文件 `tired/tired/tired/GoogleService-Info.plist`。

## 在 Xcode 中配置 URL Scheme

找到 `REVERSED_CLIENT_ID` 後，使用這個值配置 URL Scheme：

1. **選擇專案**
   - 在專案導航器中點擊專案（藍色圖標）
   - 選擇你的 App target

2. **打開 Info 標籤**
   - 點擊頂部的 `Info` 標籤

3. **添加 URL Type**
   - 找到 `URL Types` 部分
   - 點擊 `+` 按鈕添加新的 URL Type

4. **輸入 URL Scheme**
   - 在 `URL Schemes` 欄位中，點擊 `+` 按鈕
   - 輸入：`com.googleusercontent.apps.566724358335-04e0heqf7hato4hv2kb62pkfk9fgd366`
   - 確認 `Role` 設置為 `Editor`（或留空）

## 驗證

配置完成後，`Info.plist` 文件應該包含：

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

## 如果還是找不到

如果你在 Xcode 中打開 `GoogleService-Info.plist` 但看不到 `REVERSED_CLIENT_ID`：

1. **確認文件正確**
   - 確認你打開的是 `TiredApp/GoogleService-Info.plist`
   - 不是其他位置的同名文件

2. **檢查文件是否完整**
   - 文件應該包含多個鍵值對
   - 如果文件看起來不完整，可能需要重新下載

3. **從 Firebase Console 重新下載**
   - 前往 [Firebase Console](https://console.firebase.google.com/)
   - 選擇專案：`tired-634e9`
   - 左側選單 → `Project Settings`（⚙️ 圖標）
   - 滾動到 `Your apps` 部分
   - 找到 iOS 應用程式
   - 點擊 `GoogleService-Info.plist` 下載按鈕
   - 替換現有文件


