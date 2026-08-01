# 友链分组管理实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `blog-phone` 管理员友链页面中接入已有友链分组 API，完成分组 CRUD 和友链多分组关联。

**Architecture:** 沿用现有 `FriendLinksApi -> FriendLinksRepository -> Riverpod Provider -> FriendLinksScreen` 分层。API 层负责严格匹配后端路由和响应，Repository 作为页面访问边界，页面使用对话框和表单完成分组管理以及友链分组选择；不新增后端接口，不接入分组迁移接口。

**Tech Stack:** Flutter、Dart、Riverpod、现有 `ApiClient`、Flutter widget tests。

---

## 文件结构

- Modify: `E:\kmoretti-github\blog_api\blog-phone\lib\features\friends\data\friend_links_api.dart` — 分组模型、payload、API 方法，以及创建友链 ID 返回值。
- Modify: `E:\kmoretti-github\blog_api\blog-phone\lib\features\friends\data\friend_links_repository.dart` — 分组 API 的 Repository 封装和缓存失效。
- Modify if needed: `E:\kmoretti-github\blog_api\blog-phone\lib\features\friends\data\friend_links_provider.dart` — 仅在需要提供分组专用 provider 时修改；优先复用现有 Repository provider。
- Modify: `E:\kmoretti-github\blog_api\blog-phone\lib\features\friends\presentation\friend_links_screen.dart` — 管理入口、分组弹窗、友链分组多选和保存同步。
- Modify: `E:\kmoretti-github\blog_api\blog-phone\test\features\friends\friend_links_test.dart` — 分组模型与 API 契约测试。
- Modify or create only if an existing widget-test location is appropriate: `E:\kmoretti-github\blog_api\blog-phone\test\features\friends\friend_links_screen_test.dart` — 页面行为测试；先检查现有测试结构，若已有友链页面测试则扩展已有文件。

API 权威实现：

- `E:\kmoretti-github\blog_api\api\src\handler\friend_link_group.go`
- `E:\kmoretti-github\blog_api\api\src\repositories\friend\friend_link_group.go`
- `E:\kmoretti-github\blog_api\api\src\cmd\router\register.go`

---

### Task 1: 固化分组模型和请求类型

**Files:**
- Modify: `E:\kmoretti-github\blog_api\blog-phone\lib\features\friends\data\friend_links_api.dart`
- Test: `E:\kmoretti-github\blog_api\blog-phone\test\features\friends\friend_links_test.dart`

- [ ] **Step 1: 写分组模型解析的失败测试**

在现有 `friend_links_test.dart` 增加测试数据，验证以下 JSON 会解析成完整模型：

```dart
final group = FriendLinkGroup.fromJson({
  'id': 3,
  'name': '技术博客',
  'description': '技术类友链',
  'sort_order': 2,
  'created_at': 100,
  'updated_at': 200,
});
expect(group.id, 3);
expect(group.name, '技术博客');
expect(group.description, '技术类友链');
expect(group.sortOrder, 2);
expect(group.createdAt, 100);
expect(group.updatedAt, 200);
```

同时验证 `FriendLinkGroupPayload(name: '技术博客', description: '技术类友链', sortOrder: 2).toJson()` 输出 `name`、`description`、`sort_order` 三个 API 字段。

- [ ] **Step 2: 运行测试确认当前实现失败**

Run from `E:\kmoretti-github\blog_api\blog-phone`:

```powershell
flutter test --no-pub test/features/friends/friend_links_test.dart
```

Expected: FAIL because `FriendLinkGroup` and `FriendLinkGroupPayload` are not yet defined.

- [ ] **Step 3: 实现分组模型和 payload**

在 `friend_links_api.dart` 中增加：

```dart
class FriendLinkGroup {
  const FriendLinkGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String description;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;

  factory FriendLinkGroup.fromJson(Map<String, dynamic> json) => FriendLinkGroup(
    id: _int(json['id']),
    name: _string(json['name']),
    description: _string(json['description']),
    sortOrder: _int(json['sort_order']),
    createdAt: _int(json['created_at']),
    updatedAt: _int(json['updated_at']),
  );
}

class FriendLinkGroupPayload {
  const FriendLinkGroupPayload({
    required this.name,
    this.description = '',
    this.sortOrder = 0,
  });

  final String name;
  final String description;
  final int sortOrder;

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'sort_order': sortOrder,
  };
}
```

