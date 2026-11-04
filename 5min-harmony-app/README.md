# 5min-harmony-app

如厕计时器 · 五分钟 — HarmonyOS 原生客户端。

- **bundleName**：`chat.5min.app`
- **版本**：`AppScope/app.json5` → `versionName` / `versionCode`（与 Android `1.0.0` 对齐；`versionCode` 采用 `major*1000000+minor*1000+patch`）
- **技术**：ArkTS · ArkUI（Stage）· Preferences · Vibrator · Notification

## 功能

- 时长预设与分组场景（与 Web / Android 共享 `rawfile/shared`）
- 绝对时间戳倒计时；到期本地通知 + 约 5 秒振动
- 今日累计、多语言
- 计时页常亮（`setWindowKeepScreenOn`）

## 打开工程

使用 **DevEco Studio 26.0.0+** 打开本目录。

若提示「工程结构及配置需要升级」：`Tools` → `Migrate Assistant`，或确认已有 `hvigor/hvigor-config.json5`（`modelVersion: 26.0.0`）后 `File` → `Sync and Refresh Project`。

共享配置由 Web 子项目导出：

```bash
cd ../5min-web && node scripts/export-shared.mjs
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

1. 在 [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html) 创建应用（包名 `chat.5min.app`），申请发布证书 / Profile。
2. 将 `.p12` / `.cer` / `.p7b` 放到 `signing/material/`（已 gitignore）。
3. **在 DevEco 里配置签名（推荐）**  
   `File` → `Project Structure` → `Signing Configs` → 取消「Automatically generate signature」  
   填入 Store File / Cert / Profile / 密码 / Alias → `Apply`。  
   IDE 会把 `storePassword` / `keyPassword` **加密**写入 `build-profile.json5`（明文密码长度不足 32 会报 `00303116`）。
4. 可选：复制 `signing.properties.example` → `signing.properties` 仅作路径备忘；正式注入密码请用上一步 IDE，不要手写明文进 `build-profile.json5`。

> `signing.properties`、`signing/material/`、注入后的本地 `build-profile.json5` 密钥信息勿提交 Git。

## 打包正式版（HAP / APP）

1. **改版本号**（每次上架递增）  
   编辑 `AppScope/app.json5` → `versionName` / `versionCode`。

2. **出包**

```bash
chmod +x scripts/release.sh
./scripts/release.sh hap   # → store/release/5min-harmony-app-1.0.0.hap
./scripts/release.sh app   # → store/release/5min-harmony-app-1.0.0.app
```

也可在 DevEco：`Build` → `Build Hap(s)/APP(s)` → `Build App(s)`。

3. **上架**  
   AppGallery Connect 上传 APP/HAP，图标可用 `store/artwork/ic_launcher_512.png`。

## 说明

- 后台杀进程后的精确提醒可按目标 API 继续接入 ReminderAgent / 后台任务（当前版本以前台 ticker + 通知/振动为主）。
- 本工具仅供习惯提醒，不构成医疗建议；数据仅存本机。
