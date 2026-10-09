import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

/// Flutter's own runner templates (the SDK this test runs on), what
/// `flutter create` writes into a new game project.
Directory _flutterTemplates() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && root.isNotEmpty) return Directory('$root/packages/flutter_tools/templates/app');
  // Otherwise up from the test runner (<flutter>/bin/cache/...).
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.parent.path != dir.path && !Directory('${dir.path}/packages/flutter_tools').existsSync()) {
    dir = dir.parent;
  }
  return Directory('${dir.path}/packages/flutter_tools/templates/app');
}

/// A project folder with Flutter's real Windows and Linux runner files.
String _projectWithRunners(Directory root) {
  final templates = _flutterTemplates();
  final project = '${root.path}/game';
  for (final platform in ['windows', 'linux']) {
    final source = Directory('${templates.path}/$platform.tmpl');
    for (final f in source.listSync(recursive: true).whereType<File>()) {
      final rel = f.path.substring(source.path.length + 1).replaceAll('\\', '/');
      if (!rel.endsWith('.cpp') && !rel.endsWith('.cc') && !rel.endsWith('.tmpl') && !rel.endsWith('.txt') && !rel.endsWith('.h')) continue;
      final target = File('$project/$platform/${rel.replaceAll('.tmpl', '')}');
      target.parent.createSync(recursive: true);
      target.writeAsStringSync(f.readAsStringSync().replaceAll('{{projectName}}', 'game'));
    }
  }
  return project;
}

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('lumina_runner_'));
  tearDown(() => root.deleteSync(recursive: true));

  test('the Flutter SDK templates are where the test reads them', () {
    expect(File('${_flutterTemplates().path}/windows.tmpl/runner/flutter_window.cpp').existsSync(), isTrue);
  });

  group('Windows runner', () {
    test('writes the window-mode sources and hooks them into the runner', () {
      final project = _projectWithRunners(root);
      final report = GameWindowRunnerService.apply(project, startFullscreen: true);
      expect(report.warnings, isEmpty);

      final cpp = File('$project/windows/runner/lumina_window_mode.cpp').readAsStringSync();
      expect(cpp, contains('constexpr bool kStartFullscreen = true;'));
      expect(cpp, contains('WS_POPUP'));
      expect(cpp, contains('MonitorFromWindow'));
      expect(cpp, contains('rcMonitor'));
      expect(cpp, contains('HWND_TOP'));
      expect(cpp, contains('VK_F11'));
      expect(cpp, contains('"lumina/game_window"'));
      expect(File('$project/windows/runner/lumina_window_mode.h').existsSync(), isTrue);

      final cmake = File('$project/windows/runner/CMakeLists.txt').readAsStringSync();
      expect(RegExp(r'add_executable\([^)]*"lumina_window_mode\.cpp"', dotAll: true).hasMatch(cmake), isTrue);

      final window = File('$project/windows/runner/flutter_window.cpp').readAsStringSync();
      expect(window, contains('#include "lumina_window_mode.h"'));
      // After SetChildContent: the view window exists then.
      final attach = window.indexOf('LuminaWindowModeAttach(');
      expect(attach, greaterThan(window.indexOf('SetChildContent(')));
      expect(attach, lessThan(window.indexOf('SetNextFrameCallback')));
    });

    test('is idempotent: a second run changes nothing', () {
      final project = _projectWithRunners(root);
      GameWindowRunnerService.apply(project, startFullscreen: true);
      final before = {
        for (final f in Directory('$project/windows').listSync(recursive: true).whereType<File>()) f.path: f.readAsStringSync(),
      };
      final second = GameWindowRunnerService.apply(project, startFullscreen: true);
      expect(second.files, isEmpty);
      for (final e in before.entries) {
        expect(File(e.key).readAsStringSync(), e.value, reason: e.key);
      }
    });

    test('Start Fullscreen off keeps the toggle and starts windowed', () {
      final project = _projectWithRunners(root);
      GameWindowRunnerService.apply(project, startFullscreen: true);
      final report = GameWindowRunnerService.apply(project, startFullscreen: false);
      expect(report.files, ['windows/runner/lumina_window_mode.cpp', 'linux/runner/lumina_window_mode.cc']);
      expect(File('$project/windows/runner/lumina_window_mode.cpp').readAsStringSync(),
          contains('constexpr bool kStartFullscreen = false;'));
    });

    test('the earlier screen-sized main.cpp is put back to the template window', () {
      final project = _projectWithRunners(root);
      final main = File('$project/windows/runner/main.cpp');
      main.writeAsStringSync(main.readAsStringSync().replaceAll(
            RegExp(r'Win32Window::Point origin\(10, 10\);\s*Win32Window::Size size\(1280, 720\);'),
            'Win32Window::Point origin(0, 0);\n  Win32Window::Size size(GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN));',
          ));
      expect(main.readAsStringSync(), contains('SM_CXSCREEN'));
      GameWindowRunnerService.apply(project, startFullscreen: true);
      final cpp = main.readAsStringSync();
      expect(cpp, isNot(contains('SM_CXSCREEN')));
      expect(cpp, contains('Win32Window::Size size(1280, 720);'));
    });
  });

  test('Linux runner: fullscreen through GTK, hooked after the plugins', () {
    final project = _projectWithRunners(root);
    final report = GameWindowRunnerService.apply(project, startFullscreen: true);
    expect(report.warnings, isEmpty);
    final cc = File('$project/linux/runner/lumina_window_mode.cc').readAsStringSync();
    expect(cc, contains('static const gboolean kStartFullscreen = TRUE;'));
    expect(cc, contains('gtk_window_fullscreen'));
    expect(cc, contains('GDK_KEY_F11'));
    final app = File('$project/linux/runner/my_application.cc').readAsStringSync();
    expect(app, contains('#include "lumina_window_mode.h"'));
    expect(app.indexOf('lumina_window_mode_attach(window, view);'), greaterThan(app.indexOf('fl_register_plugins(')));
    final cmake = File('$project/linux/runner/CMakeLists.txt').readAsStringSync();
    expect(RegExp(r'add_executable\([^)]*"lumina_window_mode\.cc"', dotAll: true).hasMatch(cmake), isTrue);
  });

  test('a project without desktop runners is left alone', () {
    final report = GameWindowRunnerService.apply(root.path, startFullscreen: true);
    expect(report.files, isEmpty);
    expect(report.warnings, isEmpty);
  });

  group('main.dart', () {
    test('restores the window mode before the game starts, no FFI resize', () {
      final main = DartCodeGeneratorService().generateMainDart(projectName: 'Game', startFullscreen: true);
      expect(main, isNot(contains('dart:ffi')));
      expect(main, isNot(contains('GetSystemMetrics')));
      expect(main, contains('startMode: LuminaWindowMode.borderlessFullscreen'));
      expect(main, contains('LuminaGameWindow.settingsFileFor(LuminaSaveGameSubsystem.defaultSaveDirectoryPath)'));
      expect(main.indexOf('await LuminaGameWindow.restore('), lessThan(main.indexOf('runApp(')));
      expect(main.indexOf('await LuminaGameWindow.restore('),
          greaterThan(main.indexOf('LuminaSaveGameSubsystem.defaultSaveDirectoryPath =')));
    });

    test('a windowed project still restores the player choice', () {
      final main = DartCodeGeneratorService().generateMainDart(projectName: 'Game');
      expect(main, contains('startMode: LuminaWindowMode.windowed'));
    });

    test('the Build pipeline code generation carries the project setting', () async {
      final project = _projectWithRunners(root);
      Directory('$project/contents/levels').createSync(recursive: true);
      const settings = EngineScalabilitySettings(startFullscreen: true, targetFps: 90, vsyncEnabled: true);
      final result = await GenerateDartCodeUseCase()(
        projectDir: project,
        levelName: 'L_DefaultLevel',
        actors: const [],
        project: const LuminaProject(projectName: 'game', settings: settings),
      );
      expect(result.isSuccess, isTrue, reason: result.error);
      final main = File('$project/lib/main.dart').readAsStringSync();
      expect(main, contains('startMode: LuminaWindowMode.borderlessFullscreen'));
      expect(main, contains('targetFps: 90'));
      expect(main, contains('vsyncEnabled: true'));
      expect(File('$project/windows/runner/lumina_window_mode.cpp').readAsStringSync(),
          contains('kStartFullscreen = true;'));
    });
  });
}
