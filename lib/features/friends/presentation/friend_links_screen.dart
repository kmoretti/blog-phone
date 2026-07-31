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

  Future<void> _edit(BuildContext context, WidgetRef ref, [FriendLinkDto? item]) async {
    final name = TextEditingController(text: item?.name);
    final link = TextEditingController(text: item?.link);
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(item == null ? '新增友链' : '编辑友链'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: '名称')),
            TextField(controller: link, decoration: const InputDecoration(labelText: '网址')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final payload = FriendLinkPayload(name: name.text.trim(), link: link.text.trim());
              if (item == null) {
                await ref.read(friendLinksRepositoryProvider).create(payload);
              } else {
                await ref.read(friendLinksRepositoryProvider).update(item.id, payload);
              }
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == true) {
      ref.invalidate(friendLinksPageProvider);
    }
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
      children: ['全部', 'pending', 'survival', 'rejected']
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
  const _FriendLinkCard({required this.item, required this.admin, required this.onEdit});
  final FriendLinkDto item;
  final bool admin;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: ListTile(
      leading: CircleAvatar(backgroundImage: NetworkImage(item.avatar)),
      title: Text(item.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.description),
          Wrap(spacing: 4, children: item.tags.map((tag) => Chip(label: Text(tag))).toList()),
          if (admin) Text('状态：${item.status}'),
        ],
      ),
      onTap: () => launchUrl(Uri.parse(item.link), mode: LaunchMode.externalApplication),
      trailing: admin ? IconButton(icon: const Icon(Icons.edit), onPressed: onEdit) : null,
    ),
  );
}
