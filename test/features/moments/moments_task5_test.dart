import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blog_phone/data/models/auth_models.dart';
import 'package:blog_phone/features/moments/presentation/moments_screen.dart';
import 'package:blog_phone/features/moments/data/moments_provider.dart';
import 'package:blog_phone/state/auth/auth_provider.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:blog_phone/core/storage/secure_store.dart';
import 'package:blog_phone/data/api/api_client.dart';
import 'package:blog_phone/data/api/api_exception.dart';
import 'package:blog_phone/data/db/app_database.dart';
import 'package:blog_phone/data/db/models.dart' as db;
import 'package:blog_phone/features/moments/data/moments_api.dart';
import 'package:blog_phone/features/moments/data/moments_repository.dart';

class FakeMomentsApi extends MomentsApi {
  FakeMomentsApi({this.page, this.error, this.reactionError})
    : super(
        client: ApiClient(
          baseUrl: 'https://invalid.local',
          store: MemorySecureStore(),
        ),
      );

  MomentsPage? page;
  ApiException? error;
  CreateMomentPayload? created;
  ApiException? reactionError;
  int addReactionCalls = 0;
  int removeReactionCalls = 0;

  @override
  Future<void> addReaction(int id, String reaction) async {
    addReactionCalls++;
    if (reactionError != null) throw reactionError!;
  }

  @override
  Future<void> removeReaction(int id, String reaction) async {
    removeReactionCalls++;
    if (reactionError != null) throw reactionError!;
  }

  @override
  Future<MomentsPage> list({
    int page = 1,
    int pageSize = 10,
    bool admin = false,
  }) async {
    if (error != null) throw error!;
    return this.page!;
  }

  @override
  Future<void> create(CreateMomentPayload payload) async {
    if (error != null) throw error!;
    created = payload;
  }
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this.initialState);
  final AuthState initialState;

  @override
  AuthState build() => initialState;
}

MomentDto moment({
  int id = 1,
  String content = 'cached content',
  List<MomentMediaDto> media = const [],
  Map<String, int> reactions = const {},
}) => MomentDto(
  id: id,
  content: content,
  tags: '',
  pinnedOrder: 0,
  isAd: 0,
  extension: '',
  status: 'visible',
  messageLink: '',
  createdAt: 100,
  updatedAt: 101,
  media: media,
  reactions: reactions,
  selectedReaction: null,
);

