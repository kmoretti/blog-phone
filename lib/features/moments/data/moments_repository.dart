import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../data/db/app_database.dart';
import '../../../data/db/models.dart' as db;
import '../../../data/db/outbox_dao.dart';
import '../../../data/api/api_exception.dart';
import 'moments_api.dart';

class MomentsRepository {
  MomentsRepository({required this.api, required this.database});
  final MomentsApi api;
  final AppDatabase database;

  Future<MomentsPage> load({
    int page = 1,
    int pageSize = 10,
    bool admin = false,
  }) async {
    final dbInstance = await database.database;
    final cached = await _readCache(dbInstance, page, pageSize, admin);
    if (cached != null) {
      unawaited(_refresh(dbInstance, page, pageSize, admin));
      return cached;
    }
    final remote = await api.list(page: page, pageSize: pageSize, admin: admin);
    await _writeCache(
      dbInstance,
      remote,
      admin: admin,
      page: page,
      pageSize: pageSize,
    );
    return remote;
  }

  Future<void> _refresh(
    Database dbInstance,
    int page,
    int pageSize,
    bool admin,
  ) async {
    try {
      final remote = await api.list(
        page: page,
        pageSize: pageSize,
        admin: admin,
      );
      await _writeCache(
        dbInstance,
        remote,
        admin: admin,
        page: page,
        pageSize: pageSize,
      );
    } on ApiException {
      return;
    }
  }

  Future<void> react(
    int momentId,
    String reaction, {
    required bool selected,
  }) async {
    try {
      if (selected) {
        await api.removeReaction(momentId, reaction);
      } else {
        await api.addReaction(momentId, reaction);
      }
    } on ApiException catch (error) {
      if (error.isUnauthorized) rethrow;
      if (!error.isRetryable) rethrow;
      final instance = await database.database;
      final now = DateTime.now().toUtc().toIso8601String();
      await OutboxDao(instance).insert(
        db.OutboxItem(
          id: 'reaction-$momentId-$reaction',
          operation: selected ? 'remove_reaction' : 'add_reaction',
          payload: jsonEncode({'moment_id': momentId, 'reaction': reaction}),
          status: db.OutboxStatus.pending,
          createdAt: now,
        ),
      );
    }
  }

