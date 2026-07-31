import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:blog_phone/features/moments/data/moments_api.dart';
import 'package:blog_phone/features/moments/presentation/media_preview.dart';
import 'package:blog_phone/features/moments/presentation/moment_detail_screen.dart'
    show MomentDetailScreen, toggleReaction;

void main() {
  testWidgets('shows all reaction choices when the moment has no counts', (
    tester,
  ) async {
    const moment = MomentDto(
      id: 1,
      content: 'hello',
      tags: '',
      pinnedOrder: 0,
      isAd: 0,
      extension: '',
      status: 'visible',
      messageLink: '',
      createdAt: 100,
      updatedAt: 100,
      media: [],
      reactions: {},
      selectedReaction: null,
    );
    await tester.pumpWidget(
      const MaterialApp(home: MomentDetailScreen(moment: moment)),
    );
    expect(find.text('👍 0'), findsOneWidget);
    expect(find.text('💩 0'), findsOneWidget);
  });

  test('switches reaction counts instead of accumulating selections', () {
    final result = toggleReaction(
      reactions: {'👍': 2, '👀': 3},
      selectedReaction: '👍',
      reaction: '👀',
    );
    expect(result.reactions, {'👍': 1, '👀': 4});
    expect(result.selectedReaction, '👀');
  });

  testWidgets('renders video preview with play affordance', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaPreview(
          url: 'https://example.com/video.mp4',
          mediaType: 'video',
        ),
      ),
    );
    expect(find.text('视频暂不支持播放'), findsOneWidget);
  });
}
