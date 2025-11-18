#!/bin/bash

# 設定 Xcode 專案的腳本
# 這個腳本會將 TiredApp/ 目錄的程式碼整合到 Xcode 專案中

PROJECT_NAME="TiredApp"
PROJECT_DIR="$(pwd)"
XCODE_PROJECT_DIR="$PROJECT_DIR/$PROJECT_NAME.xcodeproj"
TIRED_APP_DIR="$PROJECT_DIR/TiredApp"

echo "🔧 開始設定 Xcode 專案..."

# 檢查 Xcode 專案是否存在
if [ ! -d "$XCODE_PROJECT_DIR" ]; then
    echo "❌ 錯誤: 找不到 Xcode 專案: $XCODE_PROJECT_DIR"
    echo ""
    echo "請先建立 Xcode 專案："
    echo "1. 打開 Xcode"
    echo "2. File → New → Project → iOS → App"
    echo "3. Product Name: $PROJECT_NAME"
    echo "4. Interface: SwiftUI"
    echo "5. 保存到: $PROJECT_DIR"
    echo ""
    echo "建立完成後再執行此腳本"
    exit 1
fi

# 檢查 TiredApp 目錄是否存在
if [ ! -d "$TIRED_APP_DIR" ]; then
    echo "❌ 錯誤: 找不到 TiredApp 目錄: $TIRED_APP_DIR"
    exit 1
fi

echo "✅ 找到 Xcode 專案: $XCODE_PROJECT_DIR"
echo "✅ 找到 TiredApp 目錄: $TIRED_APP_DIR"
echo ""
echo "📋 接下來請在 Xcode 中手動執行以下步驟："
echo ""
echo "1. 在 Xcode 中打開專案: $XCODE_PROJECT_DIR"
echo ""
echo "2. 刪除自動生成的檔案："
echo "   - 在專案導航器中，刪除自動生成的 $PROJECT_NAME/ 目錄下的所有檔案"
echo "   - 保留 $PROJECT_NAME.xcodeproj 本身"
echo ""
echo "3. 添加現有檔案："
echo "   - 在專案導航器中，右鍵點擊 $PROJECT_NAME"
echo "   - 選擇 'Add Files to \"$PROJECT_NAME\"...'"
echo "   - 選擇整個 TiredApp/ 目錄"
echo "   - ✅ 勾選 'Create groups'"
echo "   - ✅ 勾選 'Copy items if needed'"
echo "   - ✅ 確保 Target Membership 中勾選了 $PROJECT_NAME"
echo "   - 點擊 'Add'"
echo ""
echo "4. 添加 Firebase SDK："
echo "   - File → Add Package Dependencies"
echo "   - 輸入: https://github.com/firebase/firebase-ios-sdk.git"
echo "   - 版本: Up to Next Major Version 10.19.0"
echo "   - 選擇產品:"
echo "     ✅ FirebaseAuth"
echo "     ✅ FirebaseFirestore"
echo "     ✅ FirebaseStorage"
echo "   - 點擊 'Add Package'"
echo ""
echo "5. 配置專案設定："
echo "   - 選擇專案 → $PROJECT_NAME target → General"
echo "   - Deployment Target: iOS 17.0"
echo "   - Bundle Identifier: tw.pu.tiredteam.tired"
echo ""
echo "6. 確認 GoogleService-Info.plist 已添加："
echo "   - 在專案導航器中確認 TiredApp/GoogleService-Info.plist 存在"
echo "   - 右鍵點擊 → Show File Inspector"
echo "   - 確認 Target Membership 中勾選了 $PROJECT_NAME"
echo ""
echo "7. 選擇模擬器並運行："
echo "   - 在 Xcode 頂部選擇 iOS 模擬器（例如 iPhone 15 Pro）"
echo "   - 按 ⌘R 或點擊運行按鈕"
echo ""
echo "✨ 完成！"

