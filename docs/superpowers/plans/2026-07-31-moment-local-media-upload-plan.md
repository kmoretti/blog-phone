# 动态本地媒体上传实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 Flutter 动态编辑器按 API 网页端流程上传本地图片/视频，支持本地资源和 OSS 两种目标，并在动态发布前使用服务器 URL。

**Architecture:** 新增独立的 `MomentMediaUploadApi`，只负责 multipart 上传和响应解析；编辑器通过 `MomentUploadTarget` 选择 local/OSS，上传成功后生成 `CreateMediaPayload`。新建动态先上传全部本地媒体再创建动态，编辑动态先更新字段再上传新增媒体并调用 `createMedia`；任何失败都不提交客户端绝对路径。

**Tech Stack:** Flutter、Dart、Dio、flutter_test、file_picker、image_picker、现有 ApiClient/JWT 注入。

---

### Task 1: 上传模型、校验和 API multipart 请求

**Files:**
- Create: `lib/features/moments/data/moment_media_upload_api.dart`
- Create: `test/features/moments/moment_media_upload_api_test.dart`
- Modify: `lib/features/moments/data/moments_api.dart` only if shared payload constructors need extraction

- [ ] **Step 1: Write failing tests**

覆盖：

```dart
expect(MomentUploadTarget.local.endpoint, 'action/resource/local');
expect(MomentUploadTarget.oss.endpoint, 'action/resource/oss');
expect(validateMomentMediaFile('photo.jpg', 1024), isNull);
expect(validateMomentMediaFile('clip.mp4', 1024), isNull);
expect(validateMomentMediaFile('clip.mov', 1024), isNotNull);
expect(validateMomentMediaFile('photo.jpg', 65 * 1024 * 1024 + 1), isNotNull);
```

使用 Dio adapter 断言上传请求：

- method 为 POST；
- path 为 `action/resource/local` 或 `action/resource/oss`；
- body 是 `FormData`；
- 包含 `file`、`path`、`overwrite`；
- `path` 格式为 `moments/YYMMDD`；
- 成功响应解析 `data.url`，本地 `isLocal=true`，OSS `isLocal=false`，并保留 `objectKey`。

- [ ] **Step 2: Run tests and verify failure**

Run: `flutter test test/features/moments/moment_media_upload_api_test.dart`
Expected: FAIL because upload API/model/helper does not exist.

- [ ] **Step 3: Implement upload API**

定义：

```dart
enum MomentUploadTarget { local, oss }

class MomentUploadResult {
  const MomentUploadResult({required this.url, required this.isLocal, this.objectKey});
  final String url;
  final bool isLocal;
  final String? objectKey;
}
```

实现：

- 允许图片 `png/jpg/jpeg/gif/webp`；视频 `mp4/webm`；大小不超过 `65 * 1024 * 1024`；
- 使用 `MultipartFile.fromFile(filePath, filename: basename(filePath))`；
- `FormData.fromMap({'file': file, 'path': 'moments/${DateFormat('yyMMdd').format(DateTime.now())}', 'overwrite': 'false'})`；
- local 请求 `action/resource/local`，OSS 请求 `action/resource/oss`；
- 读取 `response.data['data']['url']`；没有 URL 或返回错误时抛出用户可理解的 `ApiException`；
- 不记录文件内容、JWT 或敏感响应。

- [ ] **Step 4: Run API tests**

Run: `flutter test test/features/moments/moment_media_upload_api_test.dart`
Expected: PASS。

### Task 2: 编辑器上传目标和发布流程

**Files:**
- Modify: `lib/features/moments/presentation/moment_editor_screen.dart`
- Modify: `lib/features/moments/data/moments_repository.dart` only to remove the pre-upload local-media rejection after all payloads use server URLs
- Create: `test/features/moments/moment_local_upload_flow_test.dart`

- [ ] **Step 1: Write failing flow tests**

验证新建动态：

1. 文件选择结果进入待上传列表；
2. 保存时先调用 local/OSS upload；
3. `CreateMomentPayload.media` 使用上传返回的 URL；
4. `is_local` 分别为 `1`/`0`；
5. API create 请求不包含客户端本地路径；
6. 上传失败时不调用 create，媒体仍可重试。

验证编辑动态：

1. update 先执行；
2. 新增本地文件先上传；
3. 上传返回 URL 后调用 `createMedia`；
4. 删除已有媒体仍调用 `deleteMedia`；
5. 上传失败显示错误且不创建带本地路径的媒体。

- [ ] **Step 2: Run flow tests and verify failure**

Run: `flutter test test/features/moments/moment_local_upload_flow_test.dart`
Expected: FAIL because editor still passes local paths and repository rejects `is_local == 1`.

- [ ] **Step 3: Implement target selector and upload orchestration**

在媒体操作区域增加 local/OSS 选择控件，默认 local。为待上传文件保留 `filePath` 和媒体类型，不提前构造 `is_local=1` 的远端 payload。

新建流程：

```text
validate extension
→ upload every local file with selected target
→ convert each result to CreateMediaPayload(url, type, isLocal ? 1 : 0)
→ append external media
→ repository.save(CreateMomentPayload)
```

编辑流程：

```text
update moment fields
→ upload every new local file
→ createMedia(moment.id, uploaded payload)
→ createMedia for new external media
→ deleteMedia for removed existing media
```

上传失败时停止后续流程，显示错误，保留文件条目和目标选择，禁止提交本地绝对路径。

- [ ] **Step 4: Remove obsolete repository rejection**

`MomentsRepository.save` 不再因为 `isLocal == 1` 拒绝 payload；仅当媒体 URL 仍是客户端路径时在编辑器上传阶段阻止提交。保留草稿机制用于网络/API失败，但草稿中不能写入未上传本地路径。

- [ ] **Step