import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blog_phone/core/storage/secure_store.dart';
import 'package:blog_phone/data/api/api_client.dart';
import 'package:blog_phone/features/moments/data/moment_upload.dart';
import 'package:blog_phone/features/moments/data/moments_api.dart';

class MomentUploadAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    final isLocal = options.uri.path.endsWith('/action/resource/local');
    return ResponseBody.fromString(
      '{"code":200,"data":{"url":"${isLocal ? '/moments/local.jpg' : 'https://cdn.test/oss.jpg'}","objectKey":"moments/260731/asset.jpg"}}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('exposes upload targets and validates supported media', () {
    expect(MomentUploadTarget.local.endpoint, 'action/resource/local');
    expect(MomentUploadTarget.oss.endpoint, 'action/resource/oss');
    expect(validateMomentUploadFile('photo.jpg', 64 * 1024 * 1024), isNull);
    expect(validateMomentUploadFile('clip.mp4', 1), isNull);
    expect(validateMomentUploadFile('clip.mov', 1), isNotNull);
    expect(
      validateMomentUploadFile('clip.mp4', 64 * 1024 * 1024 + 1),
      isNotNull,
    );
  });

  test('resolves relative media URLs against the API host', () {
    expect(
      resolveMomentMediaUrl('https://host/api', '/moments/a.jpg'),
      'https://host/moments/a.jpg',
    );
    expect(
      resolveMomentMediaUrl('https://host/api/', 'moments/a.jpg'),
      'https://host/moments/a.jpg',
    );
    expect(
      resolveMomentMediaUrl('https://host/api', 'https://cdn.test/a.jpg'),
      'https://cdn.test/a.jpg',
    );
  });

  test(
    'uploads multipart media to the selected target and parses the result',
    () async {
      final file = await File(
        '${Directory.systemTemp.path}/moment-upload.jpg',
      ).writeAsString('image');
      final adapter = MomentUploadAdapter();
      final api = MomentsApi(
        client: ApiClient(
          baseUrl: 'https://api.test',
          store: MemorySecureStore({'jwt': 'token'}),
          dio: Dio()..httpClientAdapter = adapter,
        ),
      );

      final result = await api.uploadMomentMedia(
        filePath: file.path,
        target: MomentUploadTarget.local,
        uploadPath: 'moments/260731',
      );

      expect(result.url, '/moments/local.jpg');
      expect(result.isLocal, isTrue);
      expect(result.objectKey, 'moments/260731/asset.jpg');
      expect(adapter.request?.method, 'POST');
      expect(adapter.request?.uri.path, '/api/action/resource/local');
      expect(adapter.request?.data, isA<FormData>());
      final form = adapter.request!.data as FormData;
      expect(
        form.fields.where((entry) => entry.key == 'path').single.value,
        'moments/260731',
      );
      expect(
        form.fields.where((entry) => entry.key == 'overwrite').single.value,
        'false',
      );
      expect(form.files.single.key, 'file');

      final ossResult = await api.uploadMomentMedia(
        filePath: file.path,
        target: MomentUploadTarget.oss,
        uploadPath: 'moments/260731',
      );
      expect(ossResult.url, 'https://cdn.test/oss.jpg');
      expect(ossResult.isLocal, isFalse);
      expect(adapter.request?.uri.path, '/api/action/resource/oss');
    },
  );
}
