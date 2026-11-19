# 5min-harmony-app

**如厕计时器** — HarmonyOS 原生客户端。官网：https://5min.chat。

- **bundleName**：`chat.5min.app`
- **App ID（AGC）**：`6917621936327753309`
- **版本**：`AppScope/app.json5` → `versionName` / `versionCode`（与 Android `1.0.0` 对齐；`versionCode` 采用 `major*1000000+minor*1000+patch`）
- **技术**：ArkTS · ArkUI（Stage）· Preferences · Vibrator · Notification

## 功能

- 时长预设与分组场景（与 Web / Android 共享 `rawfile/shared`）
- 绝对时间戳倒计时；到期本地通知 + 约 5 秒报警音与振动
- 今日累计；多语言（简体中文、繁体中文、English、Deutsch、Русский、Français、བོད་ཡིག）
- 计时页常亮（`setWindowKeepScreenOn`）

## 打开工程

使用 **DevEco Studio 26.0.0+** 打开本目录。

若提示「工程结构及配置需要升级」：`Tools` → `Migrate Assistant`，或确认已有 `hvigor/hvigor-config.json5`（`modelVersion: 26.0.0`）后 `File` → `Sync and Refresh Project`。

共享配置由 Web 子项目导出：

```bash
cd ../5min-web && npm run export-shared
# 文案源：public/js/i18n/locales.js
```

图标重出（与 Android 同品牌）：

```bash
# 需 Pillow；可复用 Android 工程虚拟环境
../5min-android-app/.tools-venv/bin/python scripts/generate_icons.py
```

## 签名

### 调试（推荐）

`File` → `Project Structure` → `Signing Configs` → 勾选 **Automatically generate signature**。

### 正式发布（AppGallery）

1. 在 [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html) 使用应用 **App ID `6917621936327753309`**（包名 `chat.5min.app`），申请/下载发布证书与 Profile。
2. 将 `.p12` / `.cer` / `.p7b` 放到 `signing/material/`（已 gitignore）。当前发布材料约定：
   - 证书：`signing/material/5min_chat.cer`（亦可保留桌面下载名 `fivemin_chat.cer` 副本）
   - Profile：`signing/material/5min_chatRelease.p7b`（须含上述 App ID）
   - 密钥库：`signing/material/5min_chat.p12`（alias `5min_chat`）
3. **在 DevEco 里配置签名（推荐）**
 `File` → `Project Structure` → `Signing Configs` → 取消「Automatically generate signature」
 填入 Store File / Cert / Profile / 密码 / Alias → `Apply`。
 IDE 会把 `storePassword` / `keyPassword` **加密**写入 `build-profile.json5`（明文密码长度不足 32 会报 `00303116`）。
4. 可选：复制 `signing.properties.example` → `signing.properties` 仅作路径备忘；正式注入密码请用上一步 IDE，不要手写明文进 `build-profile.json5`。

> 若在 AGC 删除旧应用并新建，必须换用绑定新 App ID 的 Profile（`.p7b`），仅换证书不够。
> `signing.properties`、`signing/material/`、本地 `build-profile.json5`（含本机路径与加密密码）勿提交 Git；仓库只保留 `build-profile.json5.example`。
> 商店截图放 `store/artwork/screenshots/`（已 gitignore）；可用 `scripts/capture_store_screenshots.sh` 本地生成。

## 打包正式版（HAP / APP）

1. **改版本号**（每次上架递增）
 编辑 `AppScope/app.json5` → `versionName` / `versionCode`。

2. **出包**

```bash
chmod +x scripts/release.sh
./scripts/release.sh hap # → store/release/5min-harmony-app-1.0.0.hap
./scripts/release.sh app # → store/release/5min-harmony-app-1.0.0.app
```

也可在 DevEco：`Build` → `Build Hap(s)/APP(s)` → `Build App(s)`。

确认产物为 **`*-signed.app`**（不要上传 `*-unsigned.app`），且 `build-profile.json5` 里 product 的 `signingConfig` 指向**发布证书**（`signing/material/5min_chat.*`），不要用 `~/.ohos/config` 自动调试签名。

3. **上架**
 AppGallery Connect → 软件包管理 上传 `.app`；图标可用 `store/artwork/ic_launcher_1024.png`。
 若提示「软件包解析失败」，到软件包管理列表点错误码查看（常见：未签名包、调试 Profile、证书不匹配）。

## App Linking（应用链接）

域名 `https://5min.chat` 可直达已安装的客户端（未安装则打开网页版）。

1. **网站关联文件**（须公网可访问）：`https://5min.chat/.well-known/applinking.json`  
   源文件：`../5min-web/public/.well-known/applinking.json`（`appIdentifier` = AGC App ID）。
2. **开发者中心**：推广运营 → 增长运营 → App Linking → 应用链接 → 域名填 `https://5min.chat`（勿尾斜杠）→ 发布。校验依赖上一步 JSON。
3. **客户端**：`entry/src/main/module.json5` 中独立 skill（`entity.system.browsable` + `ohos.want.action.viewData` + `host: 5min.chat` + `domainVerify: true`）。须用**手动签名**安装验证；自动签名无法完成域名校验。
4. **设备校验**：安装后约等 20 秒，执行 `hdc shell hidumper -s AppDomainVerifyManager`，目标域名为 `success` 后再用备忘录/浏览器打开 `https://5min.chat` 测拉起。

## 说明

- 系统通知：首次开始计时时会申请通知授权；到期通过 `notificationManager.publish` 弹出本机通知（自定义 `alert.wav`）；并尝试 `reminderAgentManager`（`PUBLISH_AGENT_REMINDER`）在后台/冻后仍提醒。前台结束时另播放应用内报警音 + 振动（不依赖通知声道是否被静音）。
- 会话记录使用本地 RDB：`databaseDir/rdb/5min-chat/5min_chat_history.db`（近 14 日）；覆盖安装可保留。
- 仅在倒计时中保持屏幕常亮，降低待机耗电。
- 仅供习惯提醒；计时与统计原则上保存在本机。
