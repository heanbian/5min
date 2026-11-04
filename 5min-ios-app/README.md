# 5min-ios-app

如厕计时器 · 五分钟 — iOS 原生客户端。

- **Bundle ID**：`chat.5min.app`
- **技术**：SwiftUI · UserNotifications · AVAudioEngine · Core Haptics（NotificationFeedback）
- **最低系统**：iOS 17

## 功能

- 时长预设 3 / 5 / 10 分钟与分组场景
- 绝对时间戳倒计时；到期本地通知 + 约 5 秒提示音与触觉
- 今日累计、多语言（含阿语 RTL）
- 计时中常亮（`isIdleTimerDisabled`）
- 结束后轻触表盘可再次提醒

## 打开工程

用 Xcode 15+ 打开 `FiveMin.xcodeproj`，选择模拟器或真机，设置你的 Development Team 后运行。

共享文案与场景：

```bash
cd ../5min-web && node scripts/export-shared.mjs
```

会同步到 `FiveMin/Resources/shared/`。

## 说明

- 杀进程后仍可靠提醒依赖**本地通知**；前台到期会播放约 5 秒声触。
- 本工具仅供习惯提醒，不构成医疗建议；数据仅存本机。
