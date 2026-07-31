import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../state/auth/auth_provider.dart';
import '../data/moments_api.dart';
import '../data/moments_provider.dart';
import 'media_preview.dart';
import 'moment_detail_screen.dart';
import 'moment_editor_screen.dart';

class MomentsScreen extends ConsumerWidget {
  const MomentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(authProvider) is AuthenticatedState;
    final result = ref.watch(momentsPageProvider(isAdmin));
    return Scaffold(
      appBar: AppBar(
        title: const Text('动态列表'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MomentEditorScreen()),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          StreamBuilder<List<ConnectivityResult>>(
            stream: Connectivity().onConnectivityChanged,
            builder: (context, snapshot) {
              final offline =
                  snapshot.hasData &&
                  snapshot.data!.every(
                    (item) => item == ConnectivityResult.none,
                  );
              return MaterialBanner(
                content: Text(offline ? '当前离线，显示缓存' : '当前在线'),
                actions: const [SizedBox.shrink()],
              );
            },
          ),
          Expanded(
            child: result.when(
              data: (page) => RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(momentsPageProvider(isAdmin).future),
                child: ListView.builder(
                  itemCount: page.items.length,
                  itemBuilder: (_, index) =>
                      _MomentCard(moment: page.items[index], isAdmin: isAdmin),
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(error.toString())),
            ),
          ),
        ],
      ),
    );
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({required this.moment, required this.isAdmin});
  final MomentDto moment;
  final bool isAdmin;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.all(12),
    child: InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MomentDetailScreen(moment: moment)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 12),
                Expanded(child: Text(_time(moment.createdAt))),
                if (isAdmin)
                  IconButton(
                    tooltip: '编辑动态',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MomentEditorScreen(moment: moment),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(moment.content),
            if (moment.media.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: MediaPreview(
                  url: moment.media.first.mediaUrl,
                  mediaType: moment.media.first.mediaType,
                  isLocal: moment.media.first.isLocal == 1,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: moment.reactions.entries
                  .map(
                    (entry) => Chip(label: Text('${entry.key} ${entry.value}')),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    ),
  );
}

String _time(int seconds) => DateTime.fromMillisecondsSinceEpoch(
  seconds * 1000,
).toLocal().toString().substring(0, 16);
