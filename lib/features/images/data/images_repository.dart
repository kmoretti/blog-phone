import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../data/db/app_database.dart';
import 'images_api.dart';

class ImagesRepository {
  const ImagesRepository({required this.api, required this.database});
  final ImagesApi api;
  final AppDatabase database;
  Future<ImagePage> list({int page = 1, int pageSize = 20, String? status, String? search}) async {
    final key = '$page:$pageSize:${status ?? ''}:${search ?? ''}';
    final db = await database.database;
    final rows = await db.query('image_cache', where: 'cache_key = ?', whereArgs: [key]);
    if (rows.isNotEmpty) return _decode(jsonDecode(rows.single['payload']! as String));
    final result = await api.list(page: page, pageSize: pageSize, status: status, search: search);
    await db.insert('image_cache', {'cache_key': key, 'payload': jsonEncode({'items': result.items.map((e) => e.toJson()).toList(), 'total': result.total, 'page': result.page, 'page_size': result.pageSize},), 'updated_at': DateTime.now().millisecondsSinceEpoch}, conflictAlgorithm: ConflictAlgorithm.replace);
    return result;
  }
  Future<void> create(ImagePayload payload) async { await api.create(payload); await clear(); }
  Future<void> update(int id, ImagePayload payload) async { await api.update(id, payload); await clear(); }
  Future<void> delete(int id) async { await api.delete(id); await clear(); }
  Future<void> clear() => database.database.then((db) => db.delete('image_cache'));
  ImagePage _decode(Map<String, dynamic> json) => ImagePage(items: (json['items'] as List).map((e) => ImageDto.fromJson(Map<String, dynamic>.from(e as Map))).toList(), total: (json['total'] as num).toInt(), page: (json['page'] as num).toInt(), pageSize: (json['page_size'] as num).toInt());
}
