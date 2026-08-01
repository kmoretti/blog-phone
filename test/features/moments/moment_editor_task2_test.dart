import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:blog_phone/data/api/api_client.dart';
import 'package:blog_phone/data/api/api_exception.dart';
import 'package:blog_phone/core/storage/secure_store.dart';
import 'package:blog_phone/data/db/app_database.dart';
import 'package:blog_phone/features/moments/data/moments_api.dart';
import 'package:blog_phone/features/moments/data/moment_upload.dart';
import 'package:blog_phone/features/moments/data/moments_provider.dart';
import 'package:blog_phone/features/moments/data/moments_repository.dart';
import 'package:blog_phone/features/moments/presentation/moment_editor_screen.dart';

class _FailingApi extends MomentsApi {
  _FailingApi()
    : super(
        client: ApiClient(
          baseUrl: 'https://invalid.local',
          store: MemorySecureStore(),
        ),
      );

  int deleteMediaCalls = 0;
  final deletedMediaIds = <int>[];
  int createMediaCalls = 0;
  CreateMediaPayload? createdMedia;
  bool failDelete = true;
  bool failCreate = true;

  @override
  Future<void> update(int id, UpdateMomentPayload payload) async {}

  @override
  Future<void> deleteMedia(int id) async {
    deleteMediaCalls++;
    deletedMediaIds.add(id);
    if (failDelete) throw const ApiException(message: '删除媒体失败');
  }

  @override
  Future<void> createMedia(int momentId, CreateMediaPayload media) async {
    createMediaCalls++;
    createdMedia = media;
    if (failCreate) throw const ApiException(message: '添加媒体失败');
  }
}

class _UploadApi extends MomentsApi {
  _UploadApi()
    : super(
        client: ApiClient(
          baseUrl: 'https://invalid.local',
          store: MemorySecureStore(),
        ),
      );

  final uploadedPaths = <String>[];
  int createCalls = 0;
  int createMediaCalls = 0;
  final createdMedia = <CreateMediaPayload>[];
  CreateMomentPayload? createdPayload;
  bool failUpload = false;

  @override
  Future<void> createMedia(int momentId, CreateMediaPayload media) async {
    createMediaCalls++;
    createdMedia.add(media);
  }

  @override
  Future<MomentUploadResult> uploadMomentMedia({
    required String filePath,
    required MomentUploadTarget target,
    required String uploadPath,
  }) async {
    uploadedPaths.add(filePath);
    if (failUpload) throw const ApiException(message: '上传失败');
    return MomentUploadResult(
      url: 'https://cdn.example/${filePath.split('/').last}',
      isLocal: target.isLocal,
    );
  }

  @override
  Future<void> create(CreateMomentPayload payload) async {
    createCalls++;
    createdPayload = payload;
  }
}

class _UploadRepository extends MomentsRepository {
  _UploadRepository(this.uploadApi, AppDatabase database)
    : super(api: uploadApi, database: database);

  final _UploadApi uploadApi;
  int saveCalls = 0;
  CreateMomentPayload? savedPayload;

  @override
  Future<void> save(CreateMomentPayload payload) async {
    saveCalls++;
    savedPayload = payload;
    await uploadApi.create(payload);
  }
}

class _FailingRepository extends MomentsRepository {
  _FailingRepository(this.fakeApi, AppDatabase database)
    : super(api: fakeApi, database: database);

  final _FailingApi fakeApi;
  int saveCalls = 0;
  bool failSave = true;
  final completer = Completer<void>();

  @override
  Future<void> save(CreateMomentPayload payload) async {
    saveCalls++;
    if (saveCalls == 1) await completer.future;
    if (failSave) throw const ApiException(message: '保存失败');
  }
}

