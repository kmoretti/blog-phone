import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blog_phone/features/moments/presentation/moment_extension.dart';

void main() {
  test('parses a supported extension with its generic fields and payload', () {
    final extension = MomentExtension.fromJsonString(
      '{"type":"github","payload":{"repo_url":"https://github.com/example/repo"}}',
    );

    expect(extension, isA<GithubMomentExtension>());
    expect(extension!.type, 'github');
    expect(extension.isKnown, isTrue);
    expect(extension.payload, {'repo_url': 'https://github.com/example/repo'});
    expect((extension as GithubMomentExtension).repoUrl, 'https://github.com/example/repo');
  });

  test('retains unknown extension type and original payload', () {
    final extension = MomentExtension.fromJsonString(
      '{"type":"future","payload":{"label":"Preview","count":2}}',
    );

    expect(extension, isA<UnknownMomentExtension>());
    expect(extension!.type, 'future');
    expect(extension.isKnown, isFalse);
    expect(extension.payload, {'label': 'Preview', 'count': 2});
  });

  test('parses music song and artist fields', () {
    final extension = MomentExtension.fromJsonString(
      '{"type":"music","payload":{"url":"https://music.example.com/song","song":"夜に駆ける","artist":"YOASOBI"}}',
    )! as MusicMomentExtension;

    expect(extension.title, '夜に駆ける');
    expect(extension.artist, 'YOASOBI');
  });

  testWidgets('shows tweet text in the extension card', (tester) async {
    final extension = MomentExtension.fromJsonString(
      '{"type":"tweet","payload":{"url":"https://x.com/user/status/1","username":"user","status_id":"1","text":"Hello from X"}}',
    )!;

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: MomentExtensionCard(extension: extension))),
    );

    expect(find.text('Hello from X'), findsOneWidget);
  });

  test('accepts only legal http and https links', () {
    expect(isHttpUrl('https://example.com/path'), isTrue);
    expect(isHttpUrl('http://localhost:8080/source'), isTrue);
    expect(isHttpUrl('javascript:alert(1)'), isFalse);
    expect(isHttpUrl('ftp://example.com/file'), isFalse);
    expect(isHttpUrl('/relative/source'), isFalse);
    expect(isHttpUrl('https://'), isFalse);
  });

  test('returns null for empty, malformed, and invalid supported extensions', () {
    expect(parseMomentExtension(null), isNull);
    expect(parseMomentExtension(''), isNull);
    expect(parseMomentExtension('not-json'), isNull);
    expect(parseMomentExtension('{"type":"github","payload":{}}'), isNull);
  });

  test('rejects non-http extension links while parsing', () {
    expect(
      parseMomentExtension('{"type":"github","payload":{"repo_url":"javascript:alert(1)"}}'),
      isNull,
    );
    expect(
      parseMomentExtension('{"type":"website","payload":{"title":"Unsafe","site":"ftp://example.com"}}'),
      isNull,
    );
    expect(
      parseMomentExtension('{"type":"music","payload":{"url":"/relative/song"}}'),
      isNull,
    );
    expect(
      parseMomentExtension('{"type":"tweet","payload":{"url":"data:text/plain,unsafe","username":"user","status_id":"1"}}'),
      isNull,
    );
  });
}
