import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../data/api/api_client.dart';
import '../../../state/auth/auth_provider.dart';
import '../data/moments_api.dart';
import '../data/moments_provider.dart';
import 'media_preview.dart';
import 'moment_detail_screen.dart';
import 'moment_extension.dart';
import 'moment_editor_screen.dart';

class MomentsScreen extends ConsumerWidget {
  const MomentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final isAdmin = auth is AuthenticatedState;
    final baseUrl = auth is AuthenticatedState
        ? auth.session.baseUrl
        : defaultApiBaseUrl;
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
                  itemBuilder: (_, index) => _MomentCard(
                    moment: page.items[index],
                    isAdmin: isAdmin,
                    apiBaseUrl: baseUrl,
                  ),
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
  const _MomentCard({
    required this.moment,
    required this.isAdmin,
    required this.apiBaseUrl,
  });
  final MomentDto moment;
  final bool isAdmin;
  final String apiBaseUrl;
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
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: Text(_time(moment.createdAt))),
                      if (moment.pinnedOrder > 0)
                        const Chip(
                          label: Text('置顶'),
                          avatar: Icon(Icons.push_pin, size: 16),
                        ),
                      if (moment.isAd == 1)
                        const Chip(
                          label: Text('广告'),
                          avatar: Icon(Icons.campaign_outlined, size: 16),
                        ),
                    ],
                  ),
                ),
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
            MomentMarkdown(content: moment.content),
            if (moment.tags.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: moment.tags
                    .split(',')
                    .where((tag) => tag.trim().isNotEmpty)
                    .map((tag) => Chip(label: Text('#${tag.trim()}')))
                    .toList(),
              ),
            ],
            if (moment.messageLink.trim().isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: isHttpUrl(moment.messageLink)
                      ? () => launchUrl(
                          Uri.parse(moment.messageLink),
                          mode: LaunchMode.externalApplication,
                        )
                      : null,
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text('查看来源'),
                ),
              ),
            if (parseMomentExtension(moment.extension) case final extension?)
              MomentExtensionCard(extension: extension),
            if (moment.media.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: MediaPreview(
                  url: moment.media.first.mediaUrl,
                  mediaType: moment.media.first.mediaType,
                  isLocal: moment.media.first.isLocal == 1,
                  apiBaseUrl: apiBaseUrl,
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
