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
