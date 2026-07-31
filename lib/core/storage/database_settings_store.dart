import 'package:sqflite/sqflite.dart';

import '../../data/db/app_database.dart';
import 'secure_store.dart';

class DatabaseSettingsStore implements SettingsStore {
  DatabaseSettingsStore(this.appDatabase);
  final AppDatabase appDatabase;

  Future<Database> get _database => appDatabase.database;

  @override
  Future<String?> read(String key) async {
    final rows = await (await _database).query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  @override
  Future<void> write(String key, String value) async {
    await (await _database).insert('app_settings', {
      'key': key,
      'value': value,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> delete(String key) async {
    await (await _database).delete(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
  }
}
