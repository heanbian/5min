# 如厕计时器 · 五分钟

上厕所玩手机容易超时。点一下，五分钟倒计时，到点提醒你起来——别让腿麻成为日常。

纯前端 HTML5，无服务端、无注册、无广告；计时与提醒均在本机完成，不会上传。

正式用途：医学建议如厕时间控制在约 5 分钟内；本工具只做提醒，不替代任何医疗建议。

## 术语与文案约定

- 页面名称：`如厕计时器 · 五分钟`（工具名 + 品牌）。
- `site.json` 的 `description` 须含「无广告」与「不会上传」；改文案时同步 `index.html` 的 `meta` / Open Graph / Twitter / JSON-LD，以及 `site.webmanifest`。
- 正式域名写在 `site.json` 的 `origin`；部署后同步 `robots.txt`、`sitemap.xml` 与页面内 canonical / `og:url` / `og:image`。

## 功能

| 能力 | 说明 |
|------|------|
| 预设时长 | 3 / 5 / 10 分钟一键切换 |
| 开始 / 暂停 / 重置 | 基于绝对时间戳，避免后台节流导致漂移 |
| 视觉状态 | 正常绿 → 最后 1 分钟琥珀 → 超时红 |
| 到点提醒 | 震动（支持时）+ 轻提示音 + 系统通知（授权后） |
| 屏幕常亮 | 计时中尝试请求 Screen Wake Lock，减少灭屏漏看 |

技术栈：单页 `index.html`（内联 CSS / JS）。无构建步骤。

## 目录

```
5min/
├── index.html              # 页面、SEO meta / JSON-LD 与全部逻辑
├── site.json               # 站点名、origin、页面 title / description
├── site.webmanifest
├── robots.txt
├── sitemap.xml
├── favicon.ico
├── img/
│   ├── logo.svg
│   ├── logo.png
│   └── apple-touch-icon.png
├── scripts/
│   └── raster-logo.js
├── .gitignore
└── README.md
```

## 使用

用任意静态服务器或直接打开均可：

```bash
# 推荐：本地静态服务（避免 file:// 下通知等 API 受限）
npx --yes serve .
# 或
python3 -m http.server 8080
```

浏览器打开提示的地址（如 `http://localhost:3000`）。

## 标志

`img/logo.svg` 为站点标识。重新导出 PNG / ICO：

```bash
npm install --no-save @resvg/resvg-js
node scripts/raster-logo.js
```

## 说明

- 切回标签页时会按结束时间戳重新校准；后台 `setTimeout` 被节流时仍能在回到前台时正确结束。
- 首次点击「开始」时会按需请求通知权限；拒绝不影响计时本身。
- 计时中会锁定预设切换，避免误触改时长；空格键可开始 / 暂停。
- 联调短时结束可用 `?sec=2`（例如 `http://localhost:8080/?sec=2`）。
- 本仓库为纯静态资源，可放到任意 CDN / 对象存储 / Nginx 根目录。
