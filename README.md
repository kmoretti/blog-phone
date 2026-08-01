# blog-phone

一个用于个人日常使用的 Flutter 客户端，连接自建博客 API，方便在移动端和桌面端管理博客内容。

本项目主要服务于作者自己的使用场景。代码公开，欢迎参考、修改和按自己的需求继续开发，但不以通用产品、公共服务或开箱即用为目标。

## 项目定位

- 个人自用的博客客户端；
- 与自建博客 API 配套使用；
- 功能和界面会根据实际需求持续调整；
- 开源代码仅代表当前实现，不承诺兼容所有博客 API 部署环境。

## 当前功能

- 用户登录和会话保存；
- 动态浏览、发布、编辑和删除；
- 动态图片、视频附件上传；
- 本地存储和 OSS 上传链路；
- 动态媒体预览和互动；
- 友链查看、申请和管理员管理；
- 友链分组管理、友链分组迁移和多分组关联；
- RSS 内容查看和刷新；
- 图片资源管理；
- 服务地址和客户端设置管理；
- 响应式布局，支持移动端和 Windows 桌面端。

实际功能以当前代码和后端 API 为准。

## 技术栈

- Flutter / Dart；
- Riverpod 状态管理；
- Dio 网络请求；
- SQLite 本地数据存储；
- Secure Storage 会话和敏感配置存储；
- Android、Windows 等 Flutter 平台。

## 运行环境

建议使用与项目配置兼容的 Flutter SDK 和 Dart SDK。依赖版本以 `pubspec.yaml` 和 `pubspec.lock` 为准。

检查 Flutter 环境：

```bash
flutter doctor
```

## 本地运行

获取依赖：

```bash
flutter pub get
```

运行项目：

```bash
flutter run
```

运行指定平台时，可以使用 Flutter 当前环境支持的平台，例如：

```bash
flutter run -d windows
flutter run -d android
```

## 配置博客 API

启动应用后，在设置中填写博客 API 服务地址。客户端会根据该地址访问博客 API。

API 服务需要具备项目当前使用的认证、动态、资源上传、友链、RSS 和图片相关接口。后端接口不包含在本仓库中，接口行为以配套 API 项目的实际实现为准。

不要把真实服务地址、账号、Token、签名文件或其他敏感信息提交到仓库。

## 测试和检查

运行全部测试：

```bash
flutter test --no-pub
```

运行友链相关测试：

```bash
flutter test --no-pub test/features/friends
```

运行静态分析：

```bash
flutter analyze
```

检查差异中的空白错误：

```bash
git diff --check
```

## 目录结构

```text
lib/
├── core/           通用平台、存储和主题能力
├── data/           API、数据库和基础数据访问
├── features/       按业务拆分的页面、状态和数据层
├── presentation/   通用界面组件
└── state/          全局状态管理

test/               单元测试、API 测试和 Widget 测试
docs/               开发过程中的设计和实施记录
```

## 开发说明

项目会优先按照个人实际使用需求修改。修改功能时建议：

1. 先确认客户端调用的接口与后端 API 实现一致；
2. 遵循现有的 Flutter、Riverpod 和 Repository 分层；
3. 为 API 请求和关键页面行为补充测试；
4. 在提交前运行 `flutter test` 和 `flutter analyze`；
5. 不提交密钥、Token、签名文件或本地环境配置。

## 开源说明

本仓库公开代码，主要用于个人使用、学习和持续修改。

你可以基于代码进行修改和维护，但需要自行确认：

- 后端 API 是否可用；
- 本地 Flutter 环境是否兼容；
- 平台构建配置是否满足自己的设备要求；
- 修改后的功能是否符合自己的数据和安全需求。

本项目不提供公共在线服务，也不对第三方环境提供稳定性、兼容性或技术支持承诺。
