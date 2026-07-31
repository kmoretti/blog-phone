import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'database_migrations.dart';
import 'outbox_dao.dart';

class AppDatabase {
  AppDatabase({
    DatabaseFactory? factory,
    Future<String> Function()? databasePathProvider,
  }) : _databaseFactory = factory,
       _databasePathProvider = databasePathProvider;

  final DatabaseFactory? _databaseFactory;
  final Future<String> Function()? _databasePathProvider;
  Database? _instance;

  Future<Database> get database async {
    if (_instance != null) return _instance!;
    final factory = _databaseFactory ?? databaseFactory;
    final directoryPath = _databasePathProvider == null
        ? (await getApplicationDocumentsDirectory()).path
        : await _databasePathProvider();
    final databasePath = directoryPath == inMemoryDatabasePath
        ? directoryPath
        : path.join(directoryPath, 'blog_phone.db');
    _instance = await factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onCreate: (db, _) => createDatabase(db),
        onUpgrade: migrateDatabase,
      ),
    );
    await OutboxDao(_instance!).recoverExpiredProcessing();
    return _instance!;
  }

  Future<int> recoverExpiredProcessing({
    Duration timeout = const Duration(minutes: 5),
    DateTime? now,
  }) async {
    return OutboxDao(
      await database,
    ).recoverExpiredProcessing(timeout: timeout, now: now);
  }

  Future<void> close() async {
    await _instance?.close();
    _instance = null;
  }
}
