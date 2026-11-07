# 5min-mp · 如厕计时器（微信小程序）

端侧倒计时习惯提醒工具的**原生微信小程序**子项目（WXML / WXSS / JavaScript，无 uni-app、Taro、Vue、React 等框架，无 npm 运行时依赖）。与 [5min.chat](https://5min.chat/) 及鸿蒙 / iOS / Android 端功能对齐。

默认 5 分钟预设，亦可选 3 / 10 分钟与多场景预设；计时结束后振动提醒起身活动。无需注册，无广告；计时与统计在本机完成，不向服务端上传用户数据。

本工具仅供习惯提醒。界面支持**简体中文 / 繁體中文 / English**（与鸿蒙一致）。

## 功能

| 功能 | 说明 |
|------|------|
| 三 Tab | 记录 / 主页 / 我的（对齐鸿蒙） |
| 时长预设 | 3 / 5 / 10 分钟快速切换；「我的」可设默认时长 |
| 场景预设 | 多列选择器（分组） |
| 近 14 日记录 | 本机 `wx.storage`（`5min.chat.history.v1`），三行展示，升级可查 |
| 今日累计 | 主页展示当日完成次数与累计时长 |
| 环境音 | 雨声 / 海浪声 / 钟声 / 关闭；主页喇叭进「我的」 |
| 隐私同意 | 首次启动门禁；链接经 https `web-view` 打开 |
| 计时控制 | 开始、暂停、重置；绝对时间戳结算 |
| 到期提醒 | 振动 + Toast；计时中尝试保持屏幕常亮 |

版本号：`1.0.6`（与鸿蒙对齐，见 `app.js` → `globalData.appVersion`）。

## 技术栈

- 原生小程序：`app.*` + `pages/*` + `utils/*`
- 场景与文案：`shared/`（与鸿蒙 / Web shared-export 同源；运行时读 `.js` 模块）
- 调试基础库：见 `project.config.json` 的 `libVersion`

## 本地预览

1. 安装并打开 [微信开发者工具](https://developers.weixin.qq.com/miniprogram/dev/devtools/download.html)
2. 选择「导入项目」，目录指向本仓库的 `5min-mp/`
3. AppID 使用 `project.config.json` 中已配置的正式 AppID

隐私 / 条款 / 反馈页使用 `<web-view>`，正式环境需在小程序后台配置业务域名 `5min.chat`。

上传代码密钥（`private.*.key`）仅用于 CI / `miniprogram-ci`，已在 `.gitignore` 与 `packOptions.ignore` 中排除，勿提交仓库。

## 目录结构

```
5min-mp/
├── app.js / app.json / app.wxss
├── pages/
│   ├── index/      # 计时主页
│   ├── records/    # 近 14 日记录
│   ├── mine/       # 语言 / 提示音 / 时长 / 关于
│   └── webview/    # https 外链
├── utils/          # i18n、prefs、history、提醒、环境音…
├── shared/         # scenes + locales（zh-CN / zh-TW / en）
└── assets/         # logo / 喇叭 / tab 图标
```

## 同步共享文案

```bash
# 推荐先在 Web 导出，再拷到小程序（JSON 仅作源；运行时 require 的是 .js）
cd ../5min-web && node scripts/export-shared.mjs && cd ../5min-mp
HAR=../5min-harmony-app/entry/src/main/resources/rawfile/shared
MP=./shared
mkdir -p "$MP/locales"
cp "$HAR/scenes.json" "$MP/scenes.json"
cp "$HAR/locales/zh-CN.json" "$MP/locales/zh-CN.json"
cp "$HAR/locales/zh-TW.json" "$MP/locales/zh-TW.json"
cp "$HAR/locales/en.json" "$MP/locales/en.json"
node -e "
const fs=require('fs');
const dir='./shared';
fs.writeFileSync(dir+'/scenes.js','module.exports = '+fs.readFileSync(dir+'/scenes.json','utf8').trim()+';\\n');
for (const [src, dest] of [
  ['locales/zh-CN.json','locales/zh_CN.js'],
  ['locales/zh-TW.json','locales/zh_TW.js'],
  ['locales/en.json','locales/en.js'],
]) {
  fs.writeFileSync(dir+'/'+dest,'module.exports = '+fs.readFileSync(dir+'/'+src,'utf8').trim()+';\\n');
}
"
```

## 许可

Apache-2.0（见 `LICENSE`）。
