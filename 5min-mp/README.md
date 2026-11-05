# 5min-mp · 如厕计时器（微信小程序）

端侧倒计时习惯提醒工具的**原生微信小程序**子项目（WXML / WXSS / JavaScript，无 uni-app、Taro、Vue、React 等框架，无 npm 运行时依赖）。与 [5min.chat](https://5min.chat/) 及各原生端对齐。

默认 5 分钟预设，亦可选 3 / 10 分钟与多场景预设；计时结束后振动提醒起身活动。无需注册，无广告；计时与统计在本机完成，不向服务端上传用户数据。

本工具仅供习惯提醒。界面文案固定**简体中文**。

## 功能

| 功能 | 说明 |
|------|------|
| 时长预设 | 3 / 5 / 10 分钟快速切换（分段控件） |
| 场景预设 | 多列选择器（分组）：日常 / 烹饪 / 护理 / 休憩 / 学习 / 工作 / 工勤 / 农事 / 家务等 |
| 今日累计 | 本机记录当日完成次数与累计时长（`wx.storage`，不上传） |
| 环境音 | 雨声 / 海浪声 / 钟声（`wx.createWebAudioContext` 程序化，无外部音源文件） |
| 计时控制 | 开始、暂停、重置；以绝对时间戳结算，减轻后台节流漂移 |
| 状态反馈 | 进行中（绿）→ 剩余不足 1 分钟（琥珀）→ 超时（红） |
| 到期提醒 | 振动 + Toast；计时过程中尝试保持屏幕常亮 |
| 表盘 | 七段电子表数字 + 进度环（与 Web / Android 对齐） |

## 技术栈

- 原生小程序：`app.*` + `pages/index/*` + `utils/*`
- 入口页：`pages/index/index`
- 场景与文案：`shared/`（与 `5min-web/shared-export` 同源；运行时读 `.js` 模块）
- 调试基础库：见 `project.config.json` 的 `libVersion`（当前 `3.17.4`）

## 本地预览

1. 安装并打开 [微信开发者工具](https://developers.weixin.qq.com/miniprogram/dev/devtools/download.html)
2. 选择「导入项目」，目录指向本仓库的 `5min-mp/`
3. AppID 使用 `project.config.json` 中已配置的正式 AppID

上传代码密钥（`private.*.key`）仅用于 CI / `miniprogram-ci`，已在 `.gitignore` 与 `packOptions.ignore` 中排除，勿提交仓库。

## 目录结构

```
5min-mp/
├── app.js / app.json / app.wxss
├── project.config.json
├── pages/index/          # 计时主页（首页）
├── utils/                # 文案、场景、统计、提醒、环境音、七段表
├── shared/               # scenes + zh-CN（与 Web shared-export 对齐）
└── assets/               # logo / 图标
```

## 同步共享文案

```bash
cd ../5min-web && node scripts/export-shared.mjs
cp shared-export/scenes.json ../5min-mp/shared/scenes.json
cp shared-export/locales/zh-CN.json ../5min-mp/shared/zh-CN.json
node -e "
const fs=require('fs');
const dir='../5min-mp/shared';
fs.writeFileSync(dir+'/scenes.js','module.exports = '+fs.readFileSync(dir+'/scenes.json','utf8').trim()+';\\n');
fs.writeFileSync(dir+'/locales/zh_CN.js','module.exports = '+fs.readFileSync(dir+'/zh-CN.json','utf8').trim()+';\\n');
"
```

## 许可

Apache-2.0（见 `LICENSE`）。
