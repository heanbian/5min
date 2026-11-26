# 5min-android-app

**如厕计时器** — Android 原生客户端。运营方：学记宝。官网：https://5min.chat。

- **applicationId / 源码包名**：`chat.fivemin.app`
 （Android 包名每一段不能以数字开头，故不能用 `chat.5min.app`；与 iOS/鸿蒙品牌 ID 对应关系见根 README）
- **技术**：Kotlin · Jetpack Compose · Foreground Service · Exact Alarm

## 功能

与鸿蒙端一致的产品壳：

- 底部三 Tab：记录 / 首页 / 我的
- 首页倒计时（预设 3 / 5 / 10、分组场景）；喇叭入口进「我的」
- 绝对时间戳倒计时；前台服务 + 精确闹钟到期提醒
- 到期通知 / 振动 / 提示音；环境音选「关闭」则静音（仍可振动与横幅）
- 记录：近 14 日本地 SQLite（`files/5min-chat/5min_chat_history.db`），三行展示，升级可查
- 我的：语言（简体中文、繁体中文、English、Deutsch、Español、Français、Bahasa Indonesia、日本語、한국어、Português、Русский、العربية、བོད་ཡིག）、提示音、默认时长、反馈 / 隐私 / 条款 / 关于 / 软件更新（拉取 `https://5min.chat/app/android-latest.json`）
- 首次启动隐私同意门；计时中常亮（`FLAG_KEEP_SCREEN_ON`）

## 打开工程

使用 Android Studio (Ladybug+) 打开本目录，同步 Gradle 后运行 `app`。

共享文案与场景由 Web 子项目导出（会同步到本目录 `assets/shared`）：

```bash
cd ../5min-web && npm run export-shared
# 文案源：public/js/i18n/locales.js
```

## 打包正式版（AAB / APK）

1. **改版本号**（每次上架递增 `versionCode`）
 编辑 `app/build.gradle.kts` → `versionCode` / `versionName`。

2. **生成上传密钥**（仅首次；务必备份 `.jks`）

```bash
mkdir -p keystore
keytool -genkeypair -v \
 -keystore keystore/5min-upload.jks \
 -alias 5min \
 -keyalg RSA -keysize 2048 -validity 10000 \
 -storepass '你的密码' -keypass '你的密码' \
 -dname "CN=5min, OU=5min, O=XueJiBao, L=Beijing, ST=Beijing, C=CN"
```

3. **配置签名**
 复制 `keystore.properties.example` → `keystore.properties`，填入路径与密码。

4. **出包（必须用 JDK 17/21，不要用 JDK 25）**

终端若默认是 Java 25，直接 `./gradlew` 会报错 `25.0.x`。请用脚本或先切 JDK：

```bash
# 推荐：自动选用 JDK 21 / Android Studio JBR
chmod +x scripts/release.sh
./scripts/release.sh apk # → app/build/outputs/apk/release/5min-android-app-1.0.17.apk
./scripts/release.sh bundle # → app/build/outputs/bundle/release/5min-android-app-1.0.17.aab

# 或手动：
export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home
./gradlew :app:assembleRelease
./gradlew :app:bundleRelease
```

5. **上架 Play Console**
 创建应用 → 应用 ID `chat.fivemin.app` → 上传 AAB → 填写商店文案与图标（可用 `store/artwork/ic_launcher_512.png`）→ 提交审核。
 正式发布前在「应用内容」中声明前台服务（specialUse / 计时提醒）与通知用途。

> `keystore/` 与 `keystore.properties` 已忽略，勿提交到 Git。密钥丢失将无法更新同一应用。
> 商店截图放 `store/artwork/screenshots/`（已 gitignore）；可用 `scripts/capture_store_screenshots.sh` 本地生成。

## 隐私

计时与统计默认保存在本机；不要求注册账户。可选云端同步需用户主动开启，数据存放于中国境内。本工具仅供习惯提醒。
