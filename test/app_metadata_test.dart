import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('declares the expected Flutter package metadata', () {
    final source = File('pubspec.yaml').readAsStringSync();

    expect(source, contains('name: blog_phone'));
    expect(source, contains('version: 1.1.0+2'));
  });

  test('uses blog-api as the Android product label', () {
    final source = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(source, contains('android:label="blog-api"'));
  });

  test('uses blog-api for Windows binary, window, and resources', () {
    final cmake = File('windows/CMakeLists.txt').readAsStringSync();
    final main = File('windows/runner/main.cpp').readAsStringSync();
    final resources = File('windows/runner/Runner.rc').readAsStringSync();

    expect(cmake, contains('set(BINARY_NAME "blog-api")'));
    expect(main, contains('window.Create(L"blog-api"'));
    expect(resources, contains('VALUE "FileDescription", "blog-api"'));
    expect(resources, contains('VALUE "InternalName", "blog-api"'));
    expect(resources, contains('VALUE "OriginalFilename", "blog-api.exe"'));
    expect(resources, contains('VALUE "ProductName", "blog-api"'));
  });
}
