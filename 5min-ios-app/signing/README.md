# iOS 签名材料（本地）

将证书 / Profile / API Key 放在本目录下的 `material/`（已 gitignore）：

- Distribution 证书 `.p12`（若手动签名）
- Provisioning Profile `.mobileprovision`
- App Store Connect API Key `AuthKey_*.p8`（若 CLI 上传）

**推荐**：Xcode → Signing & Capabilities → 选择 Team → 勾选 Automatically manage signing。

打包前复制：

```bash
cp ExportOptions.plist.example ExportOptions.plist
# 编辑 teamID
```

勿将证书、描述文件、密码提交到 Git。
