import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/models/lumina_project.dart';
import 'package:lumina/data/services/umg_widget_library_service.dart';

/// A project's pubspec follows its UMG widget library through one
/// marked, idempotent block.
void main() {
  late Directory root;
  late File pubspec;
  late String original;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_umg_lib_');
    // A real `flutter create` pubspec: CRLF on Windows, LF elsewhere.
    final create = await Process.run('flutter', ['create', '--no-pub', '--project-name', 'hud_game', '${root.path}/hud_game'],
        runInShell: Platform.isWindows);
    expect(create.exitCode, 0, reason: '${create.stderr}');
    pubspec = File('${root.path}/hud_game/pubspec.yaml');
    original = pubspec.readAsStringSync();
  });

  tearDownAll(() => root.deleteSync(recursive: true));

  setUp(() => pubspec.writeAsStringSync(original));

  test('shadcn adds one marked shadcn_flutter pin under dependencies; applying again changes nothing', () {
    final projectDir = pubspec.parent.path;
    expect(UmgWidgetLibraryService.apply(projectDir, kUmgWidgetLibraryShadcn), isTrue);
    final text = pubspec.readAsStringSync();
    expect(RegExp(r'^  shadcn_flutter: ' + RegExp.escape(kGameShadcnFlutterVersion) + r'$', multiLine: true).allMatches(text).length, 1);
    expect(text, contains(UmgWidgetLibraryService.beginMarker));
    expect(text, contains(UmgWidgetLibraryService.endMarker));
    final deps = text.indexOf('\ndependencies:');
    final devDeps = text.indexOf('\ndev_dependencies:');
    final pin = text.indexOf('shadcn_flutter:');
    expect(pin > deps && pin < devDeps, isTrue, reason: 'a runtime dependency, not a dev one');
    expect(RegExp(r'^dependencies:', multiLine: true).allMatches(text).length, 1,
        reason: 'the existing dependencies: mapping is reused, never duplicated (CRLF pubspecs on Windows)');
    expect(text.contains('\r\n'), original.contains('\r\n'), reason: 'the file keeps its line endings');
    expect(UmgWidgetLibraryService.apply(projectDir, kUmgWidgetLibraryShadcn), isFalse);
    expect(pubspec.readAsStringSync(), text);
    expect(UmgWidgetLibraryService.dependsOnShadcn(projectDir), isTrue);
  });

  test('flutter removes the block and leaves every other line byte-identical', () {
    final projectDir = pubspec.parent.path;
    UmgWidgetLibraryService.apply(projectDir, kUmgWidgetLibraryShadcn);
    expect(UmgWidgetLibraryService.apply(projectDir, kUmgWidgetLibraryFlutter), isTrue);
    expect(pubspec.readAsStringSync(), original);
    expect(UmgWidgetLibraryService.apply(projectDir, kUmgWidgetLibraryFlutter), isFalse);
    expect(UmgWidgetLibraryService.dependsOnShadcn(projectDir), isFalse);
  });
}
