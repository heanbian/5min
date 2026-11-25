# 5min

**如厕计时器** — 多端仓库。运营方：学记宝。官网：[https://5min.chat](https://5min.chat/)。

- **定名**：如厕计时器
- **运营方**：学记宝
- **官网**：https://5min.chat

## 子项目

| 目录 | 说明 |
|------|------|
| [`5min-web`](./5min-web) | 网页端（Node · Express · PostgreSQL，静态资源在 `public/`），部署于 5min.chat；提供 App 云存储 API `/api/v1/storage`（数据存放于中国境内） |
| [`5min-android-app`](./5min-android-app) | Android 原生（Kotlin · Compose），`applicationId`：`chat.fivemin.app` |
| [`5min-harmony-app`](./5min-harmony-app) | HarmonyOS NEXT 原生（ArkTS），`bundleName`：`chat.5min.app` |
| [`5min-ios-app`](./5min-ios-app) | iOS 原生（SwiftUI），`PRODUCT_BUNDLE_IDENTIFIER`：`chat.5min.app` |
| [`5min-mp`](./5min-mp) | 微信小程序（原生 WXML / WXSS / JS） |

说明：Android 包名每一段不能以数字开头，因此 Android 使用 `chat.fivemin.app`；iOS / 鸿蒙仍可用 `chat.5min.app`。各端应用显示名均为「如厕计时器」。

## 共享文案与场景

文案源：`5min-web/public/js/i18n/locales.js`。在 Web 子项目中导出并同步到各原生端：

```bash
cd 5min-web && npm run export-shared
# 或：node scripts/export-shared.mjs
```

## 本地预览（Web）

```bash
cd 5min-web
cp -n server.conf.example server.conf   # 填写 DB_* / PORT
npm install
npm run dev                             # 或 ./run.sh → http://127.0.0.1:3300/
```

## 仓库约定

- **勿提交**：签名密钥 / `*.jks` / `ExportOptions.plist` / `signing.properties` / `keystore.properties` / `local.properties` / 鸿蒙本地 `build-profile.json5`（用 `build-profile.json5.example`）/ 微信 `project.private.config.json` 与 `private.*.key` / IDE 与 AI 工具目录（`.idea/`、`.vscode/`、`.cursor/`）/ 各端 `build` 与本地虚拟环境 / `5min-web/server.conf` / 各端商店截图与创意图（`store/artwork/screenshots/`、`store/artwork/creative/`）/ 本地测试产物
- **商店素材**：各端 `store/artwork/` 下图标可入库；截图 / 创意图 / `store/release/` 包体本地生成，已忽略
- **共享文案**：以 `5min-web/public/js/i18n/locales.js` 为源，用 `export-shared.mjs` 同步到 Android / 鸿蒙 / iOS / 小程序

## 许可

各子项目沿用 [Apache-2.0](./LICENSE)。仅供习惯提醒。