另增加内部响应解析所需的 `FriendLinkGroupIds` 解析逻辑，要求从 `data.group_ids` 读取列表，并把非数字值转换成整数后过滤无效值。

- [ ] **Step 4: 运行模型测试确认通过**

```powershell
flutter test --no-pub test/features/friends/friend_links_test.dart
```

Expected: 新增模型测试 PASS，已有友链测试不回归。

---

### Task 2: 完成六个分组 API 并支持创建友链返回 ID

**Files:**
- Modify: `E:\kmoretti-github\blog_api\blog-phone\lib\features\friends\data\friend_links_api.dart`
- Test: `E:\kmoretti-github\blog_api\blog-phone\test\features\friends\friend_links_test.dart`

- [ ] **Step 1: 为每个 API 写失败契约测试**

使用现有测试中的 fake Dio/adapter 风格，验证实际请求：

```text
GET    /api/action/friend/group
POST   /api/action/friend/group
PUT    /api/action/friend/group/3
DELETE /api/action/friend/group/3
GET    /api/action/friend/9/groups
PUT    /api/action/friend/9/groups
```

请求体必须分别为：

```json
{"name":"技术博客","description":"技术类友链","sort_order":2}
{"name":"技术博客","description":"更新后的描述","sort_order":3}
{"group_ids":[1,3]}
```

另外测试创建分组响应：

```json
{"code":201,"message":"success","data":{"id":3,"name":"技术博客","description":"技术类友链","sort_order":2,"created_at":100,"updated_at":200}}
```

应返回 `FriendLinkGroup`，不能要求业务 code 必须等于 200。

- [ ] **Step 2: 运行测试确认 API 方法缺失**

```powershell
flutter test --no-pub test/features/friends/friend_links_test.dart
```

Expected: FAIL，因为 API 方法及创建 ID 返回类型尚未完成。

- [ ] **Step 3: 实现 API 方法**

`FriendLinksApi` 增加以下签名，并保持路径不带重复 `/api`：

```dart
Future<List<FriendLinkGroup>> getGroups() async {
  final body = await client.get('action/friend/group');
  return _maps(body['data']).map(FriendLinkGroup.fromJson).toList();
}

Future<FriendLinkGroup> createGroup(FriendLinkGroupPayload payload) async {
  final body = await client.post(
    'action/friend/group',
    data: payload.toJson(),
  );
  return FriendLinkGroup.fromJson(
    Map<String, dynamic>.from(body['data'] as Map),
  );
}

Future<void> updateGroup(int id, FriendLinkGroupPayload payload) async {
  await client.put('action/friend/group/$id', data: payload.toJson());
}

Future<void> deleteGroup(int id) async {
  await client.delete('action/friend/group/$id');
}

Future<List<int>> getGroupIds(int friendLinkId) async {
  final body = await client.get('action/friend/$friendLinkId/groups');
  final data = Map<String, dynamic>.from(body['data'] as Map);
  final values = data['group_ids'];
  return values is List
      ? values.map((value) => _int(value)).where((value) => value > 0).toList()
      : const [];
}

Future<void> setGroups(int friendLinkId, List<int> groupIds) async {
  await client.put(
    'action/friend/$friendLinkId/groups',
    data: {'group_ids': groupIds},
  );
}
```

创建友链方法需要改为返回 ID，而不是 `Future<void>`：

```dart
Future<int> create(FriendLinkPayload payload) async {
  final body = await client.post('action/friend', data: payload.toCreateJson());
  final data = body['data'];
  if (data is Map) return _int(data['id']);
  return _int(body['id']);
}
```

若 API 实际创建响应为 `data` 中的友链对象，读取 `data.id`；如果没有有效 ID，抛出明确异常，禁止页面从列表猜测 ID。

- [ ] **Step 4: 运行 API 契约测试确认通过**

```powershell
flutter test --no-pub test/features/friends/friend_links_test.dart
```

Expected: 分组六接口、201 创建响应、友链创建 ID 测试 PASS。

---

### Task 3: 在 Repository 层封装分组操作

**Files:**
- Modify: `E:\kmoretti-github\blog_api\blog-phone\lib\features\friends\data\friend_links_repository.dart`
- Modify if needed: `E:\kmoretti-github\blog_api\blog-phone\lib\features\friends\data\friend_links_provider.dart`
- Test: `E:\kmoretti-github\blog_api\blog-phone\test\features\friends\friend_links_test.dart`

- [ ] **Step 1: 添加 Repository 方法的调用测试**

