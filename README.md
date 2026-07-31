# blog-phone

blog-phone 是 Blog API 的 Flutter 移动端客户端，使用 Flutter 和 Riverpod 构建。

## 开发

在项目目录执行：

```bash
flutter pub get
flutter run
```

## 验证

```bash
flutter analyze
flutter test
```

## GitHub Actions 构建

推送到 `main` 或 `feat/**` 分支、创建 Pull Request，或在 Actions 页面手动运行 `Build blog-phone`，都会执行静态分析和测试，并构建：

- Android release APK：`blog-phone-android-apk`
- Windows release 压缩包：`blog-phone-windows`

构建结果可在对应的 GitHub Actions 运行记录的 Artifacts 中下载。

### Android 签名 Secrets

Android release 构建使用 formal signing。仓库管理员需要在 GitHub 仓库的 Settings → Secrets and variables → Actions 中配置以下 Secrets：

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

`ANDROID_KEYSTORE_BASE64` 是 release keystore 的 Base64 编码。请在仓库根目录执行以下 PowerShell 命令生成编码值，然后将输出直接保存为 GitHub Secret，不要写入 README 或任何受版本控制的文件：

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('E:/kmoretti-github/blog_api/secrets/blog-api-release.jks'))
```

本地 Android 签名配置应保存在被忽略的 `android/key.properties` 中，keystore 和密码文件应放在 Git 仓库之外。CI 会在构建前重建临时签名文件，并在构建结束后清理。
