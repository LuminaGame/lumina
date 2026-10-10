import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

import '../../blueprint/frame_pacing_settings_blueprint.dart';
import 'display_test_support.dart';

void main() {
  late Directory temp;
  late String settingsPath;

  setUp(() {
    resetDisplay();
    LuminaGameFramePacing.resetForTesting();
    temp = Directory.systemTemp.createTempSync('lumina_pacing_');
    settingsPath = LuminaGameWindow.settingsFileFor('${temp.path}/SaveGames');
  });

  tearDown(() {
    resetDisplay();
    LuminaGameFramePacing.resetForTesting();
    temp.deleteSync(recursive: true);
  });

  Map<String, dynamic> savedFile() => jsonDecode(File(settingsPath).readAsStringSync()) as Map<String, dynamic>;

  group('project defaults', () {
    test('are in force, and what Get returns, until the player applies a choice', () {
      LuminaGameFramePacing.setProjectDefaults(targetFps: 60, vsyncEnabled: true);
      final settings = LuminaWorld(worldType: LuminaWorldType.game).userSettings;
      expect(LuminaGameFramePacing.targetFps, 60);
      expect(LuminaGameFramePacing.vsyncEnabled, isTrue);
      expect(settings.targetFps, 60);
      expect(settings.vsyncEnabled, isTrue);
      expect(LuminaGameFramePacing.hasPlayerChoice, isFalse);
    });

    test('a new project default does not override the player choice', () {
      LuminaGameFramePacing.setProjectDefaults(targetFps: 60, vsyncEnabled: true);
      LuminaGameFramePacing.apply(targetFps: 30, vsyncEnabled: false);
      LuminaGameFramePacing.setProjectDefaults(targetFps: 120, vsyncEnabled: true);
      expect(LuminaGameFramePacing.targetFps, 30);
      expect(LuminaGameFramePacing.vsyncEnabled, isFalse);
    });
  });

  group('Set Target FPS / Set VSync Enabled', () {
    test('stage the choice; Apply Scalability Settings puts it in force and notifies the game', () {
      LuminaGameFramePacing.setProjectDefaults(targetFps: 60, vsyncEnabled: true);
      final settings = LuminaWorld(worldType: LuminaWorldType.game).userSettings;
      final seen = <LuminaFramePacingSettings>[];
      void listener() => seen.add(LuminaGameFramePacing.settings.value);
      LuminaGameFramePacing.settings.addListener(listener);
      addTearDown(() => LuminaGameFramePacing.settings.removeListener(listener));

      settings.setTargetFps(30);
      settings.setVsyncEnabled(false);
      expect(settings.targetFps, 30, reason: 'Get returns the staged choice');
      expect(settings.vsyncEnabled, isFalse);
      expect(LuminaGameFramePacing.targetFps, 60, reason: 'nothing changes before Apply');
      expect(seen, isEmpty);

      settings.applySettings();
      expect(LuminaGameFramePacing.targetFps, 30);
      expect(LuminaGameFramePacing.vsyncEnabled, isFalse);
      expect(seen, [const LuminaFramePacingSettings(targetFps: 30, vsyncEnabled: false)]);
      expect(settings.targetFps, 30);
      expect(settings.vsyncEnabled, isFalse);
    });

    test('a negative target is unlimited', () {
      final settings = LuminaWorld(worldType: LuminaWorldType.game).userSettings;
      settings
        ..setTargetFps(-5)
        ..applySettings();
      expect(LuminaGameFramePacing.targetFps, 0);
    });

    test('an Apply with nothing staged keeps the pacing (a new world, a preset)', () {
      LuminaGameFramePacing.setProjectDefaults(targetFps: 60, vsyncEnabled: true);
      LuminaGameFramePacing.apply(targetFps: 120, vsyncEnabled: false);
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.beginPlay();
      world.userSettings.setOverallScalabilityLevel('Low');
      expect(LuminaGameFramePacing.targetFps, 120);
      expect(LuminaGameFramePacing.vsyncEnabled, isFalse);
    });

    test('the Blueprint nodes stage, apply and read back in the VM', () {
      LuminaGameFramePacing.setProjectDefaults(targetFps: 60, vsyncEnabled: true);
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final actor = LuminaBlueprintClass.fromDocument(framePacingSettingsBlueprint(), name: 'bp_frame_pacing_settings')
          .instantiate();
      final trace = <LuminaBlueprintTraceEvent>[];
      (actor as LuminaBlueprintRuntime).trace = trace.add;
      world.persistentLevel.registerActor(actor);
      world.beginPlay();
      world.tick(1 / 60);
      // Before the Set nodes, then after Apply.
      expect([for (final t in trace) if (t.printed != null) t.printed], ['60', 'true', '30', 'false']);
      expect(LuminaGameFramePacing.targetFps, 30);
      expect(LuminaGameFramePacing.vsyncEnabled, isFalse);
      expect(validateBlueprint(framePacingSettingsBlueprint(), className: 'bp_frame_pacing_settings').where((d) => d.isError),
          isEmpty);
    });
  });

  group('GameUserSettings.json', () {
    test('Save writes the applied player choice; without one it writes no frame rate keys', () async {
      LuminaGameFramePacing.setProjectDefaults(targetFps: 60, vsyncEnabled: true);
      final settings = LuminaWorld(worldType: LuminaWorldType.game).userSettings;
      expect(await settings.saveSettings(path: settingsPath), isTrue);
      expect(savedFile().containsKey(LuminaGameFramePacing.targetFpsKey), isFalse,
          reason: 'the project default stays the default');
      expect(savedFile().containsKey(LuminaGameFramePacing.vsyncKey), isFalse);

      settings
        ..setTargetFps(30)
        ..setVsyncEnabled(false)
        ..applySettings();
      expect(await settings.saveSettings(path: settingsPath), isTrue);
      expect(savedFile()[LuminaGameFramePacing.targetFpsKey], 30);
      expect(savedFile()[LuminaGameFramePacing.vsyncKey], isFalse);
    });

    test('the window restore puts the saved choice in force before the first frame', () async {
      await LuminaGameUserSettingsFile.update(settingsPath, {'target_fps': 120, 'vsync': false, 'window_mode': 'windowed'});
      await LuminaGameWindow.restore(settingsFilePath: settingsPath);
      // The game widget mounts after main() and brings the project defaults.
      LuminaGameFramePacing.setProjectDefaults(targetFps: 60, vsyncEnabled: true);
      expect(LuminaGameFramePacing.targetFps, 120);
      expect(LuminaGameFramePacing.vsyncEnabled, isFalse);
      expect(LuminaWorld(worldType: LuminaWorldType.game).userSettings.targetFps, 120);
    });

    test('a restore without a saved choice keeps the project defaults', () async {
      await LuminaGameUserSettingsFile.update(settingsPath, {'window_mode': 'windowed'});
      await LuminaGameWindow.restore(settingsFilePath: settingsPath);
      LuminaGameFramePacing.setProjectDefaults(targetFps: 60, vsyncEnabled: true);
      expect(LuminaGameFramePacing.targetFps, 60);
      expect(LuminaGameFramePacing.vsyncEnabled, isTrue);
      expect(LuminaGameFramePacing.hasPlayerChoice, isFalse);
    });

    test('Save, then a restart (restore), round-trips the choice', () async {
      final settings = LuminaWorld(worldType: LuminaWorldType.game).userSettings;
      settings
        ..setTargetFps(45)
        ..setVsyncEnabled(true)
        ..applySettings();
      await settings.saveSettings(path: settingsPath);

      LuminaGameFramePacing.resetForTesting();
      await LuminaGameWindow.restore(settingsFilePath: settingsPath);
      expect(LuminaGameFramePacing.targetFps, 45);
      expect(LuminaGameFramePacing.vsyncEnabled, isTrue);
    });

    test('Load Game User Settings applies the saved choice', () async {
      await LuminaGameUserSettingsFile.update(settingsPath, {'target_fps': 30, 'vsync': true});
      final settings = LuminaWorld(worldType: LuminaWorldType.game).userSettings;
      expect(await settings.loadSettings(path: settingsPath), isTrue);
      expect(LuminaGameFramePacing.targetFps, 30);
      expect(LuminaGameFramePacing.vsyncEnabled, isTrue);
    });
  });

  test('Play-In-Editor starts from the project defaults, not a previous session', () {
    LuminaGameFramePacing.apply(targetFps: 30, vsyncEnabled: false);
    LuminaGameFramePacing.beginPlayInEditor(targetFps: 60, vsyncEnabled: true);
    expect(LuminaGameFramePacing.targetFps, 60);
    expect(LuminaGameFramePacing.vsyncEnabled, isTrue);
    expect(LuminaGameFramePacing.hasPlayerChoice, isFalse);
  });
}
