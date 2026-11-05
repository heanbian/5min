# 5min-web · 如厕计时器

端侧倒计时提醒工具（Web 子项目）。正式站点：[5min.chat](https://5min.chat/)。源码仓库：[github.com/heanbian/5min](https://github.com/heanbian/5min)。

**定名**：如厕计时器。公开资料通常建议将单次如厕时间控制在约 5 分钟以内；使用移动设备时，时长感知易失准。默认 5 分钟预设（亦可选 3 / 10 分钟），计时结束后通过振动、提示音与系统通知提醒起身活动。无需注册，无广告；计时与提醒在本机完成，不向服务端上传用户数据。

本工具仅供习惯提醒，**不构成医疗建议**，亦不替代专业诊疗意见；**本产品非医疗器械**。

## 功能

| 功能 | 说明 |
|------|------|
| 时长预设 | 3 / 5 / 10 分钟快速切换 |
| 场景预设 | 自定义下拉（分组）：日常 / 烹饪 / 护理 / 休憩 / 学习备考 / 工作办公 / 工勤劳作 / 农事劳作 / 家务等常用场景 |
| 今日累计 | 本机记录当日完成次数与累计时长（localStorage，不上传） |
| 环境音 | 雨声 / 海浪声 / 钟声（Web Audio 程序化，无外部音源文件） |
| 计时控制 | 开始、暂停、重置；以绝对时间戳结算，减轻后台定时器节流导致的漂移 |
| 状态反馈 | 进行中（绿）→ 剩余不足 1 分钟（琥珀）→ 超时（红） |
| 到期提醒 | Vibration API（设备支持时）、Web Audio 提示音、Notification API（用户授权后） |
| 屏幕唤醒 | 计时过程中尝试申请 Screen Wake Lock，以降低因熄屏而错过提醒的可能性 |

## 技术栈

纯 **HTML5 + 现代原生 JavaScript（ES modules）**：HTML 只写结构与 SEO；样式在 `css/`，逻辑在 `js/`，无框架、无打包、无第三方运行时依赖。

使用的浏览器原生能力包括：绝对时间戳倒计时、`Notification`、`Vibration`、`AudioContext`、Screen Wake Lock、Page Visibility、SVG 进度环。

多语言（`js/i18n/locales.js`）：简体中文、繁体中文、English、བོད་ཡིག（藏文）、日本語、العربية、Français、Русский、Español。右上角切换；优先 `?lang=`，其次 `localStorage`，再次浏览器语言。阿拉伯文自动切换 RTL。

> **本地预览须用 HTTP 服务。** Chrome 等浏览器在 `file://` 下会拦截 ES module 的跨文件 `import`，请勿直接双击打开。

```bash
./run.sh        # 默认 8080
./run.sh 3000   # 指定端口
```

可部署至任意静态托管（对象存储、CDN、Nginx 等）。

字体：自托管 [Noto Sans SC](https://fonts.google.com/noto/specimen/Noto+Sans+SC)（[SIL Open Font License 1.1](https://scripts.sil.org/OFL)，可免费商用），不依赖第三方字体 CDN。

## 术语与文案约定

- **定名（产品名）**：`如厕计时器`；品牌字标：`5min`。
- **SEO 标题常用**：`如厕计时器 · 五分钟`。
- 界面默认标题（`brandTitle`）展示「如厕计时器」；选中场景时展示场景名；通知简称可用「五分钟」。
- 对外说明优先使用书面用语：端侧、倒计时、振动（勿用口语「震动」）、提示音、系统通知、Screen Wake Lock、绝对时间戳、时长感知失准、本机完成等。
- 界面状态优先使用「倒计时进行中 / 计时已结束 / 重新开始」等书面表述，避免「再响」「再来一次」等口语。
- 合规底线：仅供习惯提醒；不构成医疗建议、不替代专业诊疗意见；**非医疗器械**；不作疗效/预防/诊断宣称；不采集健康敏感个人信息；计时与提醒在本机完成、不向服务端上传用户数据。JSON-LD `applicationCategory` 使用 `UtilitiesApplication`（勿用 `HealthApplication`）。
- `site.json` 的 `description` / FAQ 须包含正式域名 `5min.chat`、「无广告」与「不向服务端上传」语义；修改后同步 `index.html`、`about.html`、`llms.txt`、`site.webmanifest` 与 JSON-LD。
- `site.json` 的 `origin` 为 `https://5min.chat`，并与 `robots.txt`、`sitemap.xml`、canonical、`og:url`、`og:image` 保持一致。

### GEO（生成式引擎优化）

面向 AI 检索与引用，需提供可独立引用的说明与问答，且与结构化数据一致：

- `llms.txt`：站点摘要与关键链接（[llmstxt.org](https://llmstxt.org/) 约定），置于站点根路径。
- `about.html`：「关于」与「常见问题」独立页（`lang="zh-CN"`），供爬虫与模型直接读取；首页脚注链向该页。
- JSON-LD：`about.html` 使用 `AboutPage` + `FAQPage`；问题与答案须与页面可见文案逐字一致；修改 FAQ 时同步 `site.json` 对应页的 `faqs`。
- 回答中保留正式域名、无广告、本机计时不上传、非医疗建议、非医疗器械等关键事实。

## 目录结构

```
5min/
├── index.html              # 计时主页（纯 HTML + SEO / JSON-LD）
├── about.html              # 关于 / FAQ（纯 HTML + GEO）
├── privacy.html            # 隐私政策（应用商店可引用）
├── terms.html              # 用户协议
├── css/
│   ├── fonts.css           # @font-face（Noto Sans SC）
│   ├── app.css             # 计时页样式
│   └── about.css           # 关于页样式
├── js/
│   ├── boot.js             # file:// 协议提示
│   ├── app.js              # 计时逻辑（ES module）
│   ├── alert.js            # 跨端到期声音 / 振动
│   ├── stats.js            # 今日累计（localStorage）
│   ├── ambient.js          # 背景白噪音（Web Audio）
│   └── i18n/
│       └── locales.js      # 多语言文案
├── fonts/                  # 自托管 woff2 + OFL.txt
├── img/
│   ├── logo.svg            # 标识主源
│   ├── logo.png
│   └── apple-touch-icon.png
├── scripts/
│   └── raster-logo.js      # SVG 栅格化为 PNG / ICO
├── site.json               # 站点元数据、页面文案与 faqs
├── site.webmanifest        # PWA 清单
├── llms.txt                # 面向大模型的站点说明
├── robots.txt
├── sitemap.xml
├── favicon.ico
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
- 指定语言：`?lang=zh-CN` / `zh-TW` / `en` / `bo` / `ja` / `ar` / `fr` / `ru` / `es`

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
- 到期提醒（`js/alert.js`）同时走多条通道，以覆盖各端差异：
  - **声音**：Web Audio 提示音 + 内嵌 WAV 的 `HTMLAudioElement`；开始手势内解锁，计时中保活。
  - **iPhone**：无 Vibration API；将 `navigator.audioSession.type` 设为 `playback`，避免静音键导致 Web Audio 无声；旧系统辅以静音循环音频打开媒体通道；以低频方波提示音代替振动体感。
  - **Android / 鸿蒙**：`navigator.vibrate` 多段重试；熄屏或后台时常忽略振动，回到前台后将补发声音与振动。
  - **PC**：振动接口为空操作；依赖扬声器与（若已授权）系统通知提醒。
  - 结束后轻触表盘，可在用户手势下再次触发声音与振动（对 iOS 及部分机型尤为重要）。

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

## 同仓库其他端

本仓库为 monorepo，根目录见 [`../README.md`](../README.md)。

- Android：[`../5min-android-app`](../5min-android-app)（`applicationId`：`chat.5min.app`）
- HarmonyOS：[`../5min-harmony-app`](../5min-harmony-app)（`bundleName`：`chat.5min.app`）
- iOS：[`../5min-ios-app`](../5min-ios-app)（`chat.5min.app`）
- 共享场景 / 文案导出：`node scripts/export-shared.mjs`
