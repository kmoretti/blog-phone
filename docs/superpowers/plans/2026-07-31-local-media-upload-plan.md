# 本地图片视频上传实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 Flutter 动态编辑器参考网页端流程，将本地图片/视频先上传到 API 本地资源或 OSS，再保存动态媒体 URL。

**Architecture:** 在 `MomentsApi` 增加统一 multipart 上传接口，根据 `MomentUploadTarget` 选择 `/action/resource/local` 或 `/action/resource/oss`；编辑器只管理待上传文件和最终媒体条目，保存时先上传本地文件，再创建/更新动态。API 返回的本地相对路径保持原值提交，展示时由资源 URL 工具拼接服务器根地址；OSS 返回的完整 URL 直接使用。上传失败立即中止，不把手机本地绝对路径写入远端 payload。

**Tech Stack:** Flutter、Dart、Dio、file_picker、image_picker、flutter_test、现有 ApiClient/Riverpod。

---

### Task 1: 上传模型、multipart API 和资源 URL

**Files:**
- Create: `lib/features/moments/data/moment_upload.dart`
- Modify: `lib/features/moments/data/moments_api.dart`
- Create: `test/features/moments/moment_upload_test.dart`

- [ ] **Step 1: Write failing upload-model tests**

覆盖：上传目标、扩展名、大小限制、资源路径解析。

```dart
expect(MomentUploadTarget.local.endpoint, 'action/resource/local');
expect(MomentUploadTarget.oss.endpoint, 'action/resource/oss');
expect(validateMomentUploadFile('photo.jpg', 64 * 1024 * 1024), isNull);
expect(validateMomentUploadFile('clip.mov', 1), isNotNull);
expect(validateMomentUploadFile('clip.mp4', 65 * 1024 * 1024 + 1), isNotNull);
expect(resolveMomentMediaUrl('https://host/api', '/moments/a.jpg'), 'https://host/moments/a.jpg');
```

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/features/moments/moment_upload_test.dart`
Expected: FAIL because upload model and helpers do not exist.

- [ ] **Step 3: Implement upload model and validation**

定义：

- `enum MomentUploadTarget { local, oss }`；
- `MomentUploadResult { url, isLocal, objectKey }`；
- 图片白名单 `png/jpg/jpeg/gif/webp`；视频白名单 `mp4/webm`；
- 单文件最大 `65 * 1024 * 1024` 字节；
- `validateMomentUploadFile(path, size)` 返回用户可见错误文本或 `null`；
- `resolveMomentMediaUrl(apiBaseUrl, mediaUrl)` 去除 `/api` 后拼接相对资源路径，完整 HTTP(S) URL 原样返回。

- [ ] **Step 4: Add API multipart upload method**

在 `MomentsApi` 增加：

```dart
Future<MomentUploadResult> uploadMomentMedia({
  required String filePath,
  required MomentUploadTarget target,
  required String uploadPath,
})
```

用 `MultipartFile.fromFile(filePath, filename: basename(filePath))` 构造 `FormData`，字段为 `file`、`path`、`overwrite: 'false'`，调用对应 endpoint。解析 `response.data.url`；local 返回 `isLocal: true`，oss 返回 `isLocal: false` 并保留 `objectKey`。

- [ ] **Step 5: Add adapter/API tests**

使用现有 Dio adapter 验证：

- local 请求路径为 `action/resource/local`；
- OSS 请求路径为 `action/resource/oss`；
- multipart 字段包含 `file`、`path` 和 `overwrite=false`；
- local/OSS 响应 URL 解析正确。

- [ ] **Step 6: Run focused tests**

Run: `flutter test test/features/moments/moment_upload_test.dart`
Expected: PASS。

### Task 2: 编辑器上传方式和新建动态流程

**Files:**
- Modify: `lib/features/moments/presentation/moment_editor_screen.dart`
- Modify: `test/features/moments/moment_editor_task2_test.dart`

- [ ] **Step 1: Write failing editor-flow tests**

验证：

- 编辑器显示本地资源/OSS 选择；
- 新建动态保存时先上传本地文件，再调用创建动态；
- 创建 payload 使用服务器 URL，不含客户端绝对路径；
- OSS 结果为 `is_local: 0`，local 结果为 `is_local: 1`；
- 上传失败时不调用创建接口且保留待上传条目。

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/features/moments/moment_editor_task2_test.dart`
Expected: FAIL because editor currently passes local paths directly and repository rejects local media。

