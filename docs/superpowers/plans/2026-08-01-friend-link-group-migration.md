# 友链分组迁移实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在管理员分组管理弹窗中接入已有 `POST /api/action/friend/group/migrate`，支持确认、执行、反馈和刷新。

**Architecture:** 沿用 `FriendLinksApi -> FriendLinksRepository -> FriendLinksScreen`，API 层只负责请求已有迁移接口，Repository 负责缓存失效，分组管理弹窗负责确认、加载状态和结果提示。客户端不复制后端迁移逻辑，不新增路由。

**Tech Stack:** Flutter、Dart、Riverpod、Dio、Flutter test。

---

## 文件结构

- Modify: `E:\kmoretti-github\blog_api\blog-phone\lib\features\friends\data\friend_links_api.dart` — 增加迁移 API 方法。
- Modify: `E:\kmoretti-github\blog_api\blog-phone\lib\features\friends\data\friend_links_repository.dart` — 增加迁移委托和缓存清理。
- Modify: `E:\kmoretti-github\blog_api\blog-phone\lib\features\friends\presentation\friend_links_screen.dart` — 增加迁移按钮、确认弹窗、执行状态和提示。
- Modify: `E:\kmoretti-github\blog_api\blog-phone\test\features\friends\friend_links_test.dart` — 增加迁移 API 契约测试。
- Modify or create: `E:\kmoretti-github\blog_api\blog-phone\test\features\friends\friend_links_screen_test.dart` — 增加迁移页面行为测试，遵循现有测试结构。

---

### Task 1: 增加迁移 API 契约

**Files:**
- Modify: `lib/features/friends/data/friend_links_api.dart`
- Modify: `test/features/friends/friend_links_test.dart`

- [ ] **Step 1: 写失败测试**

使用现有 `FriendAdapter` 验证：

```dart
test('migrates existing friend links through the backend endpoint', () async {
  final adapter = FriendAdapter(
    '{"code":200,"data":{"message":"migration completed"}}',
  );
  final api = FriendLinksApi(
    ApiClient(
      baseUrl: 'https://api.test',
      store: MemorySecureStore({'jwt': 'token'}),
      dio: Dio()..httpClientAdapter = adapter,
    ),
  );

  await api.migrateGroups();

  expect(adapter.request?.method, 'POST');
  expect(
    adapter.request?.uri.toString(),
    'https://api.test/api/action/friend/group/migrate',
  );
  expect(adapter.request?.data, isNull);
});
```

- [ ] **Step 2: 运行测试确认失败**

```powershell
flutter test --no-pub test/features/friends/friend_links_test.dart
```

Expected: FAIL，因为 `migrateGroups` 尚未定义。

- [ ] **Step 3: 实现 API 方法**

在 `FriendLinksApi` 中增加：

```dart
Future<void> migrateGroups() async {
  await client.post('action/friend/group/migrate');
}
```

不添加请求体，不新增参数，不读取或生成默认分组 ID。

- [ ] **Step 4: 运行测试确认通过**

```powershell
flutter test --no-pub test/features/friends/friend_links_test.dart
```

Expected: 迁移 API 测试和现有友链 API 测试全部通过。

---

### Task 2: 增加 Repository 委托

**Files:**
- Modify: `lib/features/friends/data/friend_links_repository.dart`
- Modify: `test/features/friends/friend_links_test.dart` 或现有 Repository 测试文件

- [ ] **Step 1: 增加委托测试**

沿用 fake API/数据库测试方式验证：

```dart
await repository.migrateGroups();
expect(fakeApi.migrateGroupsCalls, 1);
```

- [ ] **Step 2: 实现委托和缓存清理**

在 `FriendLinksRepository` 增加：

```dart
Future<void> migrateGroups() async {
  await api.migrateGroups();
  await _clear();
}
```

迁移失败时不要清理缓存，因为后端状态未确认成功；成功后清理友链列表缓存。

- [ ] **Step 3: 运行相关测试**

```powershell
flutter test --no-pub test/features/friends
```

Expected: Repository 和 API 测试通过。

---

### Task 3: 增加迁移确认和执行 UI

**Files:**
- Modify: `lib/features/friends/presentation/friend_links_screen.dart`
- Test: `test/features/friends/friend_links_screen_test.dart` 或现有友链页面测试文件

- [ ] **Step 1: 写页面行为失败测试**

验证管理员打开“分组管理”后可看到：

```dart
expect(find.text('迁移未分组友链'), findsOneWidget);
```

点击后显示确认内容：

```dart
expect(find.text('该操作会将所有未分组友链归入默认分组，并为缺少颜色的存活友链补充颜色。确定继续吗？'), findsOneWidget);
```

点击取消后，Repository 的迁移调用次数保持为 0；点击确认后调用一次并显示：

```dart
expect(find.text('友链分组迁移完成'), findsOneWidget);
```

- [ ] **Step 2: 运行 widget 测试确认失败**

```powershell
flutter test --no-pub test/features/friends/friend_links_screen_test.dart
```

Expected: FAIL，因为迁移按钮和流程尚未存在。若该测试文件不存在，按现有测试目录和 ProviderScope 约定创建。

- [ ] **Step 3: 增加迁移状态和按钮**

在 `_GroupManagerDialogState` 增加：

```dart
bool migrating = false;
```

增加执行方法：

```dart
Future<void> _migrateGroups() async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('迁移未分组友链'),
      content: const Text(
        '该操作会将所有未分组友链归入默认分组，并为缺少颜色的存活友链补充颜色。确定继续吗？',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('确定'),
        ),
      ],
    ),
  );
  if (confirmed != true || !mounted) return;
  setState(() => migrating = true);
  try {
    await widget.repository.migrateGroups();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('友链分组迁移完成')),
      );
    }
  } catch (value) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('友链分组迁移失败：$value')),
      );
    }
  } finally {
    if (mounted) setState(() => migrating = false);
  }
}
```

在分组弹窗 actions 增加：

```dart
TextButton(
  onPressed: migrating ? null : _migrateGroups,
  child: const Text('迁移未分组友链'),
),
```

迁移期间禁用按钮并显示进行中状态，避免重复提交。迁移成功只刷新分组列表；外层现有 `_openGroupManager` 在弹窗关闭后会刷新友链列表。

- [ ] **Step 4: 运行 widget 测试确认通过**

```powershell
flutter test --no-pub test/features/friends/friend_links_screen_test.dart
```

Expected: 迁移入口、取消、确认、成功提示和失败提示测试通过。

---

### Task 4: 最终验证和接口范围审查

**Files:**
- No new files.

- [ ] **Step 1: 运行友链测试**

```powershell
flutter test --no-pub test/features/friends
```

Expected: all friend-link tests pass.

- [ ] **Step 2: 运行静态检查和差异检查**

```powershell
flutter analyze
git diff --check
git grep -n "action/friend/group/migrate" -- lib/features/friends test/features/friends
```

Expected: analyze 和 diff check 通过；迁移路径只出现在 API 封装和对应测试中。

- [ ] **Step 3: 检查范围**

确认：

- 使用 POST；
- 无请求体；
- 只有管理员页面可以进入；
- 取消确认不会发送请求；
- 成功后清理 Repository 缓存并刷新分组；
- 失败时弹窗保持打开；
- API 项目未被修改；
- 未增加其他迁移或自造接口。

- [ ] **Step 4: 汇报结果**

汇报修改文件和验证命令结果。未收到明确指示前不执行 commit 或 push。
