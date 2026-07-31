import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/friend_links_api.dart';
import '../data/friend_links_provider.dart';

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
          if (admin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _edit(context, ref),
            ),
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

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    FriendLinkDto? item,
  ]) async {
    final fields = {
      'name': TextEditingController(text: item?.name ?? ''),
      'link': TextEditingController(text: item?.link ?? ''),
      'avatar': TextEditingController(text: item?.avatar ?? ''),
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
                  _field(fields['description']!, '描述', maxLines: 3),
                  _field(fields['email']!, '邮箱'),
                  _field(fields['friendLinkPage']!, '友链页面'),
                  _field(fields['feed']!, 'Feed 地址'),
                  _field(fields['rss']!, 'RSS 地址'),
                  _field(fields['color']!, '颜色'),
                  _field(fields['tags']!, '标签（逗号分隔）'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('启用 RSS'),
                    value: enableRss,
                    onChanged: (value) => setState(() => enableRss = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('跳过健康检查'),
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
                if (item == null) {
                  await ref.read(friendLinksRepositoryProvider).create(payload);
                } else {
                  await ref
                      .read(friendLinksRepositoryProvider)
                      .update(item.id, payload);
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
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
