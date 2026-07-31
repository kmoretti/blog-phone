import 'package:flutter_test/flutter_test.dart';

import 'package:blog_phone/features/moments/data/moments_api.dart';

void main() {
  test('builds an external image payload', () {
    final payload = buildExternalMediaPayload(
      'https://cdn.example/image.jpg',
      'image',
    );

    expect(payload.toJson(), {
      'media_url': 'https://cdn.example/image.jpg',
      'media_type': 'image',
      'is_local': 0,
    });
  });

  test('builds an external video payload', () {
    final payload = buildExternalMediaPayload(
      'https://cdn.example/video.mp4',
      'video',
    );

    expect(payload.toJson()['media_type'], 'video');
    expect(payload.toJson()['is_local'], 0);
  });

  test('rejects invalid external media URLs and types', () {
    expect(
      () => buildExternalMediaPayload('javascript:alert(1)', 'image'),
      throwsFormatException,
    );
    expect(
      () => buildExternalMediaPayload('ftp://cdn.example/file.jpg', 'image'),
      throwsFormatException,
    );
    expect(
      () => buildExternalMediaPayload('https://cdn.example/file.jpg', 'audio'),
      throwsFormatException,
    );
  });

  test('serializes external media in a newly created moment payload', () {
    const payload = CreateMomentPayload(
      content: 'new moment',
      media: [
        CreateMediaPayload(
          mediaUrl: 'https://cdn.example/new.jpg',
          mediaType: 'image',
          isLocal: 0,
        ),
      ],
    );

    expect(payload.toJson()['media'], [
      {
        'media_url': 'https://cdn.example/new.jpg',
        'media_type': 'image',
        'is_local': 0,
      },
    ]);
  });

  test('converts existing media to removable editor entries', () {
    const media = MomentMediaDto(
      id: 8,
      momentId: 7,
      name: 'image.jpg',
      mediaUrl: 'https://cdn.example/image.jpg',
      mediaType: 'image',
      isLocal: 0,
      isDeleted: 0,
    );

    final entry = MomentMediaEntry.fromDto(media);

    expect(entry.id, 8);
    expect(entry.url, media.mediaUrl);
    expect(entry.mediaType, 'image');
    expect(entry.isExisting, isTrue);
  });
}
