import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/core/window/lumina_window.dart';
import 'package:lumina_ui/ui/core/window/window_state_store.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_preferences.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show Rect, Size;

import '../helpers/fake_native_window.dart';

/// The window's size, position, maximized and fullscreen
/// state live in the editor preferences (`editor_preferences.json` under the
/// config dir) and come back on the next start, before the window shows.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory configDir;

  setUp(() => configDir = Directory.systemTemp.createTempSync('lumina_window_state_'));
  tearDown(() {
    if (configDir.existsSync()) configDir.deleteSync(recursive: true);
  });

  const options = WindowOptions(size: Size(1920, 1080), center: true, titleBarStyle: TitleBarStyle.hidden);

  test('the store round-trips through editor_preferences.json and keeps the other preferences', () {
    final prefs = EditorPreferences.load(configDir: configDir);
    prefs.setImportWorkers(3);
    final store = WindowStateStore(configDir: configDir);
    expect(store.load(), isNull, reason: 'nothing saved yet');
    store.save(const WindowStateData(bounds: Rect.fromLTWH(120, 90, 1400, 900), maximized: true, fullScreen: false));
    final json = jsonDecode(File('${configDir.path}/${EditorPreferences.fileName}').readAsStringSync()) as Map<String, dynamic>;
    expect(json['importWorkers'], 3, reason: 'the window block sits beside the other preferences');
    expect(json['window'], {'x': 120.0, 'y': 90.0, 'width': 1400.0, 'height': 900.0, 'maximized': true, 'fullScreen': false});
    final back = WindowStateStore(configDir: configDir).load()!;
    expect(back.bounds, const Rect.fromLTWH(120, 90, 1400, 900));
    expect(back.maximized, isTrue);
    expect(back.fullScreen, isFalse);
    // A preference change afterwards keeps the window block.
    EditorPreferences.load(configDir: configDir).setImportWorkers(2);
    expect(WindowStateStore(configDir: configDir).load()!.bounds, const Rect.fromLTWH(120, 90, 1400, 900));
  });

  test('an unreadable or undersized block is ignored', () {
    File('${configDir.path}/${EditorPreferences.fileName}')
      ..createSync(recursive: true)
      ..writeAsStringSync('{"window": {"x": 0, "y": 0, "width": 20, "height": 10}}');
    expect(WindowStateStore(configDir: configDir).load(), isNull);
    File('${configDir.path}/${EditorPreferences.fileName}').writeAsStringSync('not json');
    expect(WindowStateStore(configDir: configDir).load(), isNull);
  });

  test('size, position and maximized state saved on quit are restored on the next start', () async {
    // --- first session: the user moves and resizes, then maximizes, quits --
    final first = FakeNativeWindow(bounds: const Rect.fromLTWH(100, 80, 1280, 720))..install();
    final a = LuminaWindow(store: WindowStateStore(configDir: configDir));
    await a.startup(options);
    first.bounds = const Rect.fromLTWH(333, 222, 1500, 950);
    await first.emit('resize');
    await first.emit('move');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await a.toggleMaximize();
    await Future<void>.delayed(Duration.zero);
    expect(a.isMaximized, isTrue);
    expect(await a.requestClose(), isTrue);
    expect(first.destroyed, isTrue);
    a.dispose();
    first.uninstall();

    final saved = WindowStateStore(configDir: configDir).load()!;
    expect(saved.bounds, const Rect.fromLTWH(333, 222, 1500, 950),
        reason: 'the restored (un-maximized) bounds are kept, not the maximized screen rect');
    expect(saved.maximized, isTrue);

    // --- second session: restored before the window is shown ---------------
    final second = FakeNativeWindow(bounds: const Rect.fromLTWH(0, 0, 800, 600))..install();
    final b = LuminaWindow(store: WindowStateStore(configDir: configDir));
    await b.startup(options);
    await Future<void>.delayed(Duration.zero);
    expect(second.bounds, const Rect.fromLTWH(333, 222, 1500, 950));
    expect(second.maximized, isTrue);
    final methods = second.methods.toList();
    expect(methods.indexOf('maximize'), lessThan(methods.indexOf('show')), reason: 'restored before it shows');
    expect(methods, isNot(contains('setAlignment')), reason: 'a saved position is not re-centred');
    b.dispose();
    second.uninstall();
  });

  test('fullscreen at quit comes back fullscreen', () async {
    final first = FakeNativeWindow()..install();
    final a = LuminaWindow(store: WindowStateStore(configDir: configDir));
    await a.startup(options);
    await a.toggleFullScreen();
    await Future<void>.delayed(Duration.zero);
    expect(await a.requestClose(), isTrue);
    a.dispose();
    first.uninstall();
    expect(WindowStateStore(configDir: configDir).load()!.fullScreen, isTrue);

    final second = FakeNativeWindow()..install();
    final b = LuminaWindow(store: WindowStateStore(configDir: configDir));
    await b.startup(options);
    expect(second.fullScreen, isTrue);
    b.dispose();
    second.uninstall();
  });

  // On Windows the plugin can answer getBounds with null fields
  // (an integration-test window); window_manager then throws a TypeError,
  // which escaped _guard and failed the test running the editor.
  test('a window whose bounds cannot be read maximizes, tracks resizes and closes without throwing', () async {
    final fake = FakeNativeWindow()
      ..boundsUnavailable = true
      ..install();
    addTearDown(fake.uninstall);
    final w = LuminaWindow(store: WindowStateStore(configDir: configDir));
    addTearDown(w.dispose);
    // Awaited calls rethrow; the resize timer's read is unawaited, so an
    // error there fails the test as an uncaught error.
    await w.startup(options);
    await w.toggleMaximize();
    await fake.emit('resize');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await w.toggleMaximize();
    expect(await w.requestClose(), isTrue);
    expect(w.normalBounds, isNull);
    expect(fake.destroyed, isTrue);
  });
}