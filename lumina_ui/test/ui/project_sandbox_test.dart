import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/project_sandbox.dart';
import 'package:path/path.dart' as p;

/// The project sandbox every file tool resolves through — on
/// real temp folders (the project under a "Lumina Projects" folder, a path
/// with a space), with real symlinks (junctions on Windows).
void main() {
  late Directory root;
  late String projectDir;
  late ProjectSandbox sandbox;

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumina_sandbox_');
    projectDir = p.join(root.path, 'Lumina Projects', 'SandboxGame');
    Directory(p.join(projectDir, 'lib', 'levels')).createSync(recursive: true);
    File(p.join(projectDir, 'lib', 'main.dart')).writeAsStringSync('void main() {}\n');
    sandbox = ProjectSandbox(projectDir);
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Matcher violation([String? containing]) =>
      throwsA(isA<SandboxViolation>().having((v) => v.message, 'message', containing == null ? anything : contains(containing)));

  group('resolution', () {
    test('a relative path and its absolute form resolve to the same relative path, under a root with a space', () {
      final rel = sandbox.resolve('lib/main.dart', access: SandboxAccess.read);
      final abs = sandbox.resolve(p.join(projectDir, 'lib', 'main.dart'), access: SandboxAccess.read);
      expect(rel.relative, 'lib/main.dart');
      expect(abs.relative, 'lib/main.dart');
      expect(abs.absolute, rel.absolute);
      expect(sandbox.root, contains('Lumina Projects'));
      expect(sandbox.resolve('.', access: SandboxAccess.read).relative, '.');
    });

    test('.., absolute paths outside, NUL bytes and empty strings are violations', () {
      for (final bad in ['../outside.txt', 'lib/../../x', '/etc/passwd', 'lib/\u0000x', '', if (Platform.isWindows) r'C:\Windows\win.ini']) {
        expect(() => sandbox.resolve(bad, access: SandboxAccess.read), violation(), reason: bad);
        expect(() => sandbox.resolve(bad, access: SandboxAccess.write), violation(), reason: bad);
      }
      expect(() => sandbox.resolve('../outside.txt', access: SandboxAccess.read), violation('outside the project'));
    });

    test('a symlink out of the project is refused for read and write; one to another project folder resolves', () {
      final other = Directory.systemTemp.createTempSync('lumina_sandbox_other_');
      addTearDown(() => other.deleteSync(recursive: true));
      File(p.join(other.path, 'a.dart')).writeAsStringSync('// outside\n');
      Link(p.join(projectDir, 'lib', 'escape')).createSync(other.path);
      expect(() => sandbox.resolve('lib/escape/a.dart', access: SandboxAccess.read), violation('outside the project'));
      expect(() => sandbox.resolve('lib/escape/a.dart', access: SandboxAccess.write), violation('outside the project'));
      expect(() => sandbox.resolve('lib/escape/new.dart', access: SandboxAccess.write), violation('outside the project'));

      final shared = Directory(p.join(projectDir, 'shared'))..createSync();
      File(p.join(shared.path, 'util.dart')).writeAsStringSync('// shared\n');
      Link(p.join(projectDir, 'lib', 'shared')).createSync(shared.path);
      expect(sandbox.resolve('lib/shared/util.dart', access: SandboxAccess.read).relative, 'shared/util.dart');
    });

    test('a new nested path resolves through its deepest existing ancestor', () {
      final r = sandbox.resolve('lib/agent/new/file.dart', access: SandboxAccess.write);
      expect(r.relative, 'lib/agent/new/file.dart');
      expect(p.isWithin(sandbox.root, r.absolute), isTrue);
      expect(Directory(p.join(projectDir, 'lib', 'agent')).existsSync(), isFalse, reason: 'resolving creates nothing');
    });
  });

  group('write denial', () {
    test('editor state, build output, packages, git, assets, the manifest, .lmas and pubspec.lock are denied with a reason',
        () {
      final denied = {
        '.lumina/editor_layout.json': 'editor state',
        'build/x': 'build',
        '.dart_tool/x': '.dart_tool',
        '.git/config': '.git',
        'contents/meshes/a.txt': 'import_asset',
        'SandboxGame.lmproject': 'settings tools',
        'contents/levels/L_Main.lmas': 'asset',
        'pubspec.lock': 'pubspec.lock',
      };
      for (final e in denied.entries) {
        expect(() => sandbox.resolve(e.key, access: SandboxAccess.write), violation(e.value), reason: e.key);
        expect(() => sandbox.resolve(e.key, access: SandboxAccess.delete), violation(), reason: e.key);
        expect(sandbox.resolve(e.key, access: SandboxAccess.read).relative, e.key);
      }
      expect(() => sandbox.resolve('lib/levels/L_Main.lmas', access: SandboxAccess.write), violation('.lmas'));
    });

    test('binary files and binary content', () {
      File(p.join(projectDir, 'lib', 'blob.bin')).writeAsBytesSync([1, 2, 0, 3]);
      expect(() => sandbox.resolve('lib/blob.bin', access: SandboxAccess.write), violation('binary'));
      expect(sandbox.isBinaryFile(File(p.join(projectDir, 'lib', 'blob.bin'))), isTrue);
      expect(sandbox.isBinaryFile(File(p.join(projectDir, 'lib', 'main.dart'))), isFalse);
      expect(() => ProjectSandbox.checkContent([0x61, 0, 0x62]), violation('binary content'));
      expect(() => ProjectSandbox.checkContent([0xff, 0xfe, 0x41]), violation('binary content'));
      ProjectSandbox.checkContent(utf8.encode('çalışan kod // UTF-8 text is fine'));
    });
  });

  test('generated files name the tool that overwrites them', () {
    expect(ProjectSandbox.generatedBy('lib/main.dart'), contains('run_codegen'));
    expect(ProjectSandbox.generatedBy('lib/levels/l_main.dart'), contains('run_codegen'));
    expect(ProjectSandbox.generatedBy('lib/actors/bp_door.dart'), contains('compile_blueprint'));
    expect(ProjectSandbox.generatedBy('lib/widgets/deep/w_hud.dart'), isNotNull);
    expect(ProjectSandbox.generatedBy('lib/input/project_input.g.dart'), isNotNull);
    expect(ProjectSandbox.generatedBy('lib/blueprint/blueprint_functions.g.dart'), isNotNull);
    expect(ProjectSandbox.generatedBy('lib/game/thing.g.dart'), isNotNull);
    expect(ProjectSandbox.generatedBy('lib/agent/barrel_math.dart'), isNull);
    expect(ProjectSandbox.generatedBy('lib/levels/sub/x.dart'), isNull);
  });

  test('glob: *, **, ?, {a,b} and character classes', () {
    bool m(String glob, String path) => SandboxGlob(glob).matches(path);
    expect(m('**/*.dart', 'lib/main.dart'), isTrue);
    expect(m('**/*.dart', 'main.dart'), isTrue);
    expect(m('lib/**/*.dart', 'lib/levels/l_main.dart'), isTrue);
    expect(m('lib/**/*.dart', 'lib/main.dart'), isTrue);
    expect(m('lib/*.dart', 'lib/levels/l_main.dart'), isFalse);
    expect(m('*.{yaml,md}', 'pubspec.yaml'), isTrue);
    expect(m('*.{yaml,md}', 'README.md'), isTrue);
    expect(m('*.{yaml,md}', 'main.dart'), isFalse);
    expect(m('L_?ain.dart', 'L_Main.dart'), isTrue);
    expect(m('[A-Z]*.dart', 'Main.dart'), isTrue);
    expect(m('[!A-Z]*.dart', 'Main.dart'), isFalse);
    expect(m('a.b', 'aXb'), isFalse, reason: 'dots are literal');
  });
}
