import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../data/db/app_database.dart';
import 'friend_links_api.dart';

class FriendLinksRepository {
  const FriendLinksRepository({required this.api, required this.database});
  final FriendLinksApi api;
  final AppDatabase database;

  Future<FriendLinksPage> load({required bool admin, int page = 1, int pageSize = 20, String? status}) async {
    final db = await database.database;
    final key = _key(admin, page, pageSize, status);
    final cached = await db.query('friend_link_cache', where: 'cache_key = ?', whereArgs: [key], limit: 1);
    if (cached.isNotEmpty) {
      final result = FriendLinksPage.fromJson(jsonDecode(cached.single['payload']! as String) as Map<String, dynamic>);
      _refresh(key, admin: admin, page: page, pageSize: pageSize, status: status);
      return result;
    }
    final result = await api.list(admin: admin, page: page, pageSize: pageSize, status: status);
    await _write(key, result);
    return result;
  }

  Future<void> create(FriendLinkPayload payload) async { await api.create(payload); await _clear(); }
  Future<void> update(int id, FriendLinkPayload payload) async { await api.update(id, payload); await _clear(); }
  Future<void> delete(int id) async { await api.delete(id); await _clear(); }
  Future<void> setGroups(int id, List<int> ids) async { await api.setGroups(id, ids); await _clear(); }
  Future<void> createGroup(String name, String description) async { await api.createGroup(name, description); await _clear(); }

  Future<void> _refresh(String key, {required bool admin, required int page, required int pageSize, String? status}) async {
    try { await _write(key, await api.list(admin: admin, page: page, pageSize: pageSize, status: status)); } catch (_) {}
  }
  Future<void> _write(String key, FriendLinksPage page) async {
    final db = await database.database;
    await db.insert('friend_link_cache', {'cache_key': key, 'payload': jsonEncode({'items': page.items.map((item) => item.toJson()).toList(), 'total': page.total, 'page': page.page, 'page_size': page.pageSize},), 'updated_at': DateTime.now().millisecondsSinceEpoch}, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<void> _clear() async => (await database.database).delete('friend_link_cache');
  String _key(bool admin, int page, int size, String? status) => '${admin ? 'admin' : 'public'}:$page:$size:${status ?? ''}';
}
