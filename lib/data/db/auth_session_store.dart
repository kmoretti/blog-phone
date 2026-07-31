import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'models.dart';

abstract interface class AuthSessionStore {
  Future<AuthSession?> read();
  Future<void> write(AuthSession session);
  Future<void> delete();
}

class DatabaseAuthSessionStore implements AuthSessionStore {
  DatabaseAuthSessionStore(this.appDatabase);
  final AppDatabase appDatabase;

  Future<Database> get _database => appDatabase.database;

  @override
  Future<AuthSession?> read() async {
    final rows = await (await _database).query(
      'auth_session',
      where: 'id = 1',
      limit: 1,
    );
    return rows.isEmpty ? null : AuthSession.fromRow(rows.first);
  }

  @override
  Future<void> write(AuthSession session) async {
    await (await _database).insert(
      'auth_session',
      session.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete() async {
    await (await _database).delete('auth_session', where: 'id = 1');
  }
}
