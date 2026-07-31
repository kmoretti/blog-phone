import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blog_phone/features/moments/presentation/moment_extension.dart';
import 'package:blog_phone/features/moments/presentation/moment_extension_editor.dart';

void main() {
  test('builds JSON for all five card types', () {
    expect(
      buildMomentExtensionJson(type: 'github', values: {'repo_url': 'https://github.com/u/r'}),
      '{"type":"github","payload":{"repo_url":"https://github.com/u/r"}}',
    );
    expect(buildMomentExtensionJson(type: 'website', values: {'title': '站点', 'site': 'https://example.com'}), contains('website'));
    expect(buildMomentExtensionJson(type: 'location', values: {'placeholder': '北京', 'latitude': 39.9, 'longitude': 116.4}), contains('location'));
    expect(buildMomentExtensionJson(type: 'music', values: {'url': 'https://music.example/a'}), contains('music'));
    expect(buildMomentExtensionJson(type: 'tweet', values: {'url': 'https://x.com/u/status/1', 'username': 'u', 'status_id': '1'}), contains('tweet'));
  });

  test('validates required fields, URLs, and coordinates', () {
    expect(MomentExtensionDraft(type: 'github').validate(), isNotEmpty);
    expect(MomentExtensionDraft(type: 'github', values: {'repo_url': 'javascript:alert(1)'}).validate(), isNotEmpty);
    expect(MomentExtensionDraft(type: 'location', values: {'placeholder': '北京', 'latitude': 91, 'longitude': 116}).validate(), isNotEmpty);
    expect(MomentExtensionDraft(type: 'location', values: {'placeholder': '北京', 'latitude': 39, 'longitude': -181}).validate(), isNotEmpty);
    expect(MomentExtensionDraft(type: 'website', values: {'title': '站点', 'site': 'https://example.com'}).validate(), isEmpty);
  });

  test('round trips known JSON fields', () {
    final draft = MomentExtensionDraft.fromJsonString(
      '{"type":"website","payload":{"title":"站点","site":"https://example.com"}}',
    );
    expect(draft.type, 'website');
    expect(draft.values['title'], '站点');
    expect(draft.values['site'], 'https://example.com');
    expect(jsonDecode(draft.toJsonString()), {
      'type': 'website',
      'payload': {'title': '站点', 'site': 'https://example.com'},
    });
  });

  test('retains unknown JSON in advanced mode', () {
    const raw = '{"type":"future","payload":{"label":"Preview","count":2}}';
    final draft = MomentExtensionDraft.fromJsonString(raw);
    expect(draft.isAdvanced, isTrue);
    expect(draft.toJsonString(), raw);
  });

  test('rejects non-finite coordinates', () {
    expect(
      MomentExtensionDraft(type: 'location', values: {
        'placeholder': '北京',
        'latitude': double.nan,
        'longitude': 116,
      }).validate(),
      isNotEmpty,
    );
    expect(
      MomentExtensionDraft(type: 'location', values: {
        'placeholder': '北京',
        'latitude': double.infinity,
        'longitude': 116,
      }).validate(),
      isNotEmpty,
    );
  });

  test('preserves known payload fields when saving edited fields', () {
    final draft = MomentExtensionDraft.fromJsonString(
      '{"type":"website","payload":{"title":"旧标题","site":"https://example.com","color":"blue"}}',
    );
    final next = MomentExtensionDraft(
      type: draft.type,
      values: {...draft.values, 'title': '新标题'},
    );
    expect(jsonDecode(next.toJsonString())['payload'], {
      'title': '新标题',
      'site': 'https://example.com',
      'color': 'blue',
    });
  });

  testWidgets('starts with an empty state and cancel does not change the controller', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MomentExtensionEditor(controller: controller))));
    expect(find.text('高级编辑'), findsOneWidget);
    await tester.tap(find.text('高级编辑'));
    await tester.pump();
    expect(find.text('未知卡片类型，已保留原始 JSON。可在高级编辑中修改。'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(find.text('暂无卡片'), findsOneWidget);
    controller.dispose();
  });

  test('accepts card URLs with uppercase HTTP schemes', () {
    expect(isHttpUrl('HTTP://example.com'), isTrue);
    expect(isHttpUrl('HTTPS://example.com'), isTrue);
  });

  testWidgets('canceling unknown JSON preserves it for later advanced editing', (tester) async {
    const raw = '{"type":"future","payload":{"label":"Preview","count":2}}';
    final controller = TextEditingController(text: raw);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MomentExtensionEditor(controller: controller))));

    expect(find.text('未知卡片类型，已保留原始 JSON。可在高级编辑中修改。'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pump();
    expect(controller.text, raw);
    expect(find.text('高级编辑'), findsOneWidget);
    await tester.tap(find.text('高级编辑'));
    await tester.pump();
    expect(find.widgetWithText(TextField, raw), findsOneWidget);
    controller.dispose();
  });

  testWidgets('canceling invalid JSON preserves it for later advanced editing', (tester) async {
    const raw = '{invalid';
    final controller = TextEditingController(text: raw);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MomentExtensionEditor(controller: controller))));

    await tester.tap(find.text('高级编辑'));
    await tester.pump();
    await tester.tap(find.text('取消'));
    await tester.pump();
    expect(controller.text, raw);
    await tester.tap(find.text('高级编辑'));
    await tester.pump();
    expect(find.widgetWithText(TextField, raw), findsOneWidget);
    controller.dispose();
  });

  testWidgets('syncs the current draft before submit without pressing save', (tester) async {
    final controller = TextEditingController(text: '{"type":"website","payload":{"title":"旧","site":"https://example.com"}}');
    final key = GlobalKey<State<StatefulWidget>>();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MomentExtensionEditor(key: key, controller: controller))));
    await tester.enterText(find.widgetWithText(TextField, '旧'), '新标题');
    expect((key.currentState as dynamic).validateAndSync(), isEmpty);
    expect(jsonDecode(controller.text)['payload']['title'], '新标题');
    controller.dispose();
  });
}
