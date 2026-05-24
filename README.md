# 🚌 KMBWidget — 九巴實時到站 Native Widget

用 **SwiftUI + WidgetKit** 開發的 iOS/iPadOS 原生 Widget，支援 Small / Medium / Large 三種尺寸。

## 📁 項目結構

```
KMBWidget/
├── setup.sh                          ← 一鍵生成 Xcode project
├── project.yml                       ← XcodeGen 配置
│
├── KMBWidget/                        ← 主 App (設定介面)
│   ├── Info.plist
│   ├── KMBWidget.entitlements
│   └── Sources/
│       ├── App.swift
│       ├── Models/
│       │   └── Models.swift          ← 資料模型 (Stop, ETA, Config)
│       ├── API/
│       │   └── KMBAPIClient.swift    ← 九巴 API 呼叫 + UserDefaults
│       └── Views/
│           └── ContentView.swift    ← 搜尋站、設定、ETA 預覽
│
└── KMBWidgetExtension/               ← WidgetKit Extension
    ├── Info.plist
    ├── KMBWidgetExtension.entitlements
    └── Sources/
        └── KMBWidget.swift           ← TimelineProvider + 3 Widget Views
```

## 🚀 安裝步驟

```bash
# 1. 解壓後進入目錄
cd KMBWidget

# 2. 執行 setup script（會自動安裝 XcodeGen 並生成 .xcodeproj）
chmod +x setup.sh && ./setup.sh

# 3. 開啟 Xcode
open KMBWidget.xcodeproj
```

## ⚙️ Xcode 設定

1. **Signing & Capabilities** → 填入你的 Apple Developer Team ID
2. 兩個 Target 都確認有 **App Groups**: `group.com.eddie.kmbwidget`
3. 選 iPhone/iPad Simulator → `⌘R` 運行

## 📱 使用方法

1. 打開 App → 點「+」→ 搜尋你樓下巴士站（中英文均可）
2. 長按主畫面 → 加 Widget → 搜尋「九巴」
3. 選 Small / Medium / Large，長按 widget 可指定不同巴士站

## 🎨 Widget 外觀

| 尺寸 | 顯示內容 |
|------|---------|
| Small  | 最近 3 條路線 + 下一班時間 |
| Medium | 4 條路線 + 各 3 班時間 |
| Large  | 8 條路線 + 各 3 班時間 + 顏色標示 |

**顏色系統：**
- 🔴 紅 = ≤2 分鐘（快啲落樓！）
- 🟠 橙 = ≤5 分鐘
- 🟢 綠 = 5 分鐘以上

## 🔗 API 來源

九巴 & 龍運巴士 ETA API：`https://data.etabus.gov.hk/v1/transport/kmb/`

由運輸署及九巴提供，每 5 分鐘更新一次。