- [ ] **Step 3: Add upload target state and UI**

在媒体操作区域增加 `SegmentedButton<MomentUploadTarget>`，标签为“本地资源”和“OSS”，默认 `local`。选择文件后继续显示文件名和类型，不立即上传；文件扩展名和大小错误立即显示 SnackBar 并不加入列表。

- [ ] **Step 4: Upload before creating a new moment**

在 `_submit()` 中：

1. 校验 Extension；
2. 校验所有待上传文件；
3. 按顺序调用 `MomentsApi.uploadMomentMedia`；
4. 将结果转换为 `CreateMediaPayload(mediaUrl: result.url, mediaType: ..., isLocal: result.isLocal ? 1 : 0)`；
5. 与外链媒体合并；
6. 调用 repository 创建动态。

上传任何文件失败时停止，不调用 create，不保存客户端路径，保留待上传文件供重试。

- [ ] **Step 5: Preserve loading and error behavior**

上传和创建期间复用现有 `isSaving`，禁用保存和上传控件；捕获 `ApiException` 与通用异常，显示错误 SnackBar；成功后才关闭编辑页。

- [ ] **Step 6: Run focused tests**

Run: `flutter test test/features/moments/moment_editor_task2_test.dart`
Expected: PASS。

### Task 3: 编辑已有动态的新本地媒体流程

**Files:**
- Modify: `lib/features/moments/presentation/moment_editor_screen.dart`
- Modify: `test/features/moments/moment_editor_task2_test.dart`

- [ ] **Step 1: Write failing edit-flow tests**

验证已有动态保存时：

- 先更新动态字段；
- 上传新增本地媒体；
- 对每个上传结果调用 `createMedia(moment.id, payload)`；
- 删除指定已有媒体；
- 新增外链媒体仍按现有流程处理；
- 上传失败时不调用 `createMedia`，删除状态可重试。

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/features/moments/moment_editor_task2_test.dart`
Expected: FAIL because current edit path only creates external media and ignores local file paths.

- [ ] **Step 3: Implement edit upload sequence**

在已有动态分支中先上传 `paths`，按结果调用 `createMedia`；上传结果的 `isLocal` 由目标决定。只有动态更新和媒体操作全部成功后关闭页面；失败时保留待处理条目。

- [ ] **Step 4: Run focused tests**

Run: `flutter test test/features/moments/moment_editor_task2_test.dart`
Expected: PASS。

### Task 4: API 配置可用性和回归验证

**Files:**
- Modify: `lib/features/moments/data/moment_upload.dart` only if validation/API-base edge cases require it.
- Modify: `test/features/moments/moment_upload_test.dart`.

- [ ] **Step 1: Add OSS failure and path tests**

验证 OSS 未启用返回的错误能显示给用户；验证 `/api`、末尾斜杠、完整 URL 三种 API base 形式不会生成 `/api/moments/...` 错误资源地址。

- [ ] **Step 2: Run all dynamic tests**

Run: `flutter test test/features/moments test/moments_test.dart test/moments_widgets_test.dart`
Expected: All dynamic tests pass。

- [ ] **Step 3: Run project checks**

Run: `flutter analyze` and `git diff --check`
Expected: analyzer has no issues and diff check passes。

- [ ] **Step 4: Run full regression**

Run: `flutter test`
Expected: All existing and new tests pass。

- [ ] **Step 5: Commit only after explicit push request**

Commit message: `feat: upload local moment media to server`
