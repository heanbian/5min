# 如厕计时器（微信小程序）

端侧倒计时工具的**原生微信小程序**子项目（WXML / WXSS / JavaScript，无 uni-app、Taro、Vue、React 等框架，无 npm 运行时依赖）。运营方：学记宝。官网：https://5min.chat。与 Web / 鸿蒙 / iOS / Android 端功能对齐。

默认场景为「如厕 · 5 分钟」，亦可选 3 / 10 分钟与多场景；结束后振动提醒起身。

仅供习惯提醒，不构成医疗建议。界面支持**简体中文 / 繁體中文 / English**。

## 功能

| 功能 | 说明 |
|------|------|
| 三 Tab | 记录 / 首页 / 我的 |
| 时长设置 | 「我的」可设默认时长（1–120 分钟） |
| 场景预设 | 多列选择器（分组）；默认「如厕 · 5 分钟」 |
| 近 14 日记录 | 本机 `wx.storage`（`5min.chat.history.v1`），三行展示 |
| 今日累计 | 主页展示当日完成次数与累计时长 |
| 环境音 | 雨声 / 海浪 / 钟声 / 关闭；主页喇叭入口进入「我的」 |
| 隐私同意 | 首次启动门禁；条款经 https `web-view` 打开（仅 `5min.chat`） |
| 计时控制 | 开始、暂停、重置；绝对时间戳结算 |
| 到期提醒 | 振动 + Toast；计时中尝试保持屏幕常亮 |
| 备案 | 「我的 › 备案」弹窗展示备案号 |

版本号：`1.0.6`（见 `app.js` → `globalData.appVersion`）。

## 技术栈

- 原生小程序：`app.*` + `pages/*` + `utils/*`
- 场景与文案：`shared/`（与鸿蒙 / Web shared-export 同源；运行时读 `.js` 模块）
- 调试基础库：见 `project.config.json` 的 `libVersion`

## 本地预览

1. 安装并打开 [微信开发者工具](https://developers.weixin.qq.com/miniprogram/dev/devtools/download.html)
2. 选择「导入项目」，目录指向本仓库的 `5min-mp/`
3. AppID 使用 `project.config.json` 中已配置的正式 AppID

隐私 / 条款页使用 `<web-view>`，正式环境需在小程序后台配置业务域名 `5min.chat`。

上传代码密钥（`private.*.key`）仅用于 CI / `miniprogram-ci`，已在 `.gitignore` 与 `packOptions.ignore` 中排除，勿提交仓库。

## 校验

```bash
node scripts/verify.mjs
```

## 目录结构

```
5min-mp/
├── app.js / app.json / app.wxss
├── pages/
│   ├── index/      # 计时主页
│   ├── records/    # 近 14 日记录
│   ├── mine/       # 语言 / 环境音 / 时长 / 关于 / 备案
│   └── webview/    # https 外链（域名白名单）
├── utils/          # i18n、prefs、history、提醒、环境音…
├── shared/         # scenes + locales（zh-CN / zh-TW / en）
├── scripts/        # 本地校验
└── assets/         # logo / 喇叭 / tab 图标
```

## 同步共享文案

```bash
# 以 Web locales.js 为源；会同步 Android / 鸿蒙 / iOS，并生成小程序 JSON + .js
cd ../5min-web && node scripts/export-shared.mjs
```

同步后请复查小程序侧专有键（如 `invalidLink`、`feedbackEmail`、`beianIcp`）。

## 许可

Apache-2.0（见 `LICENSE`）。
