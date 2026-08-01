import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/friend_links_api.dart';
import '../data/friend_links_provider.dart';
import '../data/friend_links_repository.dart';

class FriendLinksScreen extends ConsumerWidget {
  const FriendLinksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(friendLinksAdminProvider);
    final status = ref.watch(friendLinksStatusProvider);
    final query = FriendLinksQuery(admin: admin, status: status);
    final result = ref.watch(friendLinksPageProvider(query));
    return Scaffold(
      appBar: AppBar(
        title: const Text('友链'),
        actions: [
          if (admin) ...[
            IconButton(
              tooltip: '分组管理',
              icon: const Icon(Icons.category_outlined),
              onPressed: () => _openGroupManager(context, ref),
            ),
            IconButton(
              tooltip: '新增友链',
              icon: const Icon(Icons.add),
              onPressed: () => _edit(context, ref),
            ),
          ],
        ],
      ),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (page) => RefreshIndicator(
          onRefresh: () => ref.refresh(friendLinksPageProvider(query).future),
          child: ListView(
            children: [
              if (admin) _AdminFilters(ref: ref),
              ...page.items.map(
                (item) => _FriendLinkCard(
                  item: item,
                  admin: admin,
                  onEdit: () => _edit(context, ref, item),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openGroupManager(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(friendLinksRepositoryProvider);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _GroupManagerDialog(repository: repository),
    );
    if (context.mounted) ref.invalidate(friendLinksPageProvider);
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    FriendLinkDto? item,
  ]) async {
    final repository = ref.read(friendLinksRepositoryProvider);
    List<FriendLinkGroup> groups = const [];
    var selectedGroupIds = <int>[];
    try {
      groups = await repository.getGroups();
      if (item != null) {
        selectedGroupIds = await repository.getGroupIds(item.id);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载友链分组失败：$error')));
      }
    }
    final fields = {
      'name': TextEditingController(text: item?.name ?? ''),
      'link': TextEditingController(text: item?.link ?? ''),
      'avatar': TextEditingController(text: item?.avatar ?? ''),
      'snapshot': TextEditingController(text: item?.snapshot ?? ''),
      'description': TextEditingController(text: item?.description ?? ''),
      'email': TextEditingController(text: item?.email ?? ''),
      'friendLinkPage': TextEditingController(text: item?.friendLinkPage ?? ''),
      'feed': TextEditingController(text: item?.feed ?? ''),
      'color': TextEditingController(text: item?.color ?? ''),
      'rss': TextEditingController(text: item?.rss ?? ''),
      'tags': TextEditingController(text: item?.tags.join(', ') ?? ''),
      'rejectionReason': TextEditingController(
        text: item?.rejectionReason ?? '',
      ),
    };
    var enableRss = item?.enableRss ?? false;
    var skipHealthCheck = item?.skipHealthCheck ?? false;
    var status = item?.status ?? 'pending';
    if (!context.mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(item == null ? '新增友链' : '编辑友链'),
          content: SizedBox(
            width: 520,
            height: MediaQuery.sizeOf(context).height * .65,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _field(fields['name']!, '名称', required: true),
                  _field(fields['link']!, '网址', required: true),
                  _field(fields['avatar']!, '头像地址', required: true),
                  _field(fields['snapshot']!, '网站封面'),
                  _field(fields['description']!, '描述', maxLines: 3),
                  _field(fields['email']!, '邮箱'),
                  _field(fields['friendLinkPage']!, '友链页面'),
                  _field(fields['feed']!, 'Feed 地址'),
                  _field(fields['rss']!, 'RSS 备用地址'),
                  _field(fields['color']!, '颜色'),
                  _field(fields['tags']!, '标签（逗号分隔）'),
                  if (groups.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('所属分组'),
                    ),
                    ...groups.map(
                      (group) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(group.name),
                        value: selectedGroupIds.contains(group.id),
                        onChanged: (value) => setState(() {
                          if (value == true) {
                            selectedGroupIds = [
                              ...selectedGroupIds,
                              if (!selectedGroupIds.contains(group.id))
                                group.id,
                            ];
                          } else {
                            selectedGroupIds = selectedGroupIds
                                .where((id) => id != group.id)
                                .toList();
                          }
                        }),
                      ),
                    ),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('启用 RSS'),
                    value: enableRss,
                    onChanged: (value) => setState(() => enableRss = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('跳过健康检查'),
                    subtitle: const Text('开启后，系统不会自动检查该友链的可访问性。仅管理员使用。'),
                    value: skipHealthCheck,
                    onChanged: (value) =>
                        setState(() => skipHealthCheck = value),
                  ),
                  if (item != null)
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: '审核状态'),
                      items:
                          const [
                                'pending',
                                'survival',
                                'timeout',
                                'error',
                                'rejected',
                              ]
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                      onChanged: (value) =>
                          setState(() => status = value ?? status),
                    ),
                  if (item != null)
                    _field(fields['rejectionReason']!, '拒绝原因', maxLines: 3),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                if (fields['name']!.text.trim().isEmpty ||
                    fields['link']!.text.trim().isEmpty ||
                    fields['avatar']!.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('名称、网址和头像地址不能为空')),
                  );
                  return;
                }
                final linkUri = Uri.tryParse(fields['link']!.text.trim());
                final avatarUri = Uri.tryParse(fields['avatar']!.text.trim());
                if (linkUri == null ||
                    avatarUri == null ||
                    !const {'http', 'https'}.contains(linkUri.scheme) ||
                    !const {'http', 'https'}.contains(avatarUri.scheme)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('网址和头像必须使用 HTTP(S)')),
                  );
                  return;
                }
                final email = fields['email']!.text.trim();
                if (email.isNotEmpty &&
                    !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('请输入有效邮箱')));
                  return;
                }
                final payload = FriendLinkPayload(
                  name: fields['name']!.text.trim(),
                  link: fields['link']!.text.trim(),
                  avatar: fields['avatar']!.text.trim(),
                  snapshot: fields['snapshot']!.text.trim(),
                  description: fields['description']!.text.trim(),
                  email: email,
                  enableRss: enableRss,
                  skipHealthCheck: skipHealthCheck,
                  friendLinkPage: fields['friendLinkPage']!.text.trim(),
                  feed: fields['feed']!.text.trim(),
                  color: fields['color']!.text.trim(),
                  rss: fields['rss']!.text.trim(),
                  tags: fields['tags']!.text
                      .split(',')
                      .map((tag) => tag.trim())
                      .where((tag) => tag.isNotEmpty)
                      .toList(),
                  status: item == null ? null : status,
                  rejectionReason: item == null
                      ? null
                      : fields['rejectionReason']!.text.trim(),
                );
                try {
                  final repository = ref.read(friendLinksRepositoryProvider);
                  late final int id;
                  if (item == null) {
                    id = await repository.create(payload);
                  } else {
                    await repository.update(item.id, payload);
                    id = item.id;
                  }
                  try {
                    await repository.setGroups(id, selectedGroupIds);
                  } catch (error) {
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
                    ScaffoldMessenger.of(
                      dialogContext,
                    ).showSnackBar(SnackBar(content: Text('保存友链失败：$error')));
                  }
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    for (final controller in fields.values) {
      controller.dispose();
    }
    if (result == true) {
      ref.invalidate(friendLinksPageProvider);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    bool required = false,
  }) => TextField(
    controller: controller,
    maxLines: maxLines,
    decoration: InputDecoration(labelText: required ? '$label *' : label),
  );
}

