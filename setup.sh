#!/bin/bash
set -e

echo "🚌 KMBWidget — macOS Setup"
echo "================================"

# ── 1. Check macOS version ─────────────────────────────
SW=$(sw_vers -productVersion 2>/dev/null || echo "0")
MAJOR=$(echo "$SW" | cut -d. -f1)
if [ "$MAJOR" -lt 14 ]; then
  echo "❌ 需要 macOS 14 (Sonoma) 或以上，你的版本：$SW"
  exit 1
fi
echo "✅ macOS $SW"

# ── 2. Check Xcode ────────────────────────────────────
if ! xcode-select -p &>/dev/null; then
  echo "❌ 未安裝 Xcode Command Line Tools"
  echo "   請先執行：xcode-select --install"
  exit 1
fi
XCODE_VER=$(xcodebuild -version 2>/dev/null | head -1)
echo "✅ $XCODE_VER"

# ── 3. Install XcodeGen ──────────────────────────────
if ! command -v xcodegen &>/dev/null; then
  echo "📦 安裝 XcodeGen..."
  if command -v brew &>/dev/null; then
    brew install xcodegen
  else
    echo "❌ 未安裝 Homebrew，請先安裝：https://brew.sh"
    exit 1
  fi
fi
echo "✅ XcodeGen $(xcodegen --version)"

# ── 4. Generate Xcode project ────────────────────────
echo ""
echo "⚙️  生成 Xcode project..."
xcodegen generate

echo ""
echo "✅ 完成！KMBWidget.xcodeproj 已生成"
echo ""
echo "下一步："
echo "  1. open KMBWidget.xcodeproj"
echo "  2. Xcode → Signing & Capabilities → 填入你的 Apple Developer Team"
echo "  3. 選 Scheme:"
echo "     - KMBWidget   → 主 App（搜尋站 + 附近站 + 提醒管理）"
echo "     - KMBMenuBar  → Menu Bar App（倒數到站）"
echo "  4. ⌘R 執行"
echo ""
echo "建議先跑 KMBMenuBar，最即刻見到效果！"
