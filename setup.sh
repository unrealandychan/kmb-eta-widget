#!/bin/bash
# ╔══════════════════════════════════════════════════════╗
# ║  KMBWidget — Setup Script                            ║
# ║  執行一次即生成 Xcode project，然後直接開啟            ║
# ╚══════════════════════════════════════════════════════╝

set -e

echo "🚌 KMB Widget — Xcode Project Setup"
echo "======================================"

# 1. Check Homebrew
if ! command -v brew &>/dev/null; then
    echo "❌ 未安裝 Homebrew，請先到 https://brew.sh 安裝"
    exit 1
fi

# 2. Install XcodeGen
if ! command -v xcodegen &>/dev/null; then
    echo "📦 安裝 XcodeGen..."
    brew install xcodegen
else
    echo "✅ XcodeGen 已安裝"
fi

# 3. Generate Xcode project
echo ""
echo "⚙️  生成 Xcode project..."
xcodegen generate

echo ""
echo "✅ 完成！Xcode project 已生成。"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 接下來步驟："
echo ""
echo "  1. 開啟 Xcode："
echo "     open KMBWidget.xcodeproj"
echo ""
echo "  2. 簽名設定（如需真機測試）："
echo "     Xcode → Signing & Capabilities → 填入你的 Team"
echo ""
echo "  3. 確認 App Group 設定："
echo "     兩個 target 都要加 App Groups: group.com.eddie.kmbwidget"
echo ""
echo "  4. 選 Simulator (iPhone/iPad) → Build & Run (⌘R)"
echo ""
echo "  5. App 內搜尋並新增你樓下嘅巴士站"
echo ""
echo "  6. 長按主畫面 → 加 Widget → 選「九巴到站時間」"
echo "     Small / Medium / Large 三種尺寸任揀！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Offer to open Xcode directly
read -p "🚀 立即開啟 Xcode？(y/N) " yn
if [[ "$yn" =~ ^[Yy] ]]; then
    open KMBWidget.xcodeproj
fi
