import 'package:sqflite/sqflite.dart';

import 'models.dart';

class OutboxDao {
  const OutboxDao(this.database);
  final Database database;
  static const _validStatuses = <String>{
    OutboxStatus.pending,
    OutboxStatus.processing,
    OutboxStatus.failed,
    OutboxStatus.pausedAuth,
    OutboxStatus.completed,
  };

  Future<String> insert(OutboxItem item) async {
    if (!_validStatuses.contains(item.status)) {
      throw ArgumentError.value(item.status, 'status');
    }
    await database.insert(
      'outbox',
      item.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return item.id;
  }

  Future<OutboxItem?> get(String id) async {
    final rows = await database.query(
      'outbox',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : OutboxItem.fromRow(rows.first);
  }

  Future<List<OutboxItem>> pending({
    int limit = 50,
    int offset = 0,
    bool includePaused = false,
  }) => _list(
    includePaused
        ? [OutboxStatus.pending, OutboxStatus.failed, OutboxStatus.pausedAuth]
        : [OutboxStatus.pending, OutboxStatus.failed],
    limit: limit,
    offset: offset,
  );

  Future<List<OutboxItem>> claimProcessing({int limit = 50}) async {
    return database.transaction((txn) async {
      final rows = await txn.query(
        'outbox',
        where: 'status IN (?, ?)',
        whereArgs: [OutboxStatus.pending, OutboxStatus.failed],
        orderBy: 'created_at ASC',
        limit: limit,
      );
      final now = DateTime.now().toUtc().toIso8601String();
      final claimed = <OutboxItem>[];
      for (final row in rows) {
        final updated = await txn.update(
          'outbox',
          {'status': OutboxStatus.processing, 'updated_at': now},
          where: 'id = ? AND status IN (?, ?)',
          whereArgs: [row['id'], OutboxStatus.pending, OutboxStatus.failed],
        );
        if (updated == 1) {
          claimed.add(
            OutboxItem.fromRow({
              ...row,
              'status': OutboxStatus.processing,
              'updated_at': now,
            }),
          );
        }
      }
      return claimed;
    });
  }

  Future<bool> markSucceeded(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    return await database.update(
          'outbox',
          {
            'status': OutboxStatus.completed,
            'processed_at': now,
            'updated_at': now,
          },
          where: 'id = ? AND status = ?',
          whereArgs: [id, OutboxStatus.processing],
        ) ==
        1;
  }

  Future<bool> markFailed(String id, String error) async =>
      await database.rawUpdate(
        'UPDATE outbox SET status = ?, retry_count = retry_count + 1, last_error = ?, updated_at = ? WHERE id = ? AND status = ?',
        [
          OutboxStatus.failed,
          error,
          DateTime.now().toUtc().toIso8601String(),
          id,
          OutboxStatus.processing,
        ],
      ) ==
      1;

  Future<bool> retry(String id) async =>
      await database.update(
        'outbox',
        {
          'status': OutboxStatus.pending,
          'last_error': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ? AND status = ?',
        whereArgs: [id, OutboxStatus.failed],
      ) ==
      1;

  Future<bool> pauseAuth(String id) async =>
      await database.update(
        'outbox',
        {
          'status': OutboxStatus.pausedAuth,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ? AND status IN (?, ?, ?)',
        whereArgs: [
          id,
          OutboxStatus.pending,
          OutboxStatus.processing,
          OutboxStatus.failed,
        ],
      ) ==
      1;

  Future<int> recoverExpiredProcessing({
    Duration timeout = const Duration(minutes: 5),
    DateTime? now,
  }) async {
    final cutoff = (now ?? DateTime.now().toUtc())
        .subtract(timeout)
        .toIso8601String();
    return database.rawUpdate(
      'UPDATE outbox SET status = ?, retry_count = retry_count + 1, last_error = ?, updated_at = ? WHERE status = ? AND updated_at < ?',
      [
        OutboxStatus.failed,
        'processing lease expired',
        now?.toUtc().toIso8601String() ??
            DateTime.now().toUtc().toIso8601String(),
        OutboxStatus.processing,
        cutoff,
      ],
    );
  }

  Future<int> deleteSuccessful(String id) => database.delete(
    'outbox',
    where: 'id = ? AND status = ?',
    whereArgs: [id, OutboxStatus.completed],
  );
  Future<int> clearCompleted() => database.delete(
    'outbox',
    where: 'status = ?',
    whereArgs: [OutboxStatus.completed],
  );

  Future<List<OutboxItem>> _list(
    List<String> statuses, {
    required int limit,
    required int offset,
  }) async {
    final placeholders = List.filled(statuses.length, '?').join(', ');
    final rows = await database.query(
      'outbox',
      where: 'status IN ($placeholders)',
      whereArgs: statuses,
      orderBy: 'created_at ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map(OutboxItem.fromRow).toList();
  }
}