沿用现有 Repository fake API 测试模式，验证页面可通过 Repository 调用：

```dart
await repository.getGroups();
await repository.createGroup(payload);
await repository.updateGroup(3, payload);
await repository.deleteGroup(3);
expect(await repository.getGroupIds(9), [1, 3]);
await repository.setGroups(9, const [1, 3]);
```

- [ ] **Step 2: 实现 Repository 委托和缓存失效**

在 `FriendLinksRepository` 增加：

```dart
Future<List<FriendLinkGroup>> getGroups() => api.getGroups();

Future<FriendLinkGroup> createGroup(FriendLinkGroupPayload payload) async {
  final result = await api.createGroup(payload);
  await _clear();
  return result;
}

Future<void> updateGroup(int id, FriendLinkGroupPayload payload) async {
  await api.updateGroup(id, payload);
  await _clear();
}

Future<void> deleteGroup(int id) async {
  await api.deleteGroup(id);
  await _clear();
}

Future<List<int>> getGroupIds(int friendLinkId) => api.getGroupIds(friendLinkId);

Future<void> setGroups(int friendLinkId, List<int> ids) async {
  await api.setGroups(friendLinkId, ids);
  await _clear();
}
```

把原来的 `createGroup(String name, String description)` 改为接收 `FriendLinkGroupPayload`，避免 Repository 和 API 层字段不一致。把友链 `create` 改为返回 `Future<int>`，并保留成功后的缓存清理。

- [ ] **Step 3: 运行 Repository/API 测试**

```powershell
flutter test --no-pub test/features/friends/friend_links_test.dart
```

Expected: Repository 分组调用和已有友链缓存行为 PASS。

---

### Task 4: 实现分组管理弹窗

**Files:**
- Modify: `E:\kmoretti-github\blog_api\blog-phone\lib\features\friends\presentation\friend_links_screen.dart`
- Test: `E:\kmoretti-github\blog_api\blog-phone\test\features\friends\friend_links_screen_test.dart` 或现有友链页面测试文件

- [ ] **Step 1: 写管理员入口和分组 CRUD 的失败 widget 测试**

使用 `ProviderScope`、fake Repository/API 和 `MaterialApp` 包装页面，验证：

```dart
expect(find.byTooltip('分组管理'), findsOneWidget);
await tester.tap(find.byTooltip('分组管理'));
await tester.pumpAndSettle();
expect(find.text('分组管理'), findsOneWidget);
```

同时准备分组数据，验证弹窗展示名称、描述、排序，并覆盖新增、编辑、删除操作的 Repository 调用。

- [ ] **Step 2: 运行 widget 测试确认入口缺失**

```powershell
flutter test --no-pub test/features/friends/friend_links_screen_test.dart
```

Expected: FAIL，因为 AppBar 和分组弹窗尚未实现。如果该测试文件尚不存在，先按项目现有测试目录规则创建它。

- [ ] **Step 3: 增加分组管理入口和状态**

保持 `FriendLinksScreen extends ConsumerWidget`，在管理员 AppBar 增加：

```dart
IconButton(
  tooltip: '分组管理',
  icon: const Icon(Icons.category_outlined),
  onPressed: () => _openGroupManager(context, ref),
),
```

`_openGroupManager` 通过 `friendLinksRepositoryProvider` 加载分组，使用 `showDialog` 展示列表。不要在页面创建新的 `ApiClient`。

- [ ] **Step 4: 增加分组列表、新增、编辑和删除交互**

实现以下边界：

- 列表加载期间显示 `CircularProgressIndicator`；
- 新增/编辑表单包含名称、描述、排序，名称为空时不提交；
- 排序值限制为 0 或更大；
- 保存成功后刷新列表；
- 删除前使用 `AlertDialog` 确认；
- 删除成功后刷新列表；
- 请求失败显示 `SnackBar`，不关闭正在编辑的对话框；
- 不提供分组迁移按钮。

使用分组 API 模型的字段名和 UI 中文文案，避免引入后端不存在的字段。

- [ ] **Step 5: 运行 widget 测试确认入口和 CRUD 通过**

```powershell
flutter test --no-pub test/features/friends/friend_links_screen_test.dart
```

Expected: 管理员入口、列表展示、表单提交、删除确认和错误提示测试 PASS。

---

### Task 5: 将分组选择接入友链新增/编辑流程

