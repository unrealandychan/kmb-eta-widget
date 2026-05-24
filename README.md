# 🚌 KMB ETA Widget — macOS

九巴實時到站時間，**純 macOS 原生 SwiftUI + WidgetKit + MenuBarExtra**。

- **macOS 14 (Sonoma)** 以上
- **Xcode 15** 以上
- Apple Developer 帳號（免費帳號可 run simulator，真機需付費帳號）

---

## 📁 項目結構

```
KMBWidget/
├── setup.sh                        ← 一鍵安裝 + 生成 Xcode project
├── project.yml                     ← XcodeGen 配置（3 個 macOS targets）
│
├── KMBWidget/                      ← 主 App（設定 + 搜尋）
│   ├── Sources/
│   │   ├── App.swift               TabView 入口
│   │   ├── Models/Models.swift     資料模型（共用）
│   │   ├── API/KMBAPIClient.swift  九巴 ETA API（共用）
│   │   ├── Views/
│   │   │   ├── ContentView.swift   我的巴士站
│   │   │   ├── NearbyStopsView.swift  附近巴士站（CoreLocation）
│   │   │   └── ReminderView.swift  提醒管理
│   │   ├── Location/
│   │   │   └── LocationManager.swift
│   │   └── Notifications/
│   │       ├── NotificationManager.swift
│   │       └── BackgroundTaskManager.swift  (Timer-based polling)
│   ├── Info.plist
│   └── KMBWidget.entitlements
│
├── KMBWidgetExtension/             ← WidgetKit 桌面 Widget
│   └── Sources/KMBWidget.swift     Small / Medium / Large
│
└── KMBMenuBar/                     ← Menu Bar App（倒數到站）
    ├── Sources/
    │   ├── MenuBarApp.swift        MenuBarExtra 入口
    │   ├── MenuBarViewModel.swift  Timer 每 30s poll
    │   └── MenuBarContentView.swift  popover UI
    └── Info.plist
```

---

## 🚀 安裝步驟

### 第一步：Clone repo

```bash
git clone https://github.com/unrealandychan/kmb-eta-widget.git
cd kmb-eta-widget
```

### 第二步：一鍵 setup

```bash
chmod +x setup.sh && ./setup.sh
```

Script 會自動：
- 檢查 macOS 版本（需要 14+）
- 檢查 Xcode
- 安裝 XcodeGen（透過 Homebrew）
- 生成 `KMBWidget.xcodeproj`

### 第三步：開啟 Xcode

```bash
open KMBWidget.xcodeproj
```

### 第四步：設定 Signing

Xcode → 左側 Project → **Signing & Capabilities**  
每個 target 都要填：
- `KMBWidget`
- `KMBMenuBar`
- `KMBWidgetExtension`

填入你的 **Apple Developer Team ID**（免費帳號都得，但 App Group 功能需付費帳號）

### 第五步：選 Scheme + Run

| Scheme | 功能 |
|--------|------|
| `KMBWidget` | 主 App：搜尋巴士站、附近站（定位）、設定提醒 |
| `KMBMenuBar` | Menu Bar 倒數到站，每 30 秒自動刷新 |

選好 Scheme 後 `⌘R` 執行。

> 💡 建議先跑 **KMBMenuBar**，最快見到效果！

---

## ✨ 功能一覽

### Menu Bar App（KMBMenuBar）
```
🚌 234 3m  98C 8m          ← 常駐 Menu Bar
```
- 實時顯示最近 2 條路線到站倒數
- 點開 popover → 全部路線 + 3 班次 ETA
- 🔴 ≤2 分鐘 / 🟠 ≤5 分鐘 / 🟢 正常
- 每 **30 秒**自動刷新
- 搜尋新增巴士站（中英文）
- 右鍵移除站
- 唔會出現喺 Dock（`LSUIElement`）

### 主 App（KMBWidget） — 3 個 Tab

**⭐ 我的巴士站**
- 手動搜尋加入常用巴士站
- 查看各路線實時 ETA

**📍 附近巴士站**
- CoreLocation 定位搜尋
- 200m / 500m / 1km 範圍篩選
- 按距離排序

**🔔 提醒**
- 設定某路線「到站前 N 分鐘」通知
- 用 `UNUserNotifications` 發 macOS 通知
- Background Timer 每 30 秒檢查 ETA

### 桌面 Widget（KMBWidgetExtension）
- Small / Medium / Large 三種尺寸
- 每 5 分鐘自動刷新
- macOS 14 桌面 widget 支援

---

## 🔑 API

使用 [KMB ETA API](https://data.etabus.gov.hk/v1/transport/kmb/) — 完全免費，無需 API key。

---

## 📋 系統需求

| 項目 | 需求 |
|------|------|
| macOS | 14.0 (Sonoma) 以上 |
| Xcode | 15.0 以上 |
| Swift | 5.10 |
| Apple Developer | 免費帳號可測試（部分功能需付費帳號） |
