import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

import 'display_test_support.dart';

void main() {
  late Directory temp;
  late String saveDir;
  late String settingsPath;
  late String legacyPath;

  Map<String, dynamic> saved() => jsonDecode(File(settingsPath).readAsStringSync()) as Map<String, dynamic>;

  setUp(() {
    resetDisplay();
    temp = Directory.systemTemp.createTempSync('lumina_settings_');
    saveDir = '${temp.path}/SaveGames';
    settingsPath = LuminaGameWindow.settingsFileFor(saveDir);
    legacyPath = '${temp.path}/user_settings.json';
  });

  tearDown(() {
    resetDisplay();
    temp.deleteSync(recursive: true);
  });

  test('the settings file is GameUserSettings.json in the save directory; the legacy file sits beside it', () {
    expect(settingsPath.replaceAll(r'\', '/'), '${temp.path.replaceAll(r'\', '/')}/SaveGames/GameUserSettings.json');
    expect(LuminaGameUserSettingsFile.legacyPathFor(settingsPath).replaceAll(r'\', '/'),
        legacyPath.replaceAll(r'\', '/'));
  });

  test('update merges keys, removes null ones and keeps the rest', () async {
    expect(await LuminaGameUserSettingsFile.update(settingsPath, {'a': 1, 'b': 'x'}), isTrue);
    expect(await LuminaGameUserSettingsFile.update(settingsPath, {'b': null, 'c': true}), isTrue);
    expect(saved(), {'a': 1, 'c': true});
  });

  test('concurrent writers never lose each other\'s keys', () async {
    await Future.wait([
      for (var k = 0; k < 20; k++) LuminaGameUserSettingsFile.update(settingsPath, {'key$k': k}),
    ]);
    expect(saved().length, 20);
  });

  test('a legacy user_settings.json is merged once, unknown keys kept, then removed', () async {
    File(legacyPath).writeAsStringSync(jsonEncode({'window_mode': 'borderless_fullscreen', 'mod_option': 7}));
    Directory(saveDir).createSync(recursive: true);
    File(settingsPath).writeAsStringSync(jsonEncode({'shadow_quality': 'Low', 'mod_option': 1}));
    installRunner(FakeRunnerWindow());
    final mode = await LuminaGameWindow.restore(settingsFilePath: settingsPath);
    expect(mode, LuminaWindowMode.borderlessFullscreen);
    expect(File(legacyPath).existsSync(), isFalse);
    // The settings file's own value wins over the legacy one.
    expect(saved(), {'shadow_quality': 'Low', 'mod_option': 1, 'window_mode': 'borderless_fullscreen'});
    expect(await LuminaGameUserSettingsFile.migrateLegacy(path: settingsPath), isFalse);
  });

  test('Save Game User Settings keeps the window mode and keys it does not know', () async {
    Directory(saveDir).createSync(recursive: true);
    File(settingsPath).writeAsStringSync(jsonEncode({'window_mode': 'borderless_fullscreen', 'newer_setting': 'kept'}));
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final settings = world.userSettings;
    settings.setShadowQuality('Low');
    expect(await settings.saveSettings(path: settingsPath), isTrue);
    final data = saved();
    expect(data['window_mode'], 'borderless_fullscreen');
    expect(data['newer_setting'], 'kept');
    expect(data['shadow_quality'], 'Low');
  });

  test('Set Screen Resolution is staged until applied, then persisted and loaded back', () async {
    final window = FakeRunnerWindow();
    installRunner(window);
    await LuminaGameWindow.restore(settingsFilePath: settingsPath);
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final settings = world.userSettings;

    settings.setScreenResolution(1920, 1080);
    settings.setFullscreenMonitor(0);
    expect(settings.screenResolutionSetting, (1920, 1080));
    expect(window.resizes, isEmpty);
    expect(LuminaGameDisplay.screenResolution, isNull);

    settings.applySettings();
    await LuminaGameDisplay.pendingApply;
    await LuminaGameUserSettingsFile.idle;
    expect(window.resizes, [(1920, 1080)]);
    expect(saved()['screen_resolution'], {'width': 1920, 'height': 1080});

    // An apply with nothing staged leaves the window alone.
    settings.applySettings();
    await LuminaGameDisplay.pendingApply;
    expect(window.resizes, [(1920, 1080)]);

    // Save a copy, choose native, load the copy: its resolution is applied again.
    final copy = '${temp.path}/copy.json';
    expect(await settings.saveSettings(path: copy), isTrue);
    settings.setScreenResolution(0, 0);
    settings.applySettings();
    await LuminaGameDisplay.pendingApply;
    expect(LuminaGameDisplay.screenResolution, isNull);
    expect(await settings.loadSettings(path: copy), isTrue);
    await LuminaGameDisplay.pendingApply;
    expect(LuminaGameDisplay.screenResolution, (1920, 1080));
  });
}
