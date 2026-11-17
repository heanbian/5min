# 5min-web · 如厕计时器

端侧倒计时工具的 **Web 服务**子项目（Node.js + Express + PostgreSQL，静态资源位于 `public/`）。官网：[https://5min.chat](https://5min.chat/)。源码仓库：[github.com/heanbian/5min](https://github.com/heanbian/5min)。

**定名**：如厕计时器。**官网**：https://5min.chat。建议单次如厕约 5 分钟内完成；使用手机易低估耗时。默认 5 分钟（亦可选 3 / 10 分钟），结束后以振动、提示音与系统通知提醒起身。

仅供习惯提醒。

## 功能

| 功能 | 说明 |
|------|------|
| 时长预设 | 3 / 5 / 10 分钟快速切换 |
| 场景预设 | 分组场景选择：日常 / 烹饪 / 护肤 / 休息 / 学习 / 办公 / 班次 / 农事 / 家务等 |
| 今日累计 | 浏览器本机记录当日完成次数与累计时长（`localStorage`） |
| 环境音 | 雨声 / 海浪声 / 钟声（Web Audio 程序化，无外部音源文件） |
| 计时控制 | 开始、暂停、重置；以绝对时间戳结算，减轻后台定时器节流导致的漂移 |
| 状态反馈 | 进行中（绿）→ 剩余不足 1 分钟（琥珀）→ 超时（红） |
| 到期提醒 | Vibration API（设备支持时）、Web Audio 提示音、Notification API（用户授权后） |
| 屏幕唤醒 | 计时过程中尝试申请 Screen Wake Lock |
| 轻量 PWA | `public/site.webmanifest` + `public/sw.js` 预缓存计时壳；改壳资源后请 bump `CACHE` |
| 访客记录 | 服务端写入 PostgreSQL 表 `fivemin_visitor_log`（无管理页） |
| 云存储 API | 端侧可选：设备凭证绑定偏好与近 14 日会话（`/api/v1/storage`） |
| 健康检查 | `GET /api/status` → `{ success, data }` |

## 技术栈

| 层 | 说明 |
|----|------|
| 服务端 | Node.js ≥ 24 · Express 5 · Helmet · `pg`；目录布局对齐学记宝 [`tools`](https://github.com/heanbian) 类项目：`server.js` / `bizjs/` / `routes/` / `public/` |
| 前端 | `public/` 内 HTML5 + 原生 ES modules，无框架、无前端打包 |
| 数据 | Web 计时默认仍存浏览器本机；App 可选云端同步。PostgreSQL：访客日志 + 云存储表 |

多语言（`public/js/i18n/locales.js`）：简体中文、繁体中文、English、Deutsch、Русский、Français、བོད་ཡིག。右上角切换；优先 `?lang=`，其次 `localStorage`，再次浏览器语言。

字体：自托管 [Noto Sans SC](https://fonts.google.com/noto/specimen/Noto+Sans+SC)（[SIL OFL 1.1](https://scripts.sil.org/OFL)）。

## 目录结构

```
5min-web/
├── server.js                 # HTTP 入口（中间件、静态托管、页面路由、优雅退出）
├── server.conf.example       # 配置模板 → 复制为 server.conf（已 gitignore）
├── package.json              # npm scripts：dev / start / test / export-shared / build:pkg
├── bizjs/
│   ├── db.js                 # PostgreSQL 连接池（读 server.conf）
│   ├── paths.js              # 应用根 / public 路径解析（pkg 友好）
│   ├── visitor-log.js        # 访客 DDL、中间件、地理解析与限流
│   └── cloud-storage.js      # 设备云存储 DDL / 鉴权 / 偏好与会话
├── routes/
│   ├── public.js             # GET /api/status
│   └── storage.js            # /api/v1/storage/*
├── public/                   # 对外静态根（部署时与二进制同级，勿打进 ncc/pkg）
│   ├── index.html            # 计时主页
│   ├── about.html            # 关于
│   ├── faq.html              # 常见问题
│   ├── privacy.html          # 隐私政策
│   ├── terms.html            # 用户协议
│   ├── 404.html
│   ├── css/                  # fonts.css · app.css · about.css
│   ├── js/
│   │   ├── boot.js           # SW 注册 / file:// 提示
│   │   ├── app.js            # 计时主逻辑
│   │   ├── alert.js          # 到期声音 / 振动
│   │   ├── ambient.js        # 环境音
│   │   ├── stats.js          # 今日累计
│   │   └── i18n/locales.js   # 多语言文案（各端共享源）
│   ├── fonts/ · img/
│   ├── site.json             # 站点元数据、页面列表、faqs
│   ├── site.webmanifest · sw.js
│   ├── llms.txt · robots.txt · sitemap.xml
│   └── favicon.ico
├── scripts/
│   ├── export-shared.mjs     # 导出场景 / 文案到 Android · 鸿蒙 · iOS · 小程序
│   └── raster-logo.js        # SVG → PNG / ICO
├── shared-export/            # 导出中间产物（勿当长期编辑源）
├── test/
│   ├── http-security-perf.test.js
│   └── visitor-log.test.js
├── run.sh                    # → npm run dev
├── start.sh / stop.sh        # 后台启停（fivemin.pid）
├── LICENSE · NOTICE
└── README.md
```

## 本地运行

```bash
cp -n server.conf.example server.conf   # 填写 DB_*、PORT（默认 8080）
npm install
npm run dev                             # 或 ./run.sh → http://127.0.0.1:8080/
```

生产 / 后台：

```bash
npm start                 # 前台
node server.js -d         # 或 ./start.sh（写 fivemin.pid）
./stop.sh
```

测试：

```bash
npm test                  # node --test（安全头 / 路径穿越 / 延迟与并发）
```

打包（`public/` **不**打进包，须与二进制同级部署）：

```bash
npm run build:pkg
# 产物旁放置 public/ + server.conf
```

## 配置说明

见 `server.conf.example`：

| 变量 | 含义 |
|------|------|
| `PORT` | 监听端口，默认 `8080` |
| `TRUST_PROXY` | 置于可信反代后设为 `1`；须由反代剥离/覆写伪造头 |
| `DB_*` | PostgreSQL 连接；启动时确保访客表与云存储表 |
| `STORAGE_PEPPER` | 设备 secret 哈希盐（生产务必更换） |
| `VISITOR_GEO_ENABLED` | 访客地理解析（默认开；可关） |
| `FIVEMIN_ROOT` / `FIVEMIN_PUBLIC` | 覆盖应用根 / `public` 路径（打包部署用） |

无独立 migration 目录；表结构在进程监听后按需确保（与 `tools` 一致）。

### 云存储 API（`/api/v1/storage`）

端侧在「我的 › 数据存储」选择云端后，用本机生成的 `deviceId`（UUID）+ `deviceSecret`（≥32 位 hex）注册并同步。服务端只存 secret 的 SHA-256（加 pepper）。

| 方法 | 路径 | 说明 |
|------|------|------|
| `POST` | `/register` | 注册或校验设备凭证 |
| `GET` | `/snapshot` | 拉取偏好 + 近 14 日会话 |
| `PUT` | `/prefs` | 覆盖偏好 |
| `PUT` | `/sessions` | 批量 upsert 会话（`clientId`） |
| `PUT` | `/snapshot` | 偏好与会话一并写入后返回快照 |
| `DELETE` | `/sessions/:clientId` | 软删除单条 |
| `POST` | `/sessions/clear` | 清空该设备云端会话 |

鉴权头：`X-Device-Id`、`X-Device-Secret`。写操作按 IP 限流。响应形如 `{ success, data }` / `{ success: false, message }`。

## 共享文案导出

```bash
npm run export-shared
# 等价：node scripts/export-shared.mjs
```

文案源：`public/js/i18n/locales.js`。同步至 Android / HarmonyOS / iOS / 微信小程序 `shared/`。

## 术语与文案约定

- **定名**：`如厕计时器`；官网：`https://5min.chat`。
- 对外说明使用书面用语：端侧、倒计时、振动（勿用口语「震动」）、提示音、系统通知等；避免堆砌「无广告 / 无需注册」等口号。
- 界面状态优先「倒计时中 / 计时结束，请起身活动 / 重新开始」。
- 合规：仅供习惯提醒；不作疗效/诊断宣称；JSON-LD `applicationCategory` 使用 `UtilitiesApplication`。
- 修改对外文案时同步 `public/site.json`、对应 HTML、`llms.txt`、`site.webmanifest`、`sitemap.xml` 与 JSON-LD；`origin` 保持 `https://5min.chat`。

### GEO

- `public/llms.txt`：站点摘要与链接。
- `public/about.html` / `public/faq.html`：独立可读页（`lang="zh-CN"`）。
- FAQ 可见文案须与 `site.json` 中 `faqs` 及 JSON-LD `FAQPage` 一致。

## 关联项目

- Android：[`../5min-android-app`](../5min-android-app)（`applicationId`：`chat.fivemin.app`）
- HarmonyOS：[`../5min-harmony-app`](../5min-harmony-app)（`bundleName`：`chat.5min.app`）
- iOS：[`../5min-ios-app`](../5min-ios-app)（`PRODUCT_BUNDLE_IDENTIFIER`：`chat.5min.app`）
- 微信小程序：[`../5min-mp`](../5min-mp)
