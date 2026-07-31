# Blog 内容功能完善实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完善 blog-api Flutter 客户端的动态、友链和 RSS 功能，使其与现有后端字段和交互能力一致。

**Architecture:** 保持现有 Riverpod、Repository、DTO 和页面结构。动态扩展解析独立为纯 Dart 模型/渲染组件；友链表单直接复用现有 API DTO 并补齐字段；RSS 页面增加本地分页状态、日期格式化和外链跳转，不改变后端接口。

**Tech Stack:** Flutter、Dart、flutter_riverpod、flutter_markdown、url_launcher、flutter_test。

---

### Task 1: 动态扩展协议与 Markdown 渲染

**Files:**
- Create: `lib/features/moments/presentation/moment_extension.dart`
- Create: `test/features/moments/moment_extension_test.dart`
- Modify: `lib/features/moments/presentation/moments_screen.dart`
- Modify: `lib/features/moments/presentation/moment_detail_screen.dart`

- [ ] **Step 1: Write failing tests for extension parsing**

覆盖 `github`、`website`、`location`、`music`、`tweet` JSON 字符串，验证类型、标题、链接和 payload 字段能够安全解析；空字符串、非法 JSON 和未知类型返回 Unknown。

- [ ] **Step 2: Run the targeted test and verify failure**

Run: `flutter test test/features/moments/moment_extension_test.dart`
Expected: FAIL because the extension parser does not exist.

- [ ] **Step 3: Implement the pure extension model and parser**

定义 `MomentExtension`，包含 `type`、`payload`、`isKnown` 和 `fromJsonString`。解析必须捕获 JSON 格式错误，所有 payload 值转成安全可读取的 Map；未知类型保留原始 payload。

- [ ] **Step 4: Add reusable extension cards**

在同一文件增加 `MomentExtensionCard`，按类型显示图标、标题、描述和可点击 URL：GitHub 显示仓库地址，website 显示网站标题/地址，location 显示地点信息，music 显示歌曲/艺术家，tweet 显示推文文本/链接。仅对合法 HTTP(S) 地址调用 `url_launcher`。

- [ ] **Step 5: Replace plain moment text with Markdown and extension rendering**

使用已有 `MarkdownBody` 渲染正文；在动态列表卡片和详情页显示标签、置顶、广告标记、扩展卡片和 message link。移除 `CircleAvatar`，保留时间和管理员编辑入口。

- [ ] **Step 6: Run targeted tests and analyzer**

Run: `flutter test test/features/moments/moment_extension_test.dart && flutter analyze`
Expected: targeted tests pass and analyzer has no new errors.

### Task 2: 动态编辑字段

**Files:**
- Create: `test/features/moments/moment_editor_payload_test.dart`
- Modify: `lib/features/moments/presentation/moment_editor_screen.dart`
- Modify: `lib/features/moments/data/moments_api.dart`

- [ ] **Step 1: Write failing payload tests**

验证新增和更新 payload 正确传递 `tags`、`pinned_order`、`is_ad`、`extension`、`message_link`，并保持空可选字段不发送。

- [ ] **Step 2: Run test and verify failure**

Run: `flutter test test/features/moments/moment_editor_payload_test.dart`
Expected: FAIL for missing editor state or serialization expectations.

- [ ] **Step 3: Add editor controllers and controls**

新增标签、置顶顺序、广告开关、扩展 JSON、来源链接输入；编辑时从 `MomentDto` 初始化；提交时构造完整的 `CreateMomentPayload` 或 `UpdateMomentPayload`。数值字段对非法输入显示表单错误，不发送非法整数。

- [ ] **Step 4: Run targeted tests**

Run: `flutter test test/features/moments/moment_editor_payload_test.dart`
Expected: PASS.

### Task 3: 友链 DTO、表单和审核状态

**Files:**
- Modify: `lib/features/friends/data/friend_links_api.dart`
- Modify: `lib/features/friends/presentation/friend_links_screen.dart`
- Create: `test/features/friends/friend_link_payload_test.dart`

- [ ] **Step 1: Inspect existing DTO and write failing field coverage tests**

测试新增/更新 payload 支持后端字段：`name`、`link`、`avatar`、`description`、`email`、`enable_rss`、`skip_health_check`、`friend_link_page`、`feed`、`color`、`rss`、`tags`、`status`、`rejection_reason`。

- [ ] **Step 2: Run targeted test and verify failure**

Run: `flutter test test/features/friends/friend_link_payload_test.dart`
Expected: FAIL because current form only serializes name and link.

- [ ] **Step 3: Extend DTO serialization and form fields**

为新增/编辑弹窗增加可滚动表单，补齐文本、开关、标签和状态控件；编辑管理员记录时显示审核状态和拒绝原因。保留现有公开列表字段展示和外链打开行为。

- [ ] **Step 4: Add approval side-effect verification coverage**

增加 API/repository 测试，验证审核请求使用 `PUT api/action/friend/:id` 并发送 `status`、`rejection_reason`。在页面保存后刷新当前查询，确保审核结果立即可见。

- [ ] **Step 5: Run friend-link tests and analyzer**

Run: `flutter test test/features/friends/friend_link_payload_test.dart && flutter analyze`
Expected: PASS with no new analyzer errors.

### Task 4: RSS 分页、日期和文章跳转

**Files:**
- Modify: `lib/features/rss/presentation/rss_screen.dart`
- Create: `test/features/rss/rss_presentation_test.dart`

- [ ] **Step 1: Write failing presentation helper tests**

验证 Unix 秒时间戳格式化为本地日期时间；验证下一页仅在 `page * pageSize < total` 时可用；验证文章 URL 传递给外部打开操作。

- [ ] **Step 2: Run test and verify failure**

Run: `flutter test test/features/rss/rss_presentation_test.dart`
Expected: FAIL because pagination and formatting helpers do not exist.

- [ ] **Step 3: Add page state and pagination controls**

将 RSS 页面改为 `ConsumerStatefulWidget`，维护选中 feed、当前页和 page size；列表底部增加上一页/下一页，刷新时重置页码；feed 底部弹窗同样显示分页控制。

- [ ] **Step 4: Display dates and make articles clickable**

使用 `intl` 将 `post.time` 显示为本地日期时间；给文章 `ListTile` 增加 `onTap`，仅对合法 HTTP(S) URL 调用 `launchUrl`，失败时显示 SnackBar。

- [ ] **Step 5: Run RSS tests and analyzer**

Run: `flutter test test/features/rss/rss_presentation_test.dart && flutter analyze`
Expected: PASS with no new analyzer errors.

### Task 5: 全量验证与发布检查

**Files:**
- No new files expected.
- Inspect: `pubspec.yaml`, `.github/workflows/build.yml`, `android/app/build.gradle.kts`, `android/key.properties`.

- [ ] **Step 1: Run all Flutter tests**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`
Expected: No errors or warnings introduced by these changes.

- [ ] **Step 3: Verify release-sensitive configuration**

确认 `applicationId` 仍为 `com.example.blog_phone`，版本仍为 `1.1.0+2`，产品名仍为 `blog-api`，本地 keystore 和密码文件未被 Git 跟踪。

- [ ] **Step 4: Run available platform builds**

Run: `flutter build apk --release` and `flutter build windows --release` where the local environment permits. If dependency TLS prevents local APK download, rely on the already successful GitHub Actions workflow and report the local limitation precisely.

- [ ] **Step 5: Review diff without committing automatically**

Run: `git status --short` and `git diff --check`. Do not commit or push unless the user explicitly requests it.
