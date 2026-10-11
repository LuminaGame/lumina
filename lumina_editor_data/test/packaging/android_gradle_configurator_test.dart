import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_editor_data/src/packaging/android/android_gradle_configurator.dart';

void main() {
  final template = File('test/packaging/fixtures/flutter_template_build.gradle.kts').readAsStringSync();

  test('the Quest profile sets the id, namespace, SDK levels, versions and the arm64 filter', () {
    final out = AndroidGradleConfigurator.configure(
        template, const ProjectAndroidSettings.quest(versionName: '0.3.0', versionCode: 7), 'MetaXR Posing');
    expect(out, contains('namespace = "com.lumina.metaxr_posing"'));
    expect(out, contains('applicationId = "com.lumina.metaxr_posing"'));
    expect(out, contains('minSdk = $kQuestMinSdk'));
    expect(out, contains('targetSdk = $kQuestTargetSdk'));
    expect(out, contains('versionCode = 7'));
    expect(out, contains('versionName = "0.3.0"'));
    expect(out, contains('abiFilters += listOf("arm64-v8a")'));
    expect(out, contains('signingConfig = signingConfigs.getByName("debug")'));
    // Idempotent.
    expect(AndroidGradleConfigurator.configure(out, const ProjectAndroidSettings.quest(versionName: '0.3.0', versionCode: 7), 'MetaXR Posing'), out);
  });

  test('a release keystore signs with passwords from the environment only', () {
    final out = AndroidGradleConfigurator.configure(
        template, const ProjectAndroidSettings.quest(keystorePath: 'keys/release.jks', keyAlias: 'game'), 'g');
    expect(out, contains('signingConfig = signingConfigs.getByName("luminaRelease")'));
    expect(out, contains('System.getenv("${AndroidGradleConfigurator.storePasswordVariable}")'));
    expect(out, contains('keys/release.jks'));
    expect(out, isNot(contains('storePassword = "')));
  });

  test('MainActivity follows the application id into its package', () async {
    final dir = Directory.systemTemp.createTempSync('gradle_cfg_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/android/app/build.gradle.kts')
      ..createSync(recursive: true)
      ..writeAsStringSync(template);
    File('${dir.path}/android/app/src/main/kotlin/com/example/my_game/MainActivity.kt')
      ..createSync(recursive: true)
      ..writeAsStringSync('package com.example.my_game\n\nimport io.flutter.embedding.android.FlutterActivity\n\nclass MainActivity : FlutterActivity()\n');
    final change = await AndroidGradleConfigurator.apply(dir.path, const ProjectAndroidSettings.quest(), 'my game');
    expect(change.gradleChanged, isTrue);
    final moved = File('${dir.path}/android/app/src/main/kotlin/com/lumina/my_game/MainActivity.kt');
    expect(moved.readAsStringSync(), startsWith('package com.lumina.my_game\n'));
    expect(Directory('${dir.path}/android/app/src/main/kotlin/com/example').existsSync(), isFalse);
  });
}
