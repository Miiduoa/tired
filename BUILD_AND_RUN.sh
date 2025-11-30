#!/bin/bash

# 專案構建和運行腳本
# 用於清理並重新構建 tired 專案

echo "🚀 開始清理和構建專案..."

# 進入專案目錄
cd "$(dirname "$0")/tired" || exit 1

# 清理 DerivedData
echo "🧹 清理 DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/tired-*

# 清理模塊緩存
echo "🧹 清理模塊緩存..."
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex

# 清理專案構建文件
echo "🧹 清理專案構建文件..."
xcodebuild -project tired.xcodeproj -scheme tired -configuration Debug clean

# 構建專案
echo "🔨 開始構建專案..."
xcodebuild -project tired.xcodeproj -scheme tired -configuration Debug build

# 檢查構建結果
if [ $? -eq 0 ]; then
    echo "✅ 構建成功！"
    echo ""
    echo "下一步："
    echo "1. 在 Xcode 中打開專案"
    echo "2. 選擇模擬器或真機"
    echo "3. 按 Cmd + R 運行"
else
    echo "❌ 構建失敗，請檢查錯誤訊息"
    exit 1
fi






