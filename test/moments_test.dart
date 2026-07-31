import 'package:flutter_test/flutter_test.dart';

import 'package:blog_phone/features/moments/data/moments_api.dart';

void main() {
  test('parses public paginated moments with media and reactions', () {
    final page = MomentsPage.fromJson({
      'items': [
        {
          'id': 7,
          'content': 'hello',
          'status': 'visible',
          'tags': 'dart,flutter',
          'pinned_order': 0,
          'is_ad': 0,
          'created_at': 100,
          'updated_at': 101,
          'media': [
            {
              'id': 8,
              'moment_id': 7,
              'media_url': 'https://example.com/a.jpg',
              'media_type': 'image',
              'is_local': 0,
              'is_deleted': 0,
            },
          ],
          'reactions': {'👍': 3},
          'selected_reaction': '👍',
        },
      ],
      'total': 1,
      'page': 1,
      'page_size': 10,
    });

    expect(page.items.single.id, 7);
    expect(page.items.single.media.single.mediaType, 'image');
    expect(page.items.single.reactions['👍'], 3);
    expect(page.items.single.selectedReaction, '👍');
  });

  test('creates only confirmed create fields', () {
    final payload = CreateMomentPayload(content: 'hello');

    expect(payload.toJson(), {'content': 'hello', 'media': <Object>[]});
  });
}
