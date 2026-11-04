# 5min-harmony-app

如厕计时器 · 五分钟 — HarmonyOS NEXT 原生客户端。

- **bundleName**：`chat.5min.app`
- **技术**：ArkTS · ArkUI（Stage）· Preferences · Vibrator · Notification

## 功能

- 时长预设与分组场景（与 Web / Android 共享 `rawfile/shared`）
- 绝对时间戳倒计时；到期本地通知 + 约 5 秒振动
- 今日累计、多语言
- 计时页常亮（`setWindowKeepScreenOn`）

## 打开工程

使用 DevEco Studio（配套 HarmonyOS NEXT SDK / API 12+）打开本目录，同步依赖后运行 `entry`。

共享配置由 Web 子项目导出：

```bash
cd ../5min-web && node scripts/export-shared.mjs
```

## 说明

- 后台杀进程后的精确提醒可按目标 API 继续接入 ReminderAgent / 后台任务（当前版本以前台 ticker + 通知/振动为主）。
- 本工具仅供习惯提醒，不构成医疗建议；数据仅存本机。
