# 5min-mp · 如厕计时器（微信小程序）

端侧倒计时习惯提醒工具的微信小程序子项目。与 [5min.chat](https://5min.chat/) 及各原生端对齐：默认 5 分钟预设，亦可选 3 / 10 分钟与多场景预设；计时结束后振动提醒起身活动。无需注册，无广告；计时与统计在本机完成，不向服务端上传用户数据。

本工具仅供习惯提醒。

## 功能

| 功能 | 说明 |
|------|------|
| 时长预设 | 3 / 5 / 10 分钟快速切换 |
| 场景预设 | 多列选择器（分组）：日常 / 烹饪 / 护理 / 休憩 / 学习 / 工作 / 工勤 / 农事 / 家务等 |
| 今日累计 | 本机记录当日完成次数与累计时长（`wx.storage`，不上传） |
| 计时控制 | 开始、暂停、重置；以绝对时间戳结算，减轻后台节流漂移 |
| 状态反馈 | 进行中（绿）→ 剩余不足 1 分钟（琥珀）→ 超时（红） |
| 到期提醒 | 振动 + Toast；计时过程中尝试保持屏幕常亮 |

## 技术栈

原生微信小程序（WXML / WXSS / JavaScript），无第三方框架、无打包依赖。场景与文案来自 `shared/`（与 `5min-web/shared-export` 同源拷贝）。

## 本地预览

1. 安装并打开 [微信开发者工具](https://developers.weixin.qq.com/miniprogram/dev/devtools/download.html)
2. 选择「导入项目」，目录指向本仓库的 `5min-mp/`
3. AppID 可先使用测试号 / `touristappid`（见 `project.config.json`）；正式发布前替换为已注册的小程序 AppID

## 目录结构

```
5min-mp/
├── app.js / app.json / app.wxss
├── project.config.json
├── pages/index/          # 计时主页
├── utils/                # i18n、场景目录、今日累计、到期提醒
├── shared/               # 与 Web 端 shared-export 对齐的场景与简体中文文案
└── assets/               # logo / 图标
```

## 同步共享文案

在 Web 子项目导出后，可将产物拷贝到本目录 `shared/`：

```bash
cd ../5min-web && node scripts/export-shared.mjs
cp shared-export/scenes.json ../5min-mp/shared/scenes.json
cp shared-export/locales/zh-CN.json ../5min-mp/shared/zh-CN.json
# 小程序运行时读取 .js 模块（JSON 仅作同步源；界面固定简体中文）
node -e "
const fs=require('fs');
const dir='../5min-mp/shared';
fs.writeFileSync(dir+'/scenes.js','module.exports = '+fs.readFileSync(dir+'/scenes.json','utf8').trim()+';\\n');
fs.writeFileSync(dir+'/locales/zh_CN.js','module.exports = '+fs.readFileSync(dir+'/zh-CN.json','utf8').trim()+';\\n');
"
```

## 许可

Apache-2.0（见 `LICENSE`）。