  Future<void> save(CreateMomentPayload payload) async {
    try {
      if (payload.media.any((media) => media.isLocal == 1)) {
        throw const ApiException(
          message: '本地媒体尚未上传，已保存为草稿',
          preservesDraft: true,
        );
      }
      await api.create(payload);
    } catch (error) {
      final apiError = error is ApiException ? error : null;
      final now = DateTime.now().millisecondsSinceEpoch;
      final status = apiError?.isUnauthorized == true
          ? db.OutboxStatus.pausedAuth
          : apiError?.isRetryable == true
          ? db.OutboxStatus.pending
          : 'draft';
      final draft = db.Draft(
        id: 'moment-$now',
        content: payload.content,
        status: status,
        mediaJson: jsonEncode(payload.toJson()['media']),
        createdAt: now,
        updatedAt: now,
      );
      final instance = await database.database;
      final outboxStatus = apiError?.isRetryable == true
          ? db.OutboxStatus.pending
          : apiError?.isUnauthorized == true
          ? db.OutboxStatus.pausedAuth
          : null;
      await instance.transaction((txn) async {
        await txn.insert(
          'drafts',
          draft.toRow(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        if (outboxStatus != null) {
          await txn.insert(
            'outbox',
            db.OutboxItem(
              id: draft.id,
              operation: 'create_moment',
              payload: jsonEncode(payload.toJson()),
              status: outboxStatus,
              createdAt: DateTime.now().toUtc().toIso8601String(),
            ).toRow(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
      if (apiError?.preservesDraft == true || apiError?.isRetryable == false) {
        return;
      }
    }
  }

  Future<MomentsPage?> _readCache(
    Database dbInstance,
    int page,
    int pageSize,
    bool admin,
  ) async {
    final scope = admin ? 'admin' : 'guest';
    final rows = await dbInstance.query(
      'moments',
      where:
          'cache_scope = ? AND cache_page = ? AND cache_page_size = ? AND (? = 1 OR status = ?)',
      whereArgs: [scope, page, pageSize, admin ? 1 : 0, 'visible'],
      orderBy: 'created_at DESC',
      limit: pageSize,
      offset: 0,
    );
    if (rows.isEmpty) return null;
    final mediaRows = await dbInstance.query(
      'moment_media',
      where: 'cache_scope = ? AND cache_page = ? AND cache_page_size = ?',
      whereArgs: [scope, page, pageSize],
    );
    final reactionRows = await dbInstance.query(
      'moment_reactions',
      where: 'cache_scope = ? AND cache_page = ? AND cache_page_size = ?',
      whereArgs: [scope, page, pageSize],
    );
    final items = rows.map((row) {
      final json = Map<String, dynamic>.from(row);
      final id = row['id'].toString();
      json['media'] = mediaRows
          .where((media) => media['moment_id'].toString() == id)
          .map((media) => media.cast<String, dynamic>())
          .toList();
      final counts = <String, int>{};
      for (final reaction in reactionRows.where(
        (item) => item['moment_id'].toString() == id,
      )) {
        final key = reaction['reaction'].toString();
        counts[key] = (counts[key] ?? 0) + 1;
      }
      json['reactions'] = counts;
      final selected = reactionRows.cast<Map<String, Object?>>().where(
        (item) =>
            item['moment_id'].toString() == id && item['fingerprint_id'] != 0,
      );
      if (selected.isNotEmpty) {
        json['selected_reaction'] = selected.first['reaction'];
      }
      return MomentDto.fromJson(json);
    }).toList();
    return MomentsPage(
      items: items,
      total: rows.length,
      page: page,
      pageSize: pageSize,
    );
  }

  Future<void> _writeCache(
    Database dbInstance,
    MomentsPage resultPage, {
    required bool admin,
    required int page,
    required int pageSize,
  }) async {
    await dbInstance.transaction((txn) async {
      for (final item in resultPage.items) {
        await txn.insert('moments', {
          'id': item.id.toString(),
          'content': item.content,
          'tags': item.tags,
          'pinned_order': item.pinnedOrder,
          'is_ad': item.isAd,
          'extension': item.extension,
          'status': item.status,
          'message_link': item.messageLink,
          'created_at': item.createdAt,
          'updated_at': item.updatedAt,
          'cache_scope': admin ? 'admin' : 'guest',
          'cache_page': page,
          'cache_page_size': pageSize,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await txn.delete(
          'moment_media',
          where:
              'moment_id = ? AND cache_scope = ? AND cache_page = ? AND cache_page_size = ?',
          whereArgs: [
            item.id.toString(),
            admin ? 'admin' : 'guest',
            page,
            pageSize,
          ],
        );
        for (final media in item.media) {
          await txn.insert('moment_media', {
            ...media.toJson(),
            'moment_id': media.momentId.toString(),
            'cache_scope': admin ? 'admin' : 'guest',
            'cache_page': page,
            'cache_page_size': pageSize,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await txn.delete(
          'moment_reactions',
          where:
              'moment_id = ? AND cache_scope = ? AND cache_page = ? AND cache_page_size = ?',
          whereArgs: [
            item.id.toString(),
            admin ? 'admin' : 'guest',
            page,
            pageSize,
          ],
        );
        var reactionId = 1;
        for (final entry in item.reactions.entries) {
          await txn.insert('moment_reactions', {
            'id': item.id * 1000 + reactionId++,
            'moment_id': item.id.toString(),
            'fingerprint_id': 0,
            'reaction': entry.key,
            'created_at': item.updatedAt,
            'cache_scope': admin ? 'admin' : 'guest',
            'cache_page': page,
            'cache_page_size': pageSize,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }
}
