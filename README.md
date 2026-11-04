# 5min

如厕计时器 · 五分钟 — 多端仓库。正式站点：[5min.chat](https://5min.chat/)。

## 子项目

| 目录 | 说明 |
|------|------|
| [`5min-web`](./5min-web) | 网页端（HTML / CSS / JS），部署于 5min.chat |
| [`5min-android-app`](./5min-android-app) | Android 原生（Kotlin · Compose），`applicationId`：`chat.5min.app` |
| [`5min-harmony-app`](./5min-harmony-app) | HarmonyOS NEXT 原生（ArkTS），`bundleName`：`chat.5min.app` |
| [`5min-ios-app`](./5min-ios-app) | iOS 原生（SwiftUI），`PRODUCT_BUNDLE_IDENTIFIER`：`chat.5min.app` |

源码包名（Android Kotlin 命名空间）：`chat.fivemin.app`（标识符段不能以数字开头）。

## 共享文案与场景

在 Web 子项目中导出并同步到各原生端：

```bash
cd 5min-web && node scripts/export-shared.mjs
```

## 本地预览（Web）

```bash
cd 5min-web && ./run.sh
```

## 许可

各子项目沿用 Apache-2.0（见 `5min-web/LICENSE`）。本工具仅供习惯提醒，不构成医疗建议。
