import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/tooling/windows_packaging/windows_packaging.dart';
import 'package:path/path.dart' as p;

/// The MSIX version of a release version: valid for the Microsoft Store (four
/// sections, the fourth 0, the first not 0, each at most 65535) and strictly
/// increasing with semver order, computed the same way by the packaging tool
/// and by the release workflow's `tool/release/release_info.dart`.
void main() {
  const expected = {
    '0.0.1-dev.1': '1.0.1001.0',
    '0.0.1-dev.10': '1.0.1010.0',
    '0.0.1-dev.499': '1.0.1499.0',
    '0.0.1-rc.1': '1.0.1501.0',
    '0.0.1-rc.2': '1.0.1502.0',
    '0.0.1': '1.0.1999.0',
    '0.0.2-dev.1': '1.0.2001.0',
    '0.0.64': '1.0.64999.0',
    '0.1.0-dev.1': '1.1.1.0',
    '0.1.0': '1.1.999.0',
    '1.0.0-rc.1': '2.0.501.0',
    '1.0.0': '2.0.999.0',
  };

  test('maps release versions to Store-valid MSIX versions', () {
    expected.forEach((semver, msix) {
      expect(storeMsixVersion(semver), msix, reason: semver);
      final parts = msix.split('.').map(int.parse).toList();
      expect(parts, hasLength(4));
      expect(parts[3], 0, reason: 'the Store owns the fourth section');
      expect(parts[0], greaterThanOrEqualTo(1), reason: 'the Store refuses a first section of 0');
      expect(parts.every((x) => x <= 65535), isTrue);
    });
    expect(storeMsixVersion('0.0.1-dev.10+10'), '1.0.1010.0', reason: 'the +build suffix is ignored');
  });

  test('versions in semver order map to strictly increasing MSIX versions', () {
    int compare(String a, String b) {
      final x = a.split('.').map(int.parse).toList(), y = b.split('.').map(int.parse).toList();
      for (var i = 0; i < 4; i++) {
        if (x[i] != y[i]) return x[i].compareTo(y[i]);
      }
      return 0;
    }

    final ordered = expected.keys.toList(); // written in semver order
    for (var i = 1; i < ordered.length; i++) {
      expect(compare(storeMsixVersion(ordered[i - 1]), storeMsixVersion(ordered[i])), lessThan(0),
          reason: '${ordered[i - 1]} < ${ordered[i]}');
    }
  });

  test('refuses versions the scheme cannot order, naming the rule', () {
    Matcher refused(String text) =>
        throwsA(isA<PackagingException>().having((e) => e.exitCode, 'exitCode', 64).having((e) => e.message, 'message', contains(text)));
    expect(() => storeMsixVersion('0.0.1-alpha.1'), refused('dev.N and rc.N'));
    expect(() => storeMsixVersion('0.0.1-dev'), refused('dev.N and rc.N'));
    expect(() => storeMsixVersion('0.0.1-dev.0'), refused('1–499'));
    expect(() => storeMsixVersion('0.0.1-dev.500'), refused('1–499'));
    expect(() => storeMsixVersion('0.0.1-rc.499'), refused('1–498'));
    expect(() => storeMsixVersion('0.0.65'), refused('at most 64'));
    expect(() => storeMsixVersion('1.2'), refused('semantic version'));
  });

  test('the default version of the packaging tool comes from the pubspec through the same scheme', () {
    expect(msixVersionFromPubspec('name: a\nversion: 0.0.1-dev.10+10\n'), '1.0.1010.0');
    expect(msixVersionFromPubspec('version: 3.4.5+12\n'), '4.4.5999.0');
    expect(() => msixVersionFromPubspec('name: a\n'), throwsA(isA<PackagingException>()));
  });

  group('tool/release/release_info.dart version', () {
    late Directory repo;

    setUp(() {
      repo = Directory.systemTemp.createTempSync('lpw_release_');
      Directory(p.join(repo.path, 'lumina_ui')).createSync();
    });

    tearDown(() {
      if (repo.existsSync()) repo.deleteSync(recursive: true);
    });

    final script = p.join(Directory.current.parent.path, 'tool', 'release', 'release_info.dart');

    Future<ProcessResult> run(String semver) {
      File(p.join(repo.path, 'lumina_ui', 'pubspec.yaml')).writeAsStringSync('name: lumina_ui\nversion: $semver+7\n');
      return Process.run(findDartExecutable(Platform.environment), [script, 'version', '--tag', 'v$semver', '--root', repo.path]);
    }

    test('prints the same msix_version as the packaging tool for every tag', () async {
      for (final semver in expected.keys) {
        final r = await run(semver);
        expect(r.exitCode, 0, reason: '$semver: ${r.stderr}');
        expect(RegExp(r'^msix_version=(.+)$', multiLine: true).firstMatch((r.stdout as String).replaceAll('\r', ''))!.group(1),
            storeMsixVersion(semver));
      }
    });

    test('fails the release for a tag the scheme cannot map', () async {
      final r = await run('0.0.1-alpha.1');
      expect(r.exitCode, isNot(0));
      expect(r.stderr as String, contains('dev.N and rc.N'));
    });
  });
}
