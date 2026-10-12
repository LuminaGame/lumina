import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_editor_data/lumina_editor_data.dart';
import 'package:path/path.dart' as p;

/// The NVIDIA DLSS runtime in a packaged game: located through the game's own
/// flutter_filament, verified against `tool/dlss/manifest.txt`, copied next to
/// the executable with NVIDIA's licence. Uses the real SDK that
/// `tool/dlss/fetch_sdk.dart` fetched; tests that need it skip with the reason
/// when it is not there.
void main() {
  final filamentRoot = LuminaWorkspace.packageIn(LuminaWorkspace.findSourceRoot() ?? LuminaWorkspace.root, 'flutter_filament');
  final realSdk = DlssSdk.readSync(filamentRoot);
  final noSdk = realSdk == null
      ? 'flutter_filament has no tool/dlss (looked in $filamentRoot)'
      : realSdk.isFetched
          ? null
          : 'the DLSS SDK is not fetched: run `dart run tool/dlss/fetch_sdk.dart` in $filamentRoot';
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('dlss_bundle_'));
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// A packaged game folder holding an executable, as `flutter build` leaves it.
  Directory packageWithExe(String name) {
    final dir = Directory(p.join(temp.path, 'package', name))..createSync(recursive: true);
    File(p.join(dir.path, name == 'windows' ? 'game.exe' : 'game')).writeAsBytesSync(utf8.encode('exe'));
    return dir;
  }

  /// A flutter_filament-shaped folder whose manifest lists [paths] of the real
  /// SDK (copied), with [wrongSha] given another hash.
  DlssSdk partialSdk(List<String> paths, {String? wrongSha}) {
    final root = Directory(p.join(temp.path, 'flutter_filament'))..createSync();
    Directory(p.join(root.path, 'tool', 'dlss')).createSync(recursive: true);
    File(p.join(root.path, 'tool', 'dlss', 'VERSION')).writeAsStringSync('${realSdk!.version}\n');
    final lines = <String>['# test manifest'];
    for (final path in paths) {
      final e = realSdk.manifest.firstWhere((m) => m.path == path);
      final to = File(p.join(root.path, 'build', 'dlss-sdk', path))..parent.createSync(recursive: true);
      File(p.join(realSdk.sdkDir, path)).copySync(to.path);
      final sha = path == wrongSha ? 'f' * 64 : e.sha256;
      lines.add('$sha  ${e.size}  $path');
    }
    File(p.join(root.path, 'tool', 'dlss', 'manifest.txt')).writeAsStringSync('${lines.join('\n')}\n');
    return DlssSdk.readSync(root.path)!;
  }

  test('the manifest names three runtime libraries per desktop target and none for other targets', () {
    if (realSdk == null) return markTestSkipped(noSdk!);
    expect(realSdk.runtimeEntriesFor('windows').map((e) => e.fileName), ['nvngx_dlss.dll', 'nvngx_dlssd.dll', 'nvngx_dlssg.dll']);
    expect(realSdk.runtimeEntriesFor('linux').map((e) => e.fileName).toList()..sort(), [
      'libnvidia-ngx-dlss.so.${realSdk.versionNumber}',
      'libnvidia-ngx-dlssd.so.${realSdk.versionNumber}',
      'libnvidia-ngx-dlssg.so.${realSdk.versionNumber}',
    ]);
    for (final t in ['web', 'android', 'macos', 'ios']) {
      expect(DlssSdk.supportsTarget(t), isFalse, reason: t);
      expect(realSdk.runtimeEntriesFor(t), isEmpty, reason: t);
    }
    expect(realSdk.licenseEntry?.path, 'LICENSE.txt');
  });

  test('Windows: the runtime lands next to the executable, byte-identical, with the licence and the notice', () async {
    if (noSdk != null) return markTestSkipped(noSdk);
    final pkg = packageWithExe('windows');
    final report = await DlssRuntimeBundle.bundleInto(realSdk!, target: 'windows', packageDir: pkg.path);
    expect(report.bundled, isTrue);
    expect(report.files.map((f) => f.name),
        ['nvngx_dlss.dll', 'nvngx_dlssd.dll', 'nvngx_dlssg.dll', DlssRuntimeBundle.licenseFileName, DlssRuntimeBundle.noticeFileName]);
    for (final e in realSdk.runtimeEntriesFor('windows')) {
      final copied = File(p.join(pkg.path, e.fileName));
      expect(copied.lengthSync(), e.size);
      expect(DlssSdk.sha256Sync(copied), e.sha256);
    }
    expect(File(p.join(pkg.path, 'game.exe')).existsSync(), isTrue);
    final license = File(p.join(pkg.path, DlssRuntimeBundle.licenseFileName)).readAsStringSync();
    expect(license, startsWith('NVIDIA RTX SDKs LICENSE'));
    final notice = File(p.join(pkg.path, DlssRuntimeBundle.noticeFileName)).readAsStringSync();
    expect(notice, contains('NVIDIA DLSS SDK ${realSdk.version}'));
    expect(notice, contains('nvngx_dlss.dll'));
    expect(notice, contains('NVIDIA RTX SDKs licence'));
    // Nothing lands in a lib/ subfolder: the lookup checks the executable's folder.
    expect(Directory(p.join(pkg.path, 'lib')).existsSync(), isFalse);
    final log = DlssRuntimeBundle.describe(report);
    expect(log.where((l) => l.startsWith('NVIDIA DLSS: bundled nvngx_dlss')), hasLength(3));
    expect(log.last, contains('5 file(s)'));
  });

  test('Linux: the three libnvidia-ngx libraries land in the bundle root', () async {
    if (noSdk != null) return markTestSkipped(noSdk);
    final pkg = packageWithExe('linux');
    final report = await DlssRuntimeBundle.bundleInto(realSdk!, target: 'linux', packageDir: pkg.path);
    expect(report.files.map((f) => f.name).where((n) => n.startsWith('libnvidia-ngx-dlss')), hasLength(3));
    for (final e in realSdk.runtimeEntriesFor('linux')) {
      expect(File(p.join(pkg.path, e.fileName)).lengthSync(), e.size);
    }
    expect(File(p.join(pkg.path, DlssRuntimeBundle.licenseFileName)).existsSync(), isTrue);
    expect(pkg.listSync().whereType<File>().any((f) => f.path.endsWith('.dll')), isFalse);
  });

  test('a file whose SHA-256 differs from the manifest is refused and nothing is copied', () async {
    if (noSdk != null) return markTestSkipped(noSdk);
    const dll = 'lib/Windows_x86_64/rel/nvngx_dlssg.dll';
    final sdk = partialSdk(['LICENSE.txt', dll], wrongSha: dll);
    expect(sdk.isFetched, isTrue, reason: 'present with the right size: only the hash is wrong');
    final pkg = packageWithExe('windows');
    await expectLater(
      DlssRuntimeBundle.bundleInto(sdk, target: 'windows', packageDir: pkg.path),
      throwsA(isA<DlssBundleRefused>().having((e) => e.problems.single, 'problem', allOf(contains(dll), contains('SHA-256')))),
    );
    expect(pkg.listSync().map((e) => p.basename(e.path)), ['game.exe']);
  });

  test('an SDK that is not fetched is refused with the fetch command', () async {
    if (realSdk == null) return markTestSkipped(noSdk!);
    final root = Directory(p.join(temp.path, 'flutter_filament'));
    Directory(p.join(root.path, 'tool', 'dlss')).createSync(recursive: true);
    File(p.join(realSdk.packageRoot, 'tool', 'dlss', 'VERSION')).copySync(p.join(root.path, 'tool', 'dlss', 'VERSION'));
    File(p.join(realSdk.packageRoot, 'tool', 'dlss', 'manifest.txt')).copySync(p.join(root.path, 'tool', 'dlss', 'manifest.txt'));
    final empty = DlssSdk.readSync(root.path)!;
    expect(empty.isFetched, isFalse);
    expect(empty.missingReason, contains(DlssSdk.fetchCommand));
    final pkg = packageWithExe('windows');
    await expectLater(DlssRuntimeBundle.bundleInto(empty, target: 'windows', packageDir: pkg.path), throwsA(isA<DlssBundleRefused>()));
    expect(pkg.listSync(), hasLength(1));
  });

  test('web, Android, macOS and iOS packages get nothing', () async {
    if (realSdk == null) return markTestSkipped(noSdk!);
    for (final target in ['web', 'android', 'macos', 'ios']) {
      final pkg = Directory(p.join(temp.path, 'package', target))..createSync(recursive: true);
      final report = await DlssRuntimeBundle.bundleInto(realSdk, target: target, packageDir: pkg.path);
      expect(report.bundled, isFalse, reason: target);
      expect(report.skippedReason, contains('Windows and Linux'));
      expect(pkg.listSync(), isEmpty, reason: target);
      expect(DlssRuntimeBundle.packagedNamesFor(realSdk, target), isEmpty);
    }
  });

  test('the SDK is the one of the flutter_filament the game resolves, not the editor fallback', () async {
    if (realSdk == null) return markTestSkipped(noSdk!);
    final project = Directory(p.join(temp.path, 'game'))..createSync();
    // No package config yet (never built): the fallback is used.
    final fallback = await DlssSdk.locate(project.path, fallbackPackageRoots: [realSdk.packageRoot]);
    expect(p.normalize(fallback!.packageRoot), p.normalize(realSdk.packageRoot));

    // The game resolves a flutter_filament without the SDK: that one decides.
    final other = Directory(p.join(temp.path, 'other_filament'));
    Directory(p.join(other.path, 'tool', 'dlss')).createSync(recursive: true);
    File(p.join(realSdk.packageRoot, 'tool', 'dlss', 'VERSION')).copySync(p.join(other.path, 'tool', 'dlss', 'VERSION'));
    File(p.join(realSdk.packageRoot, 'tool', 'dlss', 'manifest.txt')).copySync(p.join(other.path, 'tool', 'dlss', 'manifest.txt'));
    File(p.join(other.path, 'pubspec.yaml')).writeAsStringSync('name: flutter_filament\n');
    Directory(p.join(project.path, '.dart_tool')).createSync();
    File(p.join(project.path, '.dart_tool', 'package_config.json')).writeAsStringSync(jsonEncode({
      'configVersion': 2,
      'packages': [
        {'name': 'flutter_filament', 'rootUri': Uri.directory(other.path).toString(), 'packageUri': 'lib/'},
      ],
    }));
    final resolved = await DlssSdk.locate(project.path, fallbackPackageRoots: [realSdk.packageRoot]);
    expect(p.normalize(resolved!.packageRoot), p.normalize(other.path));
    expect(resolved.isFetched, isFalse);
  });
}
