# 友链 API 契约对齐设计

## 目标

使 `blog-phone` 的友链功能严格遵循 `E:\kmoretti-github\blog_api\api` 的已注册路由、请求模型和响应字段，不新增 API 路由、不创造 API 不支持的字段，并审查手机端生产代码中的接口调用，移除或修正与 API 项目不一致的调用。

## API 契约基准

唯一基准为 `E:\kmoretti-github\blog_api\api` 的实际路由注册、handler 和 model；API 文档或旧注释与实际注册不一致时，以实际注册为准。

友链相关公开接口：

- `GET /api/public/friend/`
- `GET /api/public/friend/:id`
- `POST /api/public/friend/apply`
- `POST /api/public/friend/update-apply`
- `GET /api/public/friend/submissions`

友链相关管理接口：

- `GET /api/action/friend`
- `GET /api/action/friend/:id`
- `POST /api/action/friend`
- `PUT /api/action/friend/:id`
- `DELETE /api/action/friend/:id`
- `POST /api/action/friend/:id/recheck`
- 分组相关 `/api/action/friend/group*` 和 `/api/action/friend/:id/groups`

RSS 相关接口：

- `GET /api/public/rss/`
- `POST /api/public/rss/refresh`
- 管理端 `/api/action/rss*`

## 友链申请表单

申请页面只对应 `POST /api/public/friend/apply`，不复用管理端 payload。

字段和 API 请求字段严格对应：

| 页面字段 | API 字段 | 必填 | 说明 |
|---|---|---:|---|
| 网站名称 | `name` | 是 | 申请模型字段 |
| 网站链接 | `link` | 是 | HTTP(S) URL |
| 网站图标 | `avatar` | 是 | HTTP(S) URL |
| 描述 | `description` | 否 | API 可选字段 |
| 站长邮箱 | `email` | 是 | 用于审核通知 |
| 网站封面 | `snapshot` | 否 | 使用 API 已有 snapshot，不新增 cover 字段 |
| 友链页面 | `friend_link_page` | 否 | 友链页面 URL |
| 内容 RSS | `feed` | 否 | 申请接口唯一 RSS 地址字段 |
| 订阅 RSS | `enable_rss` | 否 | 是否启用 RSS |

申请页面不显示：

- `skip_health_check`
- `status`
- `rejection_reason`
- 管理端 `rss`
- `color`
- `tags`

这些字段不属于公开申请请求模型，或属于管理员维护字段。

## 网站封面

不新增 `cover_url` 等 API 不存在的字段。使用 API 已有的 `snapshot`：

- `FriendLinkDto` 增加 `snapshot`；
- JSON 解析和序列化保留 `snapshot`；
- 管理 payload 支持 API 管理模型已有的 `snapshot`；
- 申请 payload 支持申请模型的 `snapshot`；
- 友链管理表单增加“网站封面”输入框；
- 展示层按已有友链卡片能力决定是否显示，不改变 API 数据语义；
- 缓存 JSON 必须保留 `snapshot`。

语义保持：`avatar` 是网站图标，`snapshot` 是网站封面/截图。

## Feed/RSS 处理

公开申请接口只提交 `feed`，因为 `FriendLinkApplyReq` 没有 `rss` 字段。

管理员数据模型仍保留 API 已有的 `feed` 和 `rss` 字段用于兼容读取，但手机端管理表单只展示并编辑 API Web 管理页面实际提供的 `feed` 字段：

- `Feed 地址`

手机端不展示或提交 `RSS 备用地址`，不新增 `rss_url` 字段，也不创建新的 RSS API。具体 RSS 抓取数据由 API 的 `friend_rss.rss_url` 管理。

## 跳过健康检查

`skip_health_check` 仅保留在管理员友链表单，提交到 `/api/action/friend` 或 `/api/action/friend/:id`。

申请表单不展示该字段。管理员文案说明：

> 开启后，系统不会自动检查该友链的可访问性。仅管理员使用。

## 已确认的客户端接口修正

修正以下已确认与 API 路由不一致的调用：

- 公开友链列表：`friend/` → `public/friend/`
- RSS 全量刷新：`rss/refresh` → `public/rss/refresh`
- 公开 RSS 文章列表：`public/rss` → `public/rss/`，与 API 注册尾斜杠一致

其他已审查模块中，auth、moments、resource local/OSS、图片和管理端 friend/RSS 路径均以 API 实际路由为准；不额外创建接口。

## API 审查范围

对 `blog-phone/lib` 中所有生产代码的 `ApiClient` 调用进行静态清单审查：

1. 提取 HTTP 方法和 endpoint；
2. 与 `api/src/cmd/router/register.go` 实际注册路由对照；
3. 标记不存在的路径、HTTP 方法不匹配、尾斜杠不一致和请求字段不匹配；
4. 修复确认属于客户端错误的调用；
5. 对未发现问题的接口增加或更新契约测试；
6. 不修改 API 项目，不为客户端问题新增 API 路由。

## 错误处理和兼容性

- API 的统一 JSON 外层由现有 `ApiClient` 处理，业务模型只解析 API 的 `data`；
- 申请接口和管理接口使用独立 payload，避免把管理字段发送给公开申请接口；
- 对旧缓存没有 `snapshot` 的数据使用空字符串兼容；
- 不把 `rss` 自动伪造为 `feed`，也不把 `feed` 改名为 API 不存在的 `rss_url`；
- URL 校验沿用现有表单规则，仅允许 HTTP(S)。

## 测试策略

补充或更新：

- 公开友链列表请求路径为 `/api/public/friend/`；
- RSS 公开列表和全量刷新路径与 API 注册一致；
- `snapshot` 的 DTO 解析、序列化和 payload 映射；
- 公开申请 payload 只包含 API 申请模型字段；
- 管理 payload 继续支持 `skip_health_check`、`feed`、`rss`；
- 友链表单展示字段与申请/管理模型边界；
- 全生产 endpoint 静态契约审查结果。

验证命令：

```powershell
flutter test test/features/friends
flutter test test/features/rss
flutter analyze
git diff --check
```
