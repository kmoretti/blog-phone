import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/api/api_client.dart';
import '../../../state/auth/auth_provider.dart';
import '../data/moments_api.dart';
import '../data/moments_provider.dart';
import 'media_preview.dart';
import 'moment_extension.dart';
import 'package:url_launcher/url_launcher.dart';

class ReactionToggleResult {
  const ReactionToggleResult({
    required this.reactions,
    required this.selectedReaction,
  });
  final Map<String, int> reactions;
  final String? selectedReaction;
}

ReactionToggleResult toggleReaction({
  required Map<String, int> reactions,
  required String? selectedReaction,
  required String reaction,
}) {
  final next = {...reactions};
  if (selectedReaction == reaction) {
    next[reaction] = _decrement(next[reaction]);
    return ReactionToggleResult(reactions: next, selectedReaction: null);
  }
  if (selectedReaction != null) {
    next[selectedReaction] = _decrement(next[selectedReaction]);
  }
  next[reaction] = (next[reaction] ?? 0) + 1;
  return ReactionToggleResult(reactions: next, selectedReaction: reaction);
}

int _decrement(int? value) => ((value ?? 1) - 1).clamp(0, 1 << 30);

class MomentDetailScreen extends ConsumerStatefulWidget {
  const MomentDetailScreen({super.key, required this.moment});
  final MomentDto moment;

  @override
  ConsumerState<MomentDetailScreen> createState() => _MomentDetailScreenState();
}

class _MomentDetailScreenState extends ConsumerState<MomentDetailScreen> {
  late MomentDto moment;

  @override
  void initState() {
    super.initState();
    moment = widget.moment;
  }

  @override
  Widget build(BuildContext context) {
    final baseUrl = ref.watch(authProvider) is AuthenticatedState
        ? (ref.watch(authProvider) as AuthenticatedState).session.baseUrl
        : defaultApiBaseUrl;
    return Scaffold(
      appBar: AppBar(title: const Text('动态详情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          if (moment.pinnedOrder > 0 || moment.isAd == 1)
            Wrap(
              spacing: 8,
              children: [
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
          if (moment.messageLink.trim().isNotEmpty &&
              isHttpUrl(moment.messageLink))
            TextButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final opened = await launchUrl(
                  Uri.parse(moment.messageLink),
                  mode: LaunchMode.externalApplication,
                );
                if (!opened && mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('无法打开来源链接')),
                  );
                }
              },
              icon: const Icon(Icons.link, size: 18),
              label: const Text('查看来源'),
            ),
          if (parseMomentExtension(moment.extension) case final extension?)
            MomentExtensionCard(extension: extension),
          const SizedBox(height: 16),
          ...moment.media.map(
            (media) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MediaPreview(
                url: media.mediaUrl,
                mediaType: media.mediaType,
                isLocal: media.isLocal == 1,
                apiBaseUrl: baseUrl,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            children: MomentsApi.allowedReactions.map((reaction) {
              final count = moment.reactions[reaction] ?? 0;
              final selected = moment.selectedReaction == reaction;
              return ActionChip(
                label: Text('$reaction $count'),
                onPressed: () async {
                  final repository = ref.read(momentsRepositoryProvider);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await repository.react(
                      moment.id,
                      reaction,
                      selected: selected,
                    );
                    if (!mounted) return;
                    setState(() {
                      final result = toggleReaction(
                        reactions: moment.reactions,
                        selectedReaction: moment.selectedReaction,
                        reaction: reaction,
                      );
                      moment = MomentDto(
                        id: moment.id,
                        content: moment.content,
                        tags: moment.tags,
                        pinnedOrder: moment.pinnedOrder,
                        isAd: moment.isAd,
                        extension: moment.extension,
                        status: moment.status,
                        messageLink: moment.messageLink,
                        createdAt: moment.createdAt,
                        updatedAt: moment.updatedAt,
                        media: moment.media,
                        reactions: result.reactions,
                        selectedReaction: result.selectedReaction,
                      );
                    });
                  } catch (error) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(content: Text(error.toString())),
                    );
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