void main() {
  late AppDatabase database;
  late String databasePath;

  setUp(() {
    sqfliteFfiInit();
    databasePath = inMemoryDatabasePath;
    database = AppDatabase(
      factory: databaseFactoryFfi,
      databasePathProvider: () async => databasePath,
    );
  });

  tearDown(() async => database.close());

  testWidgets('uploads selected local media before creating a moment', (
    tester,
  ) async {
    final file = File('${Directory.systemTemp.path}/new.jpg');
    file.writeAsStringSync('image');
    expect(file.existsSync(), isTrue);
    final api = _UploadApi();
    final repository = _UploadRepository(api, database);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [momentsRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: MomentEditorScreen(pickFile: () async => file.path),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('moment-attach-file')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('moment-attach-file')));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pump();
    expect(find.text(file.path), findsOneWidget);
    await tester.enterText(find.byKey(const Key('moment-content')), 'hello');
    await tester.enterText(find.byKey(const Key('moment-pinned-order')), '0');
    await tester.scrollUntilVisible(
      find.text('保存'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('moment-save')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

    expect(api.uploadedPaths, [file.path]);
    expect(api.createCalls, 1);
    expect(api.createMediaCalls, 0);
    expect(api.createdPayload?.media.single.toJson(), {
      'media_url': 'https://cdn.example/new.jpg',
      'media_type': 'image',
      'is_local': 1,
      'name': 'new.jpg',
    });
  });

  testWidgets('does not create and keeps local media when upload fails', (
    tester,
  ) async {
    final file = File('${Directory.systemTemp.path}/failed.jpg');
    file.writeAsStringSync('image');
    final api = _UploadApi()..failUpload = true;
    final repository = _UploadRepository(api, database);
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [momentsRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: MomentEditorScreen(pickFile: () async => file.path),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('moment-attach-file')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('moment-attach-file')));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pump();
    expect(find.text(file.path), findsOneWidget);
    await tester.enterText(find.byKey(const Key('moment-content')), 'hello');
    await tester.enterText(find.byKey(const Key('moment-pinned-order')), '0');
    await tester.scrollUntilVisible(
      find.text('保存'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('moment-save')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

    expect(api.createCalls, 0);
    expect(api.uploadedPaths, [file.path]);
    expect(find.textContaining('上传失败'), findsOneWidget);
  });

  testWidgets(
    'shows saving state, prevents duplicate submits, and keeps retry after failure',
    (tester) async {
      final repository = _FailingRepository(_FailingApi(), database);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [momentsRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: MomentEditorScreen()),
        ),
      );

      await tester.enterText(find.byKey(const Key('moment-content')), 'hello');
      await tester.enterText(find.byKey(const Key('moment-pinned-order')), '0');
      await tester.scrollUntilVisible(
        find.text('保存'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final saveButton = find.ancestor(
        of: find.text('保存'),
        matching: find.byType(FilledButton),
      );
      await tester.tap(saveButton);
      await tester.tap(saveButton, warnIfMissed: false);
      repository.completer.complete();
      await tester.pumpAndSettle();

      expect(repository.saveCalls, 1);
      expect(find.text('保存失败'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
    },
  );

  testWidgets('adds uploaded media through createMedia when editing', (
    tester,
  ) async {
    final file = await File(
      '${Directory.systemTemp.path}/edited.jpg',
    ).writeAsString('image');
    final api = _UploadApi();
    final repository = _UploadRepository(api, database);
    const moment = MomentDto(
      id: 7,
      content: 'hello',
      tags: '',
      pinnedOrder: 0,
      isAd: 0,
      extension: '',
      status: 'visible',
      messageLink: '',
      createdAt: 1,
      updatedAt: 1,
      media: [],
      reactions: {},
      selectedReaction: null,
    );
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [momentsRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: MomentEditorScreen(
            moment: moment,
            pickFile: () async => file.path,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('moment-attach-file')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('moment-save')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('moment-save')));
    await tester.pumpAndSettle();

    expect(api.createCalls, 0);
    expect(api.createMediaCalls, 1);
    expect(api.createdMedia.single.toJson(), {
      'media_url': 'https://cdn.example/edited.jpg',
      'media_type': 'image',
      'is_local': 1,
      'name': 'edited.jpg',
    });
  });

  testWidgets(
    'successfully deletes existing media and creates external media',
    (tester) async {
      final api = _FailingApi()
        ..failDelete = false
        ..failCreate = false;
      final repository = MomentsRepository(api: api, database: database);
      const moment = MomentDto(
        id: 7,
        content: 'hello',
        tags: '',
        pinnedOrder: 0,
        isAd: 0,
        extension: '',
        status: 'visible',
        messageLink: '',
        createdAt: 1,
        updatedAt: 1,
        media: [
          MomentMediaDto(
            id: 8,
            momentId: 7,
            name: 'old.jpg',
            mediaUrl: 'https://cdn.example/old.jpg',
            mediaType: 'image',
            isLocal: 0,
            isDeleted: 0,
          ),
          MomentMediaDto(
            id: 9,
            momentId: 7,
            name: 'keep.jpg',
            mediaUrl: 'https://cdn.example/keep.jpg',
            mediaType: 'image',
            isLocal: 0,
            isDeleted: 0,
          ),
        ],
        reactions: {},
        selectedReaction: null,
      );

      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [momentsRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: MomentEditorScreen(moment: moment)),
        ),
      );
      await tester.scrollUntilVisible(
        find.byTooltip('外链图片'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byTooltip('外链图片'));
      await tester.pump();
      await tester.enterText(
        find.byType(TextField).last,
        'https://cdn.example/new.jpg',
      );
      await tester.tap(find.widgetWithText(FilledButton, '添加'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pump();
      expect(find.text('https://cdn.example/keep.jpg'), findsOneWidget);
      expect(find.text('https://cdn.example/old.jpg'), findsNothing);
      await tester.tap(find.byKey(const Key('moment-save')));
      await tester.pumpAndSettle();

      expect(api.deleteMediaCalls, 1);
      expect(api.deletedMediaIds, [8]);
      expect(api.createMediaCalls, 1);
      expect(api.createdMedia?.toJson(), {
        'media_url': 'https://cdn.example/new.jpg',
        'media_type': 'image',
        'is_local': 0,
      });
    },
  );

  testWidgets(
    'keeps external media and existing deletion visible after API failures',
    (tester) async {
      final api = _FailingApi();
      final repository = MomentsRepository(api: api, database: database);
      const moment = MomentDto(
        id: 7,
        content: 'hello',
        tags: '',
        pinnedOrder: 0,
        isAd: 0,
        extension: '',
        status: 'visible',
        messageLink: '',
        createdAt: 1,
        updatedAt: 1,
        media: [
          MomentMediaDto(
            id: 8,
            momentId: 7,
            name: 'old.jpg',
            mediaUrl: 'https://cdn.example/old.jpg',
            mediaType: 'image',
            isLocal: 0,
            isDeleted: 0,
          ),
        ],
        reactions: {},
        selectedReaction: null,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [momentsRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: MomentEditorScreen(moment: moment)),
        ),
      );

      await tester.scrollUntilVisible(
        find.byTooltip('外链图片'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byTooltip('外链图片'));
      await tester.pump();
      await tester.enterText(
        find.byType(TextField).last,
        'https://cdn.example/new.jpg',
      );
      await tester.tap(find.widgetWithText(FilledButton, '添加'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pump();
      await tester.tap(find.byKey(const Key('moment-save')));
      await tester.pump();

      expect(find.text('https://cdn.example/new.jpg'), findsOneWidget);
      expect(find.text('https://cdn.example/old.jpg'), findsOneWidget);
      expect(find.text('删除媒体失败'), findsOneWidget);
      expect(api.deleteMediaCalls, 1);
      expect(api.createMediaCalls, 0);
    },
  );
}