**Files:**
- Modify: `E:\kmoretti-github\blog_api\blog-phone\lib\features\friends\presentation\friend_links_screen.dart`
- Modify: `E:\kmoretti-github\blog_api\blog-phone\lib\features\friends\data\friend_links_repository.dart`
- Test: `E:\kmoretti-github\blog_api\blog-phone\test\features\friends\friend_links_screen_test.dart`

- [ ] **Step 1: 写友链分组选择和保存同步的失败测试**

覆盖以下流程：

1. 编辑友链打开表单时 Repository 返回 `[1, 3]`，表单显示这两个已选分组。
2. 修改分组后保存，先调用友链 update，再调用 `setGroups(item.id, [2])`。
3. 新增友链时 `create` 返回 `9`，随后调用 `setGroups(9, [1])`。
4. `setGroups` 抛错时显示 `友链已保存，但分组更新失败`，且不重复调用基础信息 update。
5. 空选择时调用 `setGroups(id, const [])`，不由客户端生成默认分组 ID。

- [ ] **Step 2: 运行 widget 测试确认分组字段和同步缺失**

```powershell
flutter test --no-pub test/features/friends/friend_links_screen_test.dart
```

Expected: FAIL because the form has no group selection and save flow does not synchronize groups.

- [ ] **Step 3: 在表单中增加分组加载和多选状态**

在 `_edit` 打开时：

```dart
final repository = ref.read(friendLinksRepositoryProvider);
var groups = await repository.getGroups();
var selectedGroupIds = item == null
    ? <int>[]
    : await repository.getGroupIds(item.id);
```

分组加载或已有关系读取失败时显示错误提示并使用空列表，但仍允许用户取消表单。表单中增加使用 `FilterChip`/`CheckboxListTile` 的多选区域；优先选择项目现有 Flutter 组件风格，不引入新依赖。每个分组显示 `group.name`，按 API 返回的 `sort_order` 顺序展示。

- [ ] **Step 4: 修改保存顺序和错误提示**

保存逻辑必须遵循：

```dart
try {
  final repository = ref.read(friendLinksRepositoryProvider);
  final id = item == null
      ? await repository.create(payload)
      : (await repository.update(item.id, payload), item.id);
  try {
    await repository.setGroups(id, selectedGroupIds);
  } catch (_) {
    if (dialogContext.mounted) {
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        const SnackBar(content: Text('友链已保存，但分组更新失败')),
      );
    }
    return;
  }
  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
} catch (error) {
  if (dialogContext.mounted) {
    ScaffoldMessenger.of(dialogContext).showSnackBar(
      SnackBar(content: Text('保存友链失败：$error')),
    );
  }
}
```

Dart 中不要直接依赖逗号表达式；实际实现应使用清晰的 `if/else` 分支保存 `id`。基础信息保存失败时不调用 `setGroups`，基础信息成功后分组同步失败时保留弹窗并给出明确提示。

- [ ] **Step 5: 运行页面测试确认新增、编辑和失败路径通过**

```powershell
flutter test --no-pub test/features/friends/friend_links_screen_test.dart
```

Expected: 分组加载、多选、创建后关联、编辑后替换、空数组提交和失败提示测试 PASS。

---

### Task 6: 全量验证并审查接口范围

**Files:**
- No new files.

- [ ] **Step 1: 运行友链测试集**

```powershell
flutter test --no-pub test/features/friends
```

Expected: all friend-link API and widget tests PASS.

- [ ] **Step 2: 运行静态检查**

```powershell
flutter analyze
```

Expected: no new analyzer errors or warnings caused by the feature.

- [ ] **Step 3: 检查 diff 和接口字符串**

```powershell
git diff --check
git diff -- lib/features/friends test/features/friends
git grep -n "action/friend/group\|action/friend/.*/groups" -- blog-phone/lib/features/friends blog-phone/test/features/friends
```

Expected: 只出现 API 已有的六个分组接口；不得出现 `group/migrate`，不得出现自造路径。

- [ ] **Step 4: 检查关键契约**

确认：

- 创建分组使用 POST 且允许 201；
- 更新和删除分组使用正确 ID；
- 友链分组关联使用 PUT 和 `group_ids`；
- 新增友链使用创建响应 ID；
- 空分组由后端处理默认分组；
- 页面没有直接创建 `ApiClient`；
- API 项目文件没有被修改。

- [ ] **Step 5: 汇报验证结果**

汇总修改文件、支持的管理操作、测试命令和结果。未得到用户明确要求前，不执行 commit 或 push。
