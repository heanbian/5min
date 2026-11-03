# 5min · 如厕计时器

端侧倒计时提醒工具。正式站点：[5min.xuejibao.dev](https://5min.xuejibao.dev/)。源码仓库：[github.com/heanbian/5min](https://github.com/heanbian/5min)。

如厕时使用移动设备易导致时长感知失准。本工具提供可预设的倒计时，到期通过震动、提示音与系统通知提醒起身活动。无需注册，页面无广告；计时与提醒均在浏览器本地完成，不向服务端上传用户数据。

本工具仅供习惯提醒，**不构成医疗建议**，亦不替代专业诊疗意见。公开资料常建议将单次如厕时间控制在约 5 分钟以内，具体因人而异。

## 功能

| 功能 | 说明 |
|------|------|
| 时长预设 | 3 / 5 / 10 分钟快速切换 |
| 计时控制 | 开始、暂停、重置；以绝对时间戳结算，减轻后台定时器节流导致的漂移 |
| 状态反馈 | 进行中（绿）→ 最后 1 分钟（琥珀）→ 超时（红） |
| 到期提醒 | Vibration API（设备支持时）、Web Audio 提示音、Notification API（用户授权后） |
| 屏幕唤醒 | 计时中尝试申请 Screen Wake Lock，降低熄屏漏看概率 |

## 技术栈

纯 **HTML5 + 现代原生 JavaScript（ES modules）**：`index.html` + `i18n/locales.js`，无框架、无打包、无第三方运行时依赖。

使用的浏览器原生能力包括：绝对时间戳倒计时、`Notification`、`Vibration`、`AudioContext`、Screen Wake Lock、Page Visibility、SVG 进度环。

多语言（`i18n/locales.js`）：简体中文、繁体中文、English，以及日本語、한국어、Español。右上角切换；优先 `?lang=`，其次 `localStorage`，再次浏览器语言。

> **本地预览须用 HTTP 服务。** Chrome 等浏览器在 `file://` 下会拦截 ES module 的跨文件 `import`，请勿直接双击打开。

```bash
./run.sh        # 默认 8080
./run.sh 3000   # 指定端口
```

可部署至任意静态托管（对象存储、CDN、Nginx 等）。

字体：自托管 [Noto Sans SC](https://fonts.google.com/noto/specimen/Noto+Sans+SC)（[SIL Open Font License 1.1](https://scripts.sil.org/OFL)，可免费商用），不依赖第三方字体 CDN。

## 术语与文案约定

- 产品名：`如厕计时器`；品牌字标：`5min`；页面标题形如 `如厕计时器 · 五分钟`。
- 对外说明优先使用书面用语：端侧处理、倒计时、系统通知、Screen Wake Lock、绝对时间戳等。
- `site.json` 的 `description` 须包含正式域名 `5min.xuejibao.dev`，以及「无广告」与「不向服务端上传 / 不会上传」语义；修改后同步 `index.html` 的 `meta` / Open Graph / Twitter / JSON-LD 与 `site.webmanifest`。
- `site.json` 的 `origin` 为 `https://5min.xuejibao.dev`，并与 `robots.txt`、`sitemap.xml`、canonical、`og:url`、`og:image` 保持一致。

## 目录结构

```
5min/
├── index.html              # 页面、SEO 与计时逻辑（ES module）
├── i18n/
│   └── locales.js          # 多语言文案（ES module export）
├── fonts.css               # @font-face（Noto Sans SC）
├── fonts/                  # 自托管 woff2 + OFL.txt
├── site.json               # 站点元数据与页面文案
├── site.webmanifest        # PWA 清单
├── robots.txt
├── sitemap.xml
├── favicon.ico
├── img/
│   ├── logo.svg            # 标识主源
│   ├── logo.png
│   └── apple-touch-icon.png
├── scripts/
│   └── raster-logo.js      # SVG 栅格化为 PNG / ICO
├── run.sh                  # 本地预览（可指定端口）
├── LICENSE                 # Apache License 2.0 全文
├── NOTICE                  # 署名、品牌与第三方声明
├── .gitignore
└── README.md
```

## 本地预览

```bash
./run.sh           # 默认端口 8080 → http://127.0.0.1:8080/
./run.sh 3000      # 指定端口
PORT=9000 ./run.sh # 环境变量指定端口
```

开发联调：

- 短时结束：`?sec=2`（单位：秒）
- 指定语言：`?lang=en` / `zh-CN` / `zh-TW` / `ja` / `ko` / `es`

## 部署

将仓库静态文件原样发布至站点根目录即可；无需 Node.js 生产依赖。确保生产域名与 `site.json` 的 `origin` 及 SEO 绝对 URL 一致。

## 品牌标识

主标识为 `img/logo.svg`。重新导出 PNG 与 favicon：

```bash
npm install --no-save @resvg/resvg-js
node scripts/raster-logo.js
```

## 行为说明

- 页面重新可见时按结束时间戳校准剩余时间；后台 `setTimeout` 被节流时，回到前台仍可正确结束。
- 首次开始计时时按需请求通知权限；拒绝授权不影响计时。
- 计时进行中禁用时长预设，降低误触；空格键可切换开始 / 暂停（焦点不在表单控件时）。

## 许可

| 内容 | 许可 |
|------|------|
| 本仓库源代码与站点资源（除字体外） | [Apache License 2.0](LICENSE) |
| `fonts/` 中的 Noto Sans SC | [SIL Open Font License 1.1](fonts/OFL.txt) |

**SPDX-License-Identifier:** `Apache-2.0 AND OFL-1.1`（字体文件为 OFL-1.1）

再分发或修改时须：

1. 保留版权声明与本许可副本；
2. 保留 [`NOTICE`](NOTICE) 中的归属与品牌说明；
3. 对修改过的文件作出显著变更说明（Apache-2.0 §4(b)）。

Apache-2.0 **不授予**「5min」「五分钟」「如厕计时器」及官方域名等名称、标识的商标或品牌使用权；衍生作品可自由使用代码，但不得在未经许可的情况下冒用官方品牌。
