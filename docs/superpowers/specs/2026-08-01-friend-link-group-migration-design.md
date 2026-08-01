# 友链分组迁移设计

## 目标

在管理员友链分组管理弹窗中接入 API 已有的分组迁移接口，将未分组友链迁移到默认分组，并完成前端反馈和刷新。

## API 契约

严格使用已有接口：

```text
POST /api/action/friend/group/migrate
```

接口无请求体，使用现有管理员认证。成功返回 HTTP 200，业务响应数据包含：

```json
{"message":"migration completed"}
```

迁移由后端完成：确保默认分组“网上邻居”存在，将所有未分组友链归入默认分组，并为缺少颜色的存活友链生成颜色。接口可重复执行，客户端不自行实现迁移逻辑，也不猜测默认分组 ID。

## 页面交互

在现有“分组管理”弹窗中增加“迁移未分组友链”操作。点击后先显示确认提示，明确说明迁移会影响未分组友链，并可能为缺色的存活友链补充颜色。

用户确认后：

1. 调用 `FriendLinksRepository.migrateGroups()`；
2. 显示加载状态，避免重复点击；
3. 成功提示“友链分组迁移完成”；
4. 刷新分组列表；
5. 关闭分组弹窗后刷新友链列表。

用户取消时不发起请求。请求失败时保留分组弹窗，显示失败提示并允许重试。

## 数据层

`FriendLinksApi` 增加：

```dart
Future<void> migrateGroups() async {
  await client.post('action/friend/group/migrate');
}
```

`FriendLinksRepository` 增加同名委托方法。迁移成功后清理友链列表缓存；不增加新 Provider，不直接在页面创建 `ApiClient`。

## 测试

覆盖：

- POST 路径、HTTP 方法和无请求体；
- 迁移成功响应；
- Repository 委托；
- 分组管理弹窗显示迁移入口；
- 取消确认不请求；
- 确认后显示加载并执行迁移；
- 成功提示和列表刷新；
- 失败提示且弹窗保持打开。

## 范围边界

只修改 `blog-phone` 友链 API、Repository、分组管理弹窗和测试。不得修改 API 项目，不新增后端路由，不在客户端实现迁移业务规则。