class _GroupManagerDialog extends StatefulWidget {
  const _GroupManagerDialog({required this.repository});
  final FriendLinksRepository repository;

  @override
  State<_GroupManagerDialog> createState() => _GroupManagerDialogState();
}

class _GroupManagerDialogState extends State<_GroupManagerDialog> {
  List<FriendLinkGroup> groups = const [];
  bool loading = true;
  bool migrating = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.repository.getGroups();
      if (!mounted) return;
      setState(() => groups = result);
    } catch (value) {
      if (!mounted) return;
      setState(() => error = '加载分组失败：$value');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _editGroup([FriendLinkGroup? group]) async {
    final name = TextEditingController(text: group?.name ?? '');
    final description = TextEditingController(text: group?.description ?? '');
    final sortOrder = TextEditingController(text: '${group?.sortOrder ?? 0}');
    final payload = await showDialog<FriendLinkGroupPayload>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(group == null ? '新增分组' : '编辑分组'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: '名称 *'),
            ),
            TextField(
              controller: description,
              decoration: const InputDecoration(labelText: '描述'),
            ),
            TextField(
              controller: sortOrder,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '排序'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final groupName = name.text.trim();
              final order = int.tryParse(sortOrder.text.trim());
              if (groupName.isEmpty || order == null || order < 0) return;
              Navigator.pop(
                dialogContext,
                FriendLinkGroupPayload(
                  name: groupName,
                  description: description.text.trim(),
                  sortOrder: order,
                ),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    name.dispose();
    description.dispose();
    sortOrder.dispose();
    if (payload == null || !mounted) return;
    try {
      if (group == null) {
        await widget.repository.createGroup(payload);
      } else {
        await widget.repository.updateGroup(group.id, payload);
      }
      await _load();
    } catch (value) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存分组失败：$value')));
      }
    }
  }

  Future<void> _migrateGroups() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('迁移未分组友链'),
        content: const Text('该操作会将所有未分组友链归入默认分组，并为缺少颜色的存活友链补充颜色。确定继续吗？'),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('友链分组迁移完成')));
      }
    } catch (value) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('友链分组迁移失败：$value')));
      }
    } finally {
      if (mounted) setState(() => migrating = false);
    }
  }

  Future<void> _deleteGroup(FriendLinkGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除分组'),
        content: Text('确定删除“${group.name}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.deleteGroup(group.id);
      await _load();
    } catch (value) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除分组失败：$value')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('分组管理'),
    content: SizedBox(
      width: 560,
      child: loading
          ? const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            )
          : error != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error!),
                TextButton(onPressed: _load, child: const Text('重试')),
              ],
            )
          : groups.isEmpty
          ? const Text('暂无分组')
          : ListView.builder(
              shrinkWrap: true,
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return ListTile(
                  title: Text(group.name),
                  subtitle: Text(
                    '${group.description} · 排序 ${group.sortOrder}',
                  ),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: '编辑分组',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editGroup(group),
                      ),
                      IconButton(
                        tooltip: '删除分组',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteGroup(group),
                      ),
                    ],
                  ),
                );
              },
            ),
    ),
    actions: [
      TextButton(
        onPressed: migrating ? null : _migrateGroups,
        child: Text(migrating ? '迁移中…' : '迁移未分组友链'),
      ),
      TextButton(onPressed: () => _editGroup(), child: const Text('新增分组')),
      FilledButton(
        onPressed: migrating ? null : () => Navigator.pop(context),
        child: const Text('关闭'),
      ),
    ],
  );
}

