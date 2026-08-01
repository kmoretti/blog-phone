import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blog_phone/core/storage/secure_store.dart';
import 'package:blog_phone/data/api/api_client.dart';
import 'package:blog_phone/features/images/data/images_api.dart';

class ImageAdapter implements HttpClientAdapter {
  ImageAdapter(this.body);
  final String body;
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async { request = options; return ResponseBody.fromString(body, 200, headers: {Headers.contentTypeHeader: ['application/json']}); }
  @override
  void close({bool force = false}) {}
}

void main() {
  test('lists public images and supports admin mutations', () async {
    final adapter = ImageAdapter('{"code":200,"data":{"items":[{"id":1,"name":"Cover","url":"https://img.test/a.png","local_path":"","is_local":0,"is_oss":0,"status":"normal"}],"total":1,"page":1,"page_size":20}}');
    final api = ImagesApi(ApiClient(baseUrl: 'https://api.test', store: MemorySecureStore({'jwt': 'token'}), dio: Dio()..httpClientAdapter = adapter));
    final page = await api.list();
    expect(page.items.single.url, 'https://img.test/a.png');
    expect(
      adapter.request?.uri.toString(),
      'https://api.test/api/action/image?page=1&page_size=20',
    );
    await api.create(const ImagePayload(name: 'New', url: 'https://img.test/b.png'));
    expect(adapter.request?.uri.toString(), 'https://api.test/api/action/image');
    expect(adapter.request?.method, 'POST');
    await api.update(1, const ImagePayload(name: 'Updated'));
    expect(
      adapter.request?.uri.toString(),
      'https://api.test/api/action/image/1',
    );
    expect(adapter.request?.method, 'PUT');
    await api.delete(1);
    expect(adapter.request?.uri.toString(), 'https://api.test/api/action/image/1');

    await api.publicImage();
    expect(
      adapter.request?.uri.toString(),
      'https://api.test/api/public/image/?type=metadata',
    );
    await api.publicImage(id: 1);
    expect(
      adapter.request?.uri.toString(),
      'https://api.test/api/public/image/1?type=metadata',
    );
  });
}
