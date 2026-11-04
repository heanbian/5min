# 5min-android-app

如厕计时器 · 五分钟 — Android 原生客户端。

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

## 隐私

计时与统计仅存本机，无账号、无广告、不上传用户数据。本工具仅供习惯提醒，不构成医疗建议。
