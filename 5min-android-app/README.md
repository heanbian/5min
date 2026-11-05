# 5min-android-app

**如厕计时器** — Android 原生客户端。

- **applicationId / 源码包名**：`chat.fivemin.app`  
  （Android 包名每一段不能以数字开头，故不能用 `chat.5min.app`；与 iOS/鸿蒙品牌 ID 对应关系见根 README）
- **技术**：Kotlin · Jetpack Compose · Foreground Service · Exact Alarm

## 功能

- 时长预设 3 / 5 / 10 分钟与分组场景
- 绝对时间戳倒计时；前台服务 + 精确闹钟到期提醒
- 到期通知、约 5 秒振动与提示音
- 今日累计、多语言、环境音偏好（本地存储）
- 计时页常亮（`keepScreenOn`）

## 打开工程

使用 Android Studio (Ladybug+) 打开本目录，同步 Gradle 后运行 `app`。

共享文案与场景由 Web 子项目导出（会同步到本目录 `assets/shared`）：

```bash
cd ../5min-web && node scripts/export-shared.mjs
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
./scripts/release.sh apk      # → app/build/outputs/apk/release/5min-android-app-1.0.0.apk
./scripts/release.sh bundle   # → app/build/outputs/bundle/release/5min-android-app-1.0.0.aab

# 或手动：
export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home
./gradlew :app:assembleRelease
./gradlew :app:bundleRelease
```

5. **上架 Play Console**  
   创建应用 → 应用 ID `chat.fivemin.app` → 上传 AAB → 填写商店文案与图标（可用 `store/artwork/ic_launcher_512.png`）→ 提交审核。  
   正式发布前在「应用内容」中声明前台服务（specialUse / 计时提醒）与通知用途。

> `keystore/` 与 `keystore.properties` 已忽略，勿提交到 Git。密钥丢失将无法更新同一应用。

## 隐私

计时与统计仅存本机，无账号、无广告、不上传用户数据。本工具仅供习惯提醒，不构成医疗建议。
