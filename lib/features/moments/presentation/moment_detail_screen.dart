import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/moments_api.dart';
import '../data/moments_provider.dart';
import 'media_preview.dart';

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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('动态详情')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(moment.content, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 16),
        ...moment.media.map(
          (media) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MediaPreview(
              url: media.mediaUrl,
              mediaType: media.mediaType,
              isLocal: media.isLocal == 1,
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
