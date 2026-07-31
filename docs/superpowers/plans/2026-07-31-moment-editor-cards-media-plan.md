# 动态编辑器卡片与外链媒体实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Flutter 动态编辑器补齐为网页端同等的五类卡片选择器，并增加外链图片/视频 URL 添加能力。

**Architecture:** 保持 `MomentEditorScreen` 作为页面容器，将卡片 JSON 生成和外链媒体 payload 构造提取为纯 Dart 辅助模型，便于单元测试；页面负责选择类型、填写字段、回填已有 JSON、管理媒体列表。未知 Extension JSON 使用高级编辑入口保留，不会被选择器覆盖。

**Tech Stack:** Flutter、Dart、flutter_riverpod、flutter_test、url_launcher 既有 URL 规则。

---

### Task 1: 卡片模型、选择器和 JSON 生成

**Files:**
- Create: `lib/features/moments/presentation/moment_extension_editor.dart`
- Create: `test/features/moments/moment_extension_editor_test.dart`
- Modify: `lib/features/moments/presentation/moment_editor_screen.dart`

- [ ] **Step 1: Write failing pure-model tests**

测试五类卡片字段生成：

```dart
expect(buildMomentExtensionJson(type: 'github', values: {'repo_url': 'https://github.com/u/r'}), '{"type":"github","payload":{"repo_url":"https://github.com/u/r"}}');
expect(buildMomentExtensionJson(type: 'website', values: {'title': '站点', 'site': 'https://example.com'}), contains('website'));
expect(buildMomentExtensionJson(type: 'location', values: {'placeholder': '北京', 'latitude': 39.9, 'longitude': 116.4}), contains('location'));
expect(buildMomentExtensionJson(type: 'music', values: {'url': 'https://music.example/a'}), contains('music'));
expect(buildMomentExtensionJson(type: 'tweet', values: {'url': 'https://x.com/u/status/1', 'username': 'u', 'status_id': '1'}), contains('tweet'));
```

同时测试缺少必填字段、非 HTTP(S) URL 和非法坐标返回校验错误；测试已有 JSON 可解析出类型和字段。

- [ ] **Step 2: Run tests and verify failure**

Run: `flutter test test/features/moments/moment_extension_editor_test.dart`
Expected: FAIL because the editor model does not exist.

- [ ] **Step 3: Implement the pure editor model**

定义 `MomentExtensionDraft`，提供：

- `fromJsonString(String?)`：读取已知类型，未知或非法 JSON 标记为 advanced/raw 模式；
- `toJsonString()`：生成与网页端一致的 `{type, payload}`；
- `validate()`：校验必填字段、HTTP(S) URL、位置纬度 `[-90,90]`、经度 `[-180,180]`；
- `buildMomentExtensionJson(...)`：供测试和页面使用的纯函数。

所有链接必须通过 `Uri.tryParse`、scheme 和 host 检查；不要将任意字符串交给外链打开或 payload 提交。

- [ ] **Step 4: Add the Flutter card selector widget**

在 `moment_extension_editor.dart` 增加 `MomentExtensionEditor`，提供“添加卡片”下拉选项：GitHub 仓库、网站链接、位置、音乐、推文。选择后显示对应输入字段和“保存卡片/取消”按钮；已有 JSON 初始化时自动回填。未知类型显示高级 JSON 文本框和保留原文提示。

- [ ] **Step 5: Replace the raw Extension field in the screen**

将 `moment_editor_screen.dart` 中单独的 Extension `TextField` 替换为 `MomentExtensionEditor`；编辑卡片后同步 `extensionController.text`，高级 JSON 也同步到控制器；保存前校验并显示错误，不覆盖未知 JSON。

- [ ] **Step 6: Run focused tests**

Run: `flutter test test/features/moments/moment_extension_editor_test.dart test/features/moments/moment_extension_test.dart`
Expected: PASS。

### Task 2: 外链图片/视频模型和媒体管理

**Files:**
- Create: `test/features/moments/moment_external_media_test.dart`
- Modify: `lib/features/moments/presentation/moment_editor_screen.dart`
- Modify: `lib/features/moments/data/moments_api.dart`

- [ ] **Step 1: Write failing media payload tests**

验证：

```dart
final image = buildExternalMediaPayload('https://cdn.example/image.jpg', 'image');
expect(image.toJson(), {'media_url': 'https://cdn.example/image.jpg', 'media_type': 'image', 'is_local': 0});
final video = buildExternalMediaPayload('https://cdn.example/video.mp4', 'video');
expect(video.toJson()['media_type'], 'video');
expect(() => buildExternalMediaPayload('javascript:alert(1)', 'image'), throwsFormatException);
```

同时验证已有媒体可以转换为编辑器条目并被删除，不影响其他媒体。

- [ ] **Step 2: Run tests and verify failure**

Run: `flutter test test/features/moments/moment_external_media_test.dart`
Expected: FAIL because external media helper and editor entries do not exist。

- [ ] **Step 3: Implement external media helper**

增加 `buildExternalMediaPayload(String url, String mediaType)`，只接受 `image`/`video` 和合法 HTTP(S) URL，返回 `CreateMediaPayload` 且 `isLocal` 固定为 `0`。保留媒体名称可选，不把 URL 当作本地路径。

- [ ] **Step 4: Add external media dialog and list**

在编辑器媒体区域增加“外链图片”和“外链视频”按钮。弹窗输入 URL，提交前调用 helper 校验；成功后加入媒体条目列表。显示现有媒体和待提交媒体，支持移除待提交媒体；编辑已有动态时，已有服务端媒体删除调用 `deleteMedia`，新增外链媒体在动态保存成功后调用 `createMedia`。

- [ ] **Step 5: Ensure local media behavior remains unchanged**

本地选择的媒体继续保持 `isLocal: 1`，当前 repository 的草稿策略不改；外链媒体不触发本地媒体草稿判断。

- [ ] **Step 6: Run focused tests**

Run: `flutter test test/features/moments/moment_external_media_test.dart test/moments_widgets_test.dart`
Expected: PASS。

### Task 3: 集成验证和发布

**Files:**
- Modify only files from Task 1 and Task 2 as needed.

- [ ] **Step 1: Run all Flutter tests**

Run: `flutter test`
Expected: All tests pass。

- [ ] **Step 2: Run analyzer and diff checks**

Run: `flutter analyze` and `git diff --check`
Expected: No analyzer issues and no whitespace errors。

- [ ] **Step 3: Verify editor acceptance criteria**

确认发布页面包含：卡片类型选择器、对应字段表单、高级 JSON 保留入口、外链图片按钮、外链视频按钮；确认生成 JSON 与后端 `extension` 协议一致，外链媒体 `is_local` 为 `0`。

- [ ] **Step 4: Commit and push only after user request**

本计划不自动提交。若用户明确要求推送，使用独立提交说明：`feat: add moment card and external media editor`。
