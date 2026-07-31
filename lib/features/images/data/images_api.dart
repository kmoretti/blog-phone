import '../../../data/api/api_client.dart';

class ImageDto {
  const ImageDto({required this.id, required this.name, required this.url, required this.localPath, required this.isLocal, required this.isOss, required this.status});
  final int id, isLocal, isOss;
  final String name, url, localPath, status;
  factory ImageDto.fromJson(Map<String, dynamic> json) => ImageDto(id: _int(json['id']), name: _string(json['name']), url: _string(json['url']), localPath: _string(json['local_path']), isLocal: _int(json['is_local']), isOss: _int(json['is_oss']), status: _string(json['status']));
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'url': url, 'local_path': localPath, 'is_local': isLocal, 'is_oss': isOss, 'status': status};
}

class ImagePage { const ImagePage({required this.items, required this.total, required this.page, required this.pageSize}); final List<ImageDto> items; final int total, page, pageSize; }
class ImagePayload {
  const ImagePayload({this.name, this.url, this.localPath, this.isLocal, this.isOss, this.status});
  final String? name, url, localPath, status;
  final int? isLocal, isOss;
  Map<String, dynamic> toJson() => {if (name != null) 'name': name, if (url != null) 'url': url, if (localPath != null) 'local_path': localPath, if (isLocal != null) 'is_local': isLocal, if (isOss != null) 'is_oss': isOss, if (status != null) 'status': status};
}
class ImagesApi {
  const ImagesApi(this.client);
  final ApiClient client;
  Future<ImagePage> list({int page = 1, int pageSize = 20, String? status, String? search}) async { final body = await client.get('action/image', queryParameters: {'page': page, 'page_size': pageSize, 'status': ?status, 'search': ?search}); final json = Map<String, dynamic>.from(body['data'] as Map); return ImagePage(items: _maps(json['items']).map(ImageDto.fromJson).toList(), total: _int(json['total']), page: _int(json['page']), pageSize: _int(json['page_size'])); }
  Future<void> create(ImagePayload payload) => client.post('action/image', data: payload.toJson());
  Future<void> update(int id, ImagePayload payload) => client.put('action/image/$id', data: payload.toJson());
  Future<void> delete(int id) => client.delete('action/image/$id');
  Future<ImageDto> publicImage({int? id}) async { final body = await client.get(id == null ? 'public/image' : 'public/image/$id', queryParameters: {'type': 'metadata'}); return ImageDto.fromJson(Map<String, dynamic>.from(body['data'] as Map? ?? body as Map)); }
}
int _int(Object? value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
String _string(Object? value) => value?.toString() ?? '';
List<Map<String, dynamic>> _maps(Object? value) => value is List ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];
