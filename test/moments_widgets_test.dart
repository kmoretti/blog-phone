import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:blog_phone/core/storage/secure_store.dart';
import 'package:blog_phone/data/api/api_client.dart';
import 'package:blog_phone/data/db/app_database.dart';
import 'package:blog_phone/features/moments/data/moments_provider.dart';
import 'package:blog_phone/features/moments/data/moments_repository.dart';
import 'package:blog_phone/features/moments/data/moments_api.dart';
import 'package:blog_phone/features/moments/presentation/media_preview.dart';
import 'package:blog_phone/features/moments/presentation/moment_detail_screen.dart'
    show MomentDetailScreen, toggleReaction;
import 'package:blog_phone/features/moments/presentation/moment_editor_screen.dart';

class _RecordingMomentsApi extends MomentsApi {
  _RecordingMomentsApi()
      : super(
          client: ApiClient(
            baseUrl: 'https://example.com',
            store: MemorySecureStore(),
          ),
        );

  UpdateMomentPayload? updatedPayload;

  @override
  Future<void> update(int id, UpdateMomentPayload payload) async {
    updatedPayload = payload;
  }
}

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

  test('serializes all dynamic moment fields', () {
    const create = CreateMomentPayload(
      content: 'content',
      tags: 'one,two',
      pinnedOrder: 2,
      isAd: 1,
      extension: '{"type":"website"}',
      messageLink: 'https://example.com/source',
    );
    const update = UpdateMomentPayload(
      content: 'content',
      status: 'visible',
      tags: 'one,two',
      pinnedOrder: 2,
      isAd: 1,
      extension: '{"type":"website"}',
      messageLink: 'https://example.com/source',
    );
    expect(create.toJson(), containsPair('tags', 'one,two'));
    expect(create.toJson(), containsPair('pinned_order', 2));
    expect(create.toJson(), containsPair('is_ad', 1));
    expect(create.toJson(), containsPair('extension', '{"type":"website"}'));
    expect(create.toJson(), containsPair('message_link', 'https://example.com/source'));
    expect(update.toJson(), containsPair('pinned_order', 2));
    expect(update.toJson(), containsPair('message_link', 'https://example.com/source'));
  });

  test('rejects invalid pinned order before serialization', () {
    expect(() => validatePinnedOrder('-1'), throwsA(isA<FormatException>()));
    expect(() => validatePinnedOrder('abc'), throwsA(isA<FormatException>()));
    expect(validatePinnedOrder('0'), 0);
    expect(validatePinnedOrder('3'), 3);
  });

  testWidgets('editor fills all dynamic fields', (tester) async {
    const moment = MomentDto(
      id: 1,
      content: 'content',
      tags: 'one,two',
      pinnedOrder: 3,
      isAd: 1,
      extension: '{"type":"website","payload":{"title":"示例网站","site":"https://example.com"}}',
      status: 'hidden',
      messageLink: 'https://example.com/source',
      createdAt: 1,
      updatedAt: 1,
      media: [],
      reactions: {},
      selectedReaction: null,
    );
    await tester.pumpWidget(const MaterialApp(home: MomentEditorScreen(moment: moment)));
    expect(find.text('one,two'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('https://example.com/source'), findsOneWidget);
    expect(find.text('示例网站'), findsOneWidget);
    expect(find.text('广告'), findsOneWidget);
    expect(find.text('暂无卡片'), findsNothing);
  });

  testWidgets('website card fields are editable and page save receives synced JSON', (tester) async {
    sqfliteFfiInit();
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      databasePathProvider: () async => 'moments-widget-${DateTime.now().microsecondsSinceEpoch}',
    );
    final api = _RecordingMomentsApi();
    final repository = MomentsRepository(api: api, database: database);
    const moment = MomentDto(
      id: 1,
      content: 'content',
      tags: '',
      pinnedOrder: 0,
      isAd: 0,
      extension: '{"type":"website","payload":{"title":"旧标题","site":"https://old.example"}}',
      status: 'visible',
      messageLink: '',
      createdAt: 1,
      updatedAt: 1,
      media: [],
      reactions: {},
      selectedReaction: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [momentsRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: MomentEditorScreen(moment: moment)),
      ),
    );
    expect(find.text('旧标题'), findsOneWidget);
    expect(find.text('https://old.example'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '旧标题'), '新标题');
    await tester.enterText(find.widgetWithText(TextField, 'https://old.example'), 'https://new.example');
    await tester.scrollUntilVisible(find.text('保存卡片'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('保存卡片'));
    await tester.pump();
    expect(find.text('新标题'), findsOneWidget);
    expect(find.text('https://new.example'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('更新'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('更新'));
    await tester.pumpAndSettle();
    expect(api.updatedPayload, isNotNull);
    expect(jsonDecode(api.updatedPayload!.extension!), {
      'type': 'website',
      'payload': {'title': '新标题', 'site': 'https://new.example'},
    });
    await database.close();
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
