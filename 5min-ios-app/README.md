# 5min-ios-app

**如厕计时器** — iOS 原生客户端。

| 项 | 值 |
|------|------|
| Bundle ID | `chat.5min.app` |
| 显示名 | 如厕计时器（`CFBundleDisplayName`） |
| 版本 | `FiveMin/Info.plist` → `CFBundleShortVersionString` / `CFBundleVersion`（与工程 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` 保持一致；当前 `1.0.0` / `1`） |
| 技术 | SwiftUI · UserNotifications · AVAudioEngine · Core Haptics |
| 最低系统 | iOS 17 |
| 工程 | `FiveMin.xcodeproj` |
| 许可 | [LICENSE](./LICENSE)（Apache-2.0） |

## 功能

- 时长预设 3 / 5 / 10 分钟与分组场景
- 绝对时间戳倒计时；到期系统本地通知（前台横幅 / 后台日历触发）+ 约 5 秒提示音与触觉
- 今日累计、多语言（含阿语 RTL）
- 计时中常亮（`isIdleTimerDisabled`）
- 结束后轻触表盘可再次提醒

---

## 开发工具

| 工具 | 用途 |
|------|------|
| macOS + **Xcode 15+** | 编译、模拟器、真机、Archive |
| Apple ID / Developer Program | 真机与上架 |
| **Node.js 18+** | 导出共享文案 |
| **Python3 + Pillow** | 重出图标（可复用 Android `.tools-venv`） |

### 打开并运行

1. 用 Xcode 打开 `FiveMin.xcodeproj`。
2. **Signing & Capabilities** → 选择 **Team**（`DEVELOPMENT_TEAM` 默认为空）。
3. 顶部目标选 **模拟器**（如 iPhone 16）或已连接真机（勿长期停在 `Any iOS Device` 却无真机）。
4. `⌘R` 运行。

通知 / 声触 / 触觉建议真机验收。

共享文案：

```bash
cd ../5min-web && node scripts/export-shared.mjs
```

同步到 `FiveMin/Resources/shared/`。

图标重出（与 Android / 鸿蒙同品牌）：

```bash
# 需 Pillow；可复用 Android 工程虚拟环境
../5min-android-app/.tools-venv/bin/python scripts/generate_icons.py
```

写入：

- `FiveMin/Assets.xcassets/AppIcon.appiconset/AppIcon.png`（1024，无透明）
- `FiveMin/Assets.xcassets/Logo.imageset/logo.png`（页眉字标）
- `store/artwork/ic_launcher_*.png`、`logo.png`

---

## 签名

### 调试（推荐）

Xcode → **Signing & Capabilities** → 勾选 **Automatically manage signing** → 选择 Team。

### 正式发布（App Store）

1. 在 [App Store Connect](https://appstoreconnect.apple.com/) 创建应用（Bundle ID `chat.5min.app`）。
2. Xcode 同一 Team，确认 Release 使用 Distribution 证书（Automatic 即可）。
3. 复制导出配置（CLI 打包用）：

```bash
cp ExportOptions.plist.example ExportOptions.plist
# 将 YOUR_TEAM_ID 换成 Membership 中的 Team ID
```

4. 可选：复制 `signing.properties.example` → `signing.properties` 作本地备忘；证书 / Profile / API Key 放 `signing/material/`（已 gitignore）。

> `ExportOptions.plist`、`signing.properties`、`signing/material/`、`store/release/` **勿提交 Git**。

---

## 版本号

每次上架递增 **Build**（`CFBundleVersion`）；对外版本变了再改 **Version**（`CFBundleShortVersionString`）。

两处保持一致：

1. `FiveMin/Info.plist` → `CFBundleShortVersionString` / `CFBundleVersion`
2. Xcode Target → General → Version / Build
 （或 `project.pbxproj` 的 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`）

当前与 Android 首发对齐：`1.0.0`（Build `1`）。鸿蒙若已为 `1.0.1`，iOS 上架时可按需跟进。

---

## 打包正式版（IPA）

### 方式 A：脚本（与 Android / 鸿蒙 `scripts/release.sh` 对应）

```bash
chmod +x scripts/release.sh
cp ExportOptions.plist.example ExportOptions.plist # 首次
# 编辑 teamID
./scripts/release.sh
# → store/release/5min-ios-app-1.0.0.ipa
```

### 方式 B：Xcode

1. 目标选 **Any iOS Device (arm64)**
2. **Product → Archive**
3. Organizer → **Distribute App** → App Store Connect

上传也可用 Transporter。图标可用 `store/artwork/ic_launcher_1024.png`；截图放 `store/artwork/screenshots/`。

### 上架文案要点

- 名称：如厕计时器；类别：**工具（Utilities）**
- 描述：端侧倒计时、习惯提醒、本机完成、无账号无广告
- 隐私政策：`https://5min.chat/privacy.html`
- 通知用途：倒计时结束后本机提醒起身活动（见 `NSUserNotificationsUsageDescription`）

---

## 文案修改

| 类型 | 位置 |
|------|------|
| 界面多语言 / 场景 | `5min-web/js/i18n/locales.js` → `export-shared` |
| 显示名 / 通知权限 | `FiveMin/Info.plist` |
| 商店元数据 | App Store Connect |

书面语与合规约定见 `5min-web/README.md`「术语与文案约定」。**勿**把 `Resources/shared/**` 当长期源。

---

## Git 应提交 / 勿提交

**应提交**

- 源码、`FiveMin.xcodeproj`、`Info.plist`、`Assets.xcassets`（含 AppIcon / Logo）
- `scripts/`、`store/artwork/`（图标与截图说明）
- `ExportOptions.plist.example`、`signing.properties.example`、`signing/README.md`
- `LICENSE`、`README.md`、`.gitignore`

**勿提交**（已在 `.gitignore`）

- `ExportOptions.plist`、`signing.properties`、`signing/material/`
- `build/`、`DerivedData/`、`*.ipa`、`*.xcarchive`、`store/release/`
- `xcuserdata/`、证书与描述文件

---

## 目录速查

```text
5min-ios-app/
├── FiveMin.xcodeproj
├── FiveMin/
│ ├── Info.plist
│ ├── Assets.xcassets/ # AppIcon · Logo · AccentColor
│ ├── Resources/shared/ # ← export-shared
│ ├── Features/Timer/
│ ├── Data/
│ └── Services/
├── scripts/
│ ├── generate_icons.py
│ └── release.sh
├── store/artwork/ # 商店图标 / 截图目录
├── signing/ # 本地签名说明；material/ 不入库
├── ExportOptions.plist.example
├── signing.properties.example
├── LICENSE
└── README.md
```

## 说明

本工具仅供习惯提醒；数据仅存本机。
