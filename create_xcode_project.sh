#!/bin/bash

# 建立 iOS App 專案的腳本
# 這個腳本會建立一個基本的 Xcode 專案結構

PROJECT_NAME="TiredApp"
BUNDLE_ID="tw.pu.tiredteam.tired"
PROJECT_DIR="$(pwd)"
XCODE_PROJECT_DIR="$PROJECT_DIR/$PROJECT_NAME.xcodeproj"

echo "🚀 開始建立 iOS App 專案..."

# 檢查是否已經存在專案
if [ -d "$XCODE_PROJECT_DIR" ]; then
    echo "⚠️  專案已存在: $XCODE_PROJECT_DIR"
    echo "   請先刪除現有專案或使用不同的名稱"
    exit 1
fi

echo "📝 請按照以下步驟在 Xcode 中建立專案："
echo ""
echo "1. 打開 Xcode"
echo "2. 選擇 File → New → Project"
echo "3. 選擇 iOS → App"
echo "4. 填寫以下資訊："
echo "   - Product Name: $PROJECT_NAME"
echo "   - Team: 選擇你的開發團隊"
echo "   - Organization Identifier: tw.pu.tiredteam"
echo "   - Bundle Identifier: $BUNDLE_ID"
echo "   - Interface: SwiftUI"
echo "   - Language: Swift"
echo "   - ⚠️  取消勾選 'Use Core Data' 和 'Include Tests'"
echo "5. 選擇保存位置: $PROJECT_DIR"
echo "6. 點擊 Create"
echo ""
echo "建立完成後，請執行以下命令來整合程式碼："
echo ""
echo "  ./setup_xcode_project.sh"
echo ""

