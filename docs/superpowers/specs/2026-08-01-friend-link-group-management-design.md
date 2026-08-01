# 友链分组管理设计

## 目标

在 `blog-phone` 的管理员友链页面中接入 API 项目已经提供的友链分组能力，支持分组 CRUD，以及为新增和已有友链选择多个分组。实现严格复用 API 已注册的接口，不新增后端路由，不在手机端暴露数据迁移接口。

## API 契约

手机端只使用以下已有管理员接口：

- `GET /api/action/friend/group`：获取分组列表。
- `POST /api/action/friend/group`：创建分组，成功响应 HTTP 201，`data` 为完整分组对象。
- `PUT /api/action/friend/group/:id`：更新分组，成功响应 `data: null`。
- `DELETE /api/action/friend/group/:id`：删除分组，成功响应 `data: null`。
- `GET /api/action/friend/:id/groups`：获取友链的分组 ID，响应为 `{ "group_ids": number[] }`。
- `PUT /api/action/friend/:id/groups`：替换友链的完整分组关联，请求体为 `{ "group_ids": number[] }`，成功响应 `data: null`。

不使用 `POST /api/action/friend/group/migrate`，因为它是用于历史数据迁移和默认分组补全的维护接口，不属于日常友链管理交互。

分组字段严格对应 API 模型：

```text
id: number
name: string
description: string
sort_order: number
created_at: number
updated_at: number
```

API 在设置空分组时会自动将友链放入默认分组，因此客户端允许提交空数组，不自行伪造默认分组 ID。

## 数据层设计

### 分组模型

在 `lib/features/friends/data/friend_links_api.dart` 增加 `FriendLinkGroup`，提供 `fromJson` 和 `toJson`，并按现有文件中的转换函数处理数字和字符串兼容值。

### API 封装

`FriendLinksApi` 增加：

- `getGroups()`，返回 `List<FriendLinkGroup>`；
- `createGroup(FriendLinkGroupPayload payload)`，返回创建后的 `FriendLinkGroup`，保留 HTTP 201 语义；
- `updateGroup(int id, FriendLinkGroupPayload payload)`；
- `deleteGroup(int id)`；
- `getGroupIds(int friendLinkId)`；
- 保留并规范 `setGroups(int friendLinkId, List<int> groupIds)`。

请求路径只使用 API 已注册路径，不能增加别名或自定义 endpoint。

### Repository 封装

`FriendLinksRepository` 继续作为页面访问 API 的边界，增加对应的分组方法。分组列表不写入现有友链列表缓存，CRUD 和友链分组关联成功后清理友链列表缓存，确保页面重新加载时获取最新数据。页面不得直接实例化 `ApiClient`。

## 页面交互设计

### 分组管理入口

管理员在友链页面 AppBar 中看到“分组管理”按钮。点击后打开分组管理弹窗，加载最新分组列表。普通用户不显示入口，也不会触发管理员分组接口。

### 分组管理弹窗

弹窗显示分组名称、描述和排序值，并提供：

- 新增分组；
- 编辑分组；
- 删除分组。

新增和编辑共用一个表单，名称必填，描述可选，排序值为不小于 0 的整数。删除前显示确认提示；删除成功后刷新分组列表并同步刷新友链表单可选项。接口失败时保留弹窗状态并显示错误提示。

### 友链表单

管理员新增或编辑友链时显示“所属分组”多选控件：

- 打开表单时加载分组列表；
- 编辑已有友链时调用 `getGroupIds` 初始化已选分组；
- 新增友链时初始为空数组；
- 友链基础信息保存成功后，再调用 `setGroups` 同步完整分组列表；
- 新增友链必须读取创建接口返回的友链 ID，不能从刷新后的列表猜测 ID；
- 基础信息保存成功但分组同步失败时，提示“友链已保存，但分组更新失败”，不回滚已经成功的基础信息；
- 取消或基础信息保存失败时不调用分组设置接口。

空分组选项仍然提交给 API，由后端自动归入默认分组。

## 错误处理

- API 返回非 2xx 或业务错误时沿用现有 `ApiClient` 异常处理，不吞掉错误。
- 分组列表加载失败时显示错误提示，表单中的分组选择为空或沿用已加载的旧值，不阻塞普通友链列表展示。
- 分组 CRUD 失败时不关闭当前表单，避免用户输入丢失。
- 编辑友链读取分组失败时显示提示，并将已选分组设为空，用户仍可取消或继续保存；继续保存会按照空数组提交，由后端应用默认分组规则。
- 删除分组成功后不假设友链已经被删除；后端只解除关联，友链仍保留。

## 测试设计

### API 契约测试

在现有友链 API 测试中覆盖：

- 分组 JSON 解析；
- 分组列表 GET 路径；
- 创建分组 POST payload 和 HTTP 201；
- 更新分组 PUT 路径及 payload；
- 删除分组 DELETE 路径；
- 获取友链分组 ID 的 GET 路径；
- 设置友链分组的 PUT 路径及 `{group_ids: [...]}` payload；
- 空数组可以正常提交。

### 页面行为测试

覆盖管理员页面的关键行为：

- 管理员看到分组管理入口，普通用户看不到；
- 新增/编辑分组调用正确接口；
- 编辑友链时加载已有分组；
- 新增和编辑友链保存后同步分组；
- 基础信息成功但分组同步失败时显示明确提示；
- 分组删除成功后刷新可选分组。

## 范围边界

本次只修改 `blog-phone` 的友链数据层、Repository/Provider 访问边界、页面交互和对应测试。不得修改 API 项目的模型、路由或接口；不得新增手机端自定义接口；不得把分组迁移维护接口加入普通页面。