class _SafeAvatar extends StatelessWidget {
  const _SafeAvatar({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(url);
    if (uri == null || !const {'http', 'https'}.contains(uri.scheme)) {
      return const CircleAvatar(child: Icon(Icons.link));
    }
    return CircleAvatar(
      backgroundImage: NetworkImage(url),
      onBackgroundImageError: (exception, stackTrace) {},
    );
  }
}

class _AdminFilters extends StatelessWidget {
  const _AdminFilters({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Wrap(
      spacing: 8,
      children: ['全部', 'pending', 'survival', 'timeout', 'error', 'rejected']
          .map(
            (status) => ActionChip(
              label: Text(status == '全部' ? status : '审核 $status'),
              onPressed: () {
                ref.read(friendLinksStatusProvider.notifier).state =
                    status == '全部' ? null : status;
              },
            ),
          )
          .toList(),
    ),
  );
}

class _FriendLinkCard extends StatelessWidget {
  const _FriendLinkCard({
    required this.item,
    required this.admin,
    required this.onEdit,
  });
  final FriendLinkDto item;
  final bool admin;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: ListTile(
      leading: _SafeAvatar(url: item.avatar),
      title: Text(item.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.description),
          Wrap(
            spacing: 4,
            children: item.tags.map((tag) => Chip(label: Text(tag))).toList(),
          ),
          if (admin) Text('状态：${item.status}'),
        ],
      ),
      onTap: () {
        final uri = Uri.tryParse(item.link);
        if (uri != null && const {'http', 'https'}.contains(uri.scheme)) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      trailing: admin
          ? IconButton(icon: const Icon(Icons.edit), onPressed: onEdit)
          : null,
    ),
  );
}
