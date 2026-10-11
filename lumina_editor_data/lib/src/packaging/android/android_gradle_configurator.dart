import 'dart:io';

import 'package:lumina_core/lumina_core.dart';

/// What [AndroidGradleConfigurator.apply] changed.
class AndroidGradleChange {
  final bool gradleChanged;

  /// Where `MainActivity` moved to, when the namespace changed.
  final String? movedMainActivity;
  const AndroidGradleChange({this.gradleChanged = false, this.movedMainActivity});
}

/// Writes the project's Android settings into the game's
/// `android/app/build.gradle.kts` (Flutter's template): the application id
/// (also the namespace, so the launcher activity is `<id>/.MainActivity`),
/// the SDK levels, the versions, the ABI filter and the release signing.
/// The keystore passwords are read by Gradle from the environment
/// ([storePasswordVariable], [keyPasswordVariable]); they are never written
/// into the project.
abstract final class AndroidGradleConfigurator {
  static const String begin = '// BEGIN LUMINA (generated)';
  static const String end = '// END LUMINA (generated)';
  static const String storePasswordVariable = 'LUMINA_ANDROID_KEYSTORE_PASSWORD';
  static const String keyPasswordVariable = 'LUMINA_ANDROID_KEY_PASSWORD';

  /// [gradle] (a `build.gradle.kts`) with [settings] applied for [projectName].
  static String configure(String gradle, ProjectAndroidSettings settings, String projectName, {String projectDir = '.'}) {
    final nl = gradle.contains('\r\n') ? '\r\n' : '\n';
    var g = gradle.replaceAll('\r\n', '\n');
    g = g.replaceAll(RegExp(r'[ \t]*// BEGIN LUMINA \(generated\).*?// END LUMINA \(generated\)[ \t]*\n', dotAll: true), '');
    final id = settings.applicationIdFor(projectName);
    String set(String text, String key, String value) {
      final re = RegExp('^([ \\t]*)$key\\s*=.*\$', multiLine: true);
      return re.hasMatch(text) ? text.replaceFirstMapped(re, (m) => '${m.group(1)}$key = $value') : text;
    }

    g = set(g, 'namespace', '"$id"');
    g = set(g, 'applicationId', '"$id"');
    g = set(g, 'minSdk', '${settings.minSdk}');
    g = set(g, 'targetSdk', '${settings.targetSdk}');
    g = set(g, 'versionCode', '${settings.versionCode}');
    g = set(g, 'versionName', '"${settings.versionName.replaceAll('"', '')}"');

    // The ABI filter, at the end of defaultConfig.
    final dc = RegExp(r'defaultConfig\s*\{').firstMatch(g);
    if (dc != null && settings.abis.isNotEmpty) {
      final close = _matchingBrace(g, dc.end - 1);
      if (close > 0) {
        final lineStart = g.lastIndexOf('\n', close) + 1;
        final abis = settings.abis.map((a) => '"$a"').join(', ');
        g = g.replaceRange(lineStart, lineStart,
            '        $begin\n        ndk {\n            abiFilters.clear()\n            abiFilters += listOf($abis)\n        }\n        $end\n');
      }
    }

    // Release signing with the project's keystore, else Flutter's debug key.
    final release = RegExp(r'signingConfig\s*=\s*signingConfigs\.getByName\("[^"]*"\)').firstMatch(g);
    if (settings.hasReleaseKeystore) {
      final store = settings.keystorePath.replaceAll(r'\', '/').replaceAll('"', '');
      final storeFile = store.startsWith('/') || RegExp(r'^[A-Za-z]:/').hasMatch(store) ? store : '\${rootProject.projectDir}/../$store';
      final block = '    $begin\n'
          '    signingConfigs {\n'
          '        create("luminaRelease") {\n'
          '            storeFile = file("$storeFile")\n'
          '            storePassword = System.getenv("$storePasswordVariable")\n'
          '            keyAlias = "${settings.keyAlias.replaceAll('"', '')}"\n'
          '            keyPassword = System.getenv("$keyPasswordVariable") ?: System.getenv("$storePasswordVariable")\n'
          '        }\n'
          '    }\n'
          '    $end\n';
      final bt = g.indexOf(RegExp(r'^[ \t]*buildTypes\s*\{', multiLine: true));
      if (bt >= 0) g = g.replaceRange(bt, bt, block);
      final r2 = RegExp(r'signingConfig\s*=\s*signingConfigs\.getByName\("[^"]*"\)').firstMatch(g);
      if (r2 != null) g = g.replaceRange(r2.start, r2.end, 'signingConfig = signingConfigs.getByName("luminaRelease")');
    } else if (release != null) {
      g = g.replaceRange(release.start, release.end, 'signingConfig = signingConfigs.getByName("debug")');
    }
    return nl == '\n' ? g : g.replaceAll('\n', nl);
  }

  static int _matchingBrace(String s, int open) {
    var depth = 0;
    for (var i = open; i < s.length; i++) {
      if (s[i] == '{') depth++;
      if (s[i] == '}') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  /// Applies [settings] to [projectDir]'s Android app: the Gradle file and,
  /// when the namespace changes, `MainActivity` moved into the new package.
  static Future<AndroidGradleChange> apply(String projectDir, ProjectAndroidSettings settings, String projectName) async {
    final file = File('$projectDir/android/app/build.gradle.kts');
    if (!await file.exists()) {
      throw StateError('The project has no android/app/build.gradle.kts: add the Android platform with '
          '`flutter create --platforms=android .` in $projectDir');
    }
    final before = await file.readAsString();
    final after = configure(before, settings, projectName, projectDir: projectDir);
    if (after != before) await file.writeAsString(after);
    final moved = await _moveMainActivity(projectDir, settings.applicationIdFor(projectName));
    final props = File('$projectDir/android/gradle.properties');
    var propsChanged = false;
    if (await props.exists()) {
      final text = await props.readAsString();
      final next = withGradleProperties(text);
      if (next != text) {
        await props.writeAsString(next);
        propsChanged = true;
      }
    }
    return AndroidGradleChange(gradleChanged: after != before || propsChanged, movedMainActivity: moved);
  }

  static const String propertiesBegin = '# BEGIN LUMINA (generated)';
  static const String propertiesEnd = '# END LUMINA (generated)';

  /// [properties] (`android/gradle.properties`) with Lumina's block: Kotlin's
  /// incremental compilation off, because a plugin's Android sources often
  /// sit on another drive than the project (a local checkout) and Kotlin's
  /// incremental caches cannot relate paths across Windows drives.
  static String withGradleProperties(String properties) {
    final nl = properties.contains('\r\n') ? '\r\n' : '\n';
    var t = properties.replaceAll('\r\n', '\n');
    t = t.replaceAll(RegExp(r'# BEGIN LUMINA \(generated\).*?# END LUMINA \(generated\)\n?', dotAll: true), '');
    if (!t.endsWith('\n')) t = '$t\n';
    t = '$t$propertiesBegin\nkotlin.incremental=false\n$propertiesEnd\n';
    return nl == '\n' ? t : t.replaceAll('\n', nl);
  }

  /// Moves `MainActivity.kt` (or `.java`) into [id]'s package folder and
  /// rewrites its `package` line; null when it is there already.
  static Future<String?> _moveMainActivity(String projectDir, String id) async {
    for (final lang in const ['kotlin', 'java']) {
      final root = Directory('$projectDir/android/app/src/main/$lang');
      if (!await root.exists()) continue;
      await for (final e in root.list(recursive: true)) {
        if (e is! File) continue;
        final name = e.uri.pathSegments.last;
        if (name != 'MainActivity.kt' && name != 'MainActivity.java') continue;
        final text = await e.readAsString();
        final pkg = RegExp(r'^package\s+([\w.]+)', multiLine: true).firstMatch(text)?.group(1);
        if (pkg == id) return null;
        final target = File('${root.path}/${id.replaceAll('.', '/')}/$name');
        await target.parent.create(recursive: true);
        await target.writeAsString(text.replaceFirst(RegExp(r'^package\s+[\w.]+;?', multiLine: true),
            name.endsWith('.java') ? 'package $id;' : 'package $id'));
        await e.delete();
        // Drop the folders the old package leaves empty.
        var dir = e.parent;
        while (dir.path.length > root.path.length && (await dir.list().isEmpty)) {
          await dir.delete();
          dir = dir.parent;
        }
        return target.path;
      }
    }
    return null;
  }
}
