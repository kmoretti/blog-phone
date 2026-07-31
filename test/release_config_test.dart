import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release validates signing only for release tasks', () {
    final source = File('android/app/build.gradle.kts').readAsStringSync();

    expect(source, contains('key.properties'));
    expect(source, contains('signingConfigs.create("release")'));
    expect(source, contains('gradle.taskGraph.whenReady'));
    expect(source, contains('storeFile'));
    expect(source, contains('storePassword'));
    expect(source, contains('keyAlias'));
    expect(source, contains('keyPassword'));
    expect(source, contains('applicationId = "com.example.blog_phone"'));
    expect(source, isNot(contains('throw GradleException("android/key.properties is required for release signing")')));
    expect(source, isNot(contains('signingConfigs.getByName("debug")')));
  });

  test('CI workflow reconstructs and cleans signing inputs', () {
    final source = File('.github/workflows/build.yml').readAsStringSync();

    expect(source, contains('Prepare Android signing'));
    expect(source, contains('ANDROID_KEYSTORE_BASE64'));
    expect(source, contains('ANDROID_KEYSTORE_PASSWORD'));
    expect(source, contains('ANDROID_KEY_ALIAS'));
    expect(source, contains('ANDROID_KEY_PASSWORD'));
    expect(source, contains('if: always()'));
  });
}