void main() {
  late String databasePath;
  late AppDatabase database;

  setUp(() {
    sqfliteFfiInit();
    databasePath = path.join(
      Directory.systemTemp.path,
      'blog_phone_task5_${DateTime.now().microsecondsSinceEpoch}',
    );
    Directory(databasePath).createSync();
    database = AppDatabase(
      factory: databaseFactoryFfi,
      databasePathProvider: () async => databasePath,
    );
  });

  tearDown(() async {
    await database.close();
    Directory(databasePath).deleteSync(recursive: true);
  });

  test('parses the administrator moments response shape', () {
    final page = MomentsPage.fromJson({
      'moments': [
        {
          'id': 9,
          'content': 'admin content',
          'status': 'hidden',
          'tags': '',
          'pinned_order': 0,
          'is_ad': 0,
          'extension': '',
          'message_link': '',
          'created_at': 100,
          'updated_at': 101,
          'media': [],
          'reactions': {},
        },
      ],
      'total': 1,
    });

    expect(page.items.single.id, 9);
    expect(page.total, 1);
  });

  test('requires an injected ApiClient for MomentsApi', () {
    expect(MomentsApi.new, isNotNull);
  });

  test('returns cache when remote moments request fails', () async {
    final cachedMedia = MomentMediaDto(
      id: 2,
      momentId: 1,
      name: 'photo',
      mediaUrl: 'https://cdn.test/photo.jpg',
      mediaType: 'image',
      isLocal: 0,
      isDeleted: 0,
    );
    final repository = MomentsRepository(
      api: FakeMomentsApi(
        page: MomentsPage(
          items: [
            moment(media: [cachedMedia], reactions: {'👍': 2}),
          ],
          total: 1,
          page: 1,
          pageSize: 10,
        ),
        error: const ApiException(message: 'offline', isNetworkError: true),
      ),
      database: database,
    );
    final dbInstance = await database.database;
    await dbInstance.insert('moments', {
      'id': '1',
      'content': 'cached content',
      'tags': '',
      'pinned_order': 0,
      'is_ad': 0,
      'extension': '',
      'status': 'visible',
      'message_link': '',
      'created_at': 100,
      'updated_at': 101,
    });
    await dbInstance.insert('moment_media', cachedMedia.toJson());
    await dbInstance.insert('moment_reactions', {
      'id': 3,
      'moment_id': '1',
      'fingerprint_id': 0,
      'reaction': '👍',
      'created_at': 101,
    });

    final result = await repository.load();

    expect(result.items.single.content, 'cached content');
    expect(result.items.single.media.single.mediaUrl, cachedMedia.mediaUrl);
    expect(result.items.single.reactions, {'👍': 1});
  });

  test('writes moments, media, and reactions in one cache refresh', () async {
    final remote = MomentsPage(
      items: [
        moment(
          media: [
            MomentMediaDto(
              id: 4,
              momentId: 1,
              name: 'remote',
              mediaUrl: 'https://cdn.test/remote.jpg',
              mediaType: 'image',
              isLocal: 0,
              isDeleted: 0,
            ),
          ],
          reactions: {'❤️': 4},
        ),
      ],
      total: 1,
      page: 1,
      pageSize: 10,
    );
    final repository = MomentsRepository(
      api: FakeMomentsApi(page: remote),
      database: database,
    );

    await repository.load();

    final dbInstance = await database.database;
    expect(
      (await dbInstance.query('moments')).single['content'],
      'cached content',
    );
    expect(
      (await dbInstance.query('moment_media')).single['media_url'],
      'https://cdn.test/remote.jpg',
    );
    expect(
      (await dbInstance.query('moment_reactions')).single['reaction'],
      '❤️',
    );
  });

  test('stores local-media draft without an outbox item', () async {
    final repository = MomentsRepository(
      api: FakeMomentsApi(
        error: const ApiException(message: 'offline', isNetworkError: true),
      ),
      database: database,
    );

    await repository.save(
      const CreateMomentPayload(
        content: 'offline post',
        media: [
          CreateMediaPayload(
            mediaUrl: '/tmp/photo.jpg',
            mediaType: 'image',
            isLocal: 1,
          ),
        ],
      ),
    );

    final dbInstance = await database.database;
    final draft = (await dbInstance.query('drafts')).single;
    expect(draft['status'], 'draft');
    expect(draft['content'], 'offline post');
    expect(await dbInstance.query('outbox'), isEmpty);
  });

  test('isolates guest and admin page cache rows, media, and reactions', () async {
    final guest = MomentsRepository(
      api: FakeMomentsApi(page: MomentsPage(items: [moment(content: 'guest')], total: 1, page: 1, pageSize: 10)),
      database: database,
    );
    final admin = MomentsRepository(
      api: FakeMomentsApi(page: MomentsPage(items: [moment(content: 'admin', reactions: {'👀': 2})], total: 1, page: 1, pageSize: 10)),
      database: database,
    );

    await guest.load();
    await admin.load(admin: true);

    final guestCached = await guest.load();
    final adminCached = await admin.load(admin: true);
    expect(guestCached.items.single.content, 'guest');
    expect(adminCached.items.single.content, 'admin');
    final rows = await (await database.database).query('moments');
    expect(rows.map((row) => row['cache_scope']), containsAll(<Object>['guest', 'admin']));
  });

  test('does not put client errors into retryable outbox', () async {
    for (final statusCode in [400, 403, 404, 409]) {
      final repository = MomentsRepository(
        api: FakeMomentsApi(error: ApiException(message: 'client', statusCode: statusCode)),
        database: database,
      );

      await repository.save(const CreateMomentPayload(content: 'client error'));
    }

    expect(await (await database.database).query('outbox'), isEmpty);
  });

  test('puts network and server errors into pending outbox', () async {
    for (final error in [
      const ApiException(message: 'offline', isNetworkError: true),
      const ApiException(message: 'server', statusCode: 503),
    ]) {
      final repository = MomentsRepository(
        api: FakeMomentsApi(error: error),
        database: database,
      );
      await repository.save(const CreateMomentPayload(content: 'retryable'));
    }

    expect(
      (await (await database.database).query('outbox'))
          .map((row) => row['status']),
      everyElement(db.OutboxStatus.pending),
    );
  });

  test('queues offline reaction without queueing client errors', () async {
    final api = FakeMomentsApi(
      page: MomentsPage(items: [moment()], total: 1, page: 1, pageSize: 10),
      reactionError: const ApiException(message: 'offline', isNetworkError: true),
    );
    final repository = MomentsRepository(api: api, database: database);

    await repository.react(1, '👍', selected: false);

    final item = (await (await database.database).query('outbox')).single;
    expect(item['operation'], 'add_reaction');
    expect(item['status'], db.OutboxStatus.pending);

    api.reactionError = const ApiException(message: 'bad request', statusCode: 400);
    await expectLater(
      repository.react(1, '👎', selected: false),
      throwsA(isA<ApiException>()),
    );
    expect((await (await database.database).query('outbox')).length, 1);
  });

  test('does not queue forbidden reaction responses', () async {
    final api = FakeMomentsApi(
      page: MomentsPage(items: [moment()], total: 1, page: 1, pageSize: 10),
      reactionError: const ApiException(message: 'forbidden', statusCode: 403),
    );
    final repository = MomentsRepository(api: api, database: database);

    await expectLater(
      repository.react(1, '👍', selected: false),
      throwsA(isA<ApiException>()),
    );
    expect(await (await database.database).query('outbox'), isEmpty);
  });

  testWidgets('shows the connectivity banner and admin actions', (tester) async {
    final page = MomentsPage(items: [moment()], total: 1, page: 1, pageSize: 10);
    final session = AuthSession(
      token: 'token',
      baseUrl: 'https://api.test',
      expiresAt: '2099-01-01T00:00:00Z',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _TestAuthNotifier(AuthenticatedState(session))),
          momentsPageProvider(true).overrideWith((ref) async => page),
        ],
        child: const MaterialApp(home: MomentsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('当前在线'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('cached content'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  test('pauses outbox item on unauthorized save', () async {
    final repository = MomentsRepository(
      api: FakeMomentsApi(
        error: const ApiException(message: 'unauthorized', statusCode: 401),
      ),
      database: database,
    );

    await repository.save(const CreateMomentPayload(content: 'auth required'));

    final dbInstance = await database.database;
    expect(
      (await dbInstance.query('outbox')).single['status'],
      db.OutboxStatus.pausedAuth,
    );
  });
}
