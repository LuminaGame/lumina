import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/models/lumina_project.dart';

void main() {
  group('LuminaProject settings sections', () {
    test('legacy manifest without new sections loads with defaults and round-trips them', () {
      final legacy = {
        'project_name': 'Old',
        'engine_version': '0.0.1',
        'active_level': 'contents/levels/L_Main.lmas',
        'settings': {'target_fps': 60, 'vsync_enabled': true, 'quality_preset': 'high'},
      };
      final p = LuminaProject.fromMap(legacy);
      expect(p.settings.targetFps, 60);
      expect(p.settings.vsyncEnabled, isTrue);
      expect(p.settings.qualityPreset, 'high');
      expect(p.description, '');
      expect(p.input.actions, isEmpty);
      expect(p.mapsAndModes.defaultGameMode, 'LuminaGameMode');
      expect(p.physics.gravityZ, -980.0);
      expect(p.packaging.targets, ['linux']);

      final map = p.toMap();
      expect(map['input'], isA<Map>());
      expect(map['maps_and_modes'], isA<Map>());
      expect(map['physics'], isA<Map>());
      expect(map['packaging'], isA<Map>());
      expect((map['settings'] as Map)['quality_preset'], 'high');
      final again = LuminaProject.fromMap(jsonDecode(jsonEncode(map)) as Map<String, dynamic>);
      expect(again.settings.targetFps, 60);
      expect(again.settings.vsyncEnabled, isTrue);
    });

    test('enhanced input structure round-trips exactly', () {
      const input = ProjectInputSettings(
        actions: [
          ProjectInputAction(name: 'IA_Move', valueType: ProjectInputValueType.axis2D),
          ProjectInputAction(name: 'IA_Jump'),
        ],
        mappingContexts: [
          ProjectMappingContext(name: 'Gameplay', priority: 0, mappings: [
            ProjectInputMapping(action: 'IA_Move', keyId: 0x77, keyLabel: 'W', scale: 1.0, axis: 'Y'),
            ProjectInputMapping(action: 'IA_Move', keyId: 0x73, keyLabel: 'S', scale: -1.0, axis: 'Y'),
            ProjectInputMapping(action: 'IA_Move', keyId: 0x64, keyLabel: 'D', scale: 1.0, axis: 'X'),
            ProjectInputMapping(action: 'IA_Jump', keyId: 0x20, keyLabel: 'Space'),
          ]),
        ],
      );
      final p = LuminaProject(projectName: 'P', input: input);
      final json = jsonEncode(p.toMap());
      final back = LuminaProject.fromMap(jsonDecode(json) as Map<String, dynamic>);
      expect(back.input.actions.map((a) => a.name), ['IA_Move', 'IA_Jump']);
      expect(back.input.actions.first.valueType, ProjectInputValueType.axis2D);
      final ctx = back.input.mappingContexts.single;
      expect(ctx.name, 'Gameplay');
      expect(ctx.mappings.length, 4);
      expect(ctx.mappings[1].scale, -1.0);
      expect(ctx.mappings[1].axis, 'Y');
      expect(ctx.mappings[3].keyLabel, 'Space');
      expect(ctx.mappings[3].axis, '');
      final raw = jsonDecode(json) as Map<String, dynamic>;
      expect((raw['input'] as Map)['mapping_contexts'][0]['mappings'][0], {
        'action': 'IA_Move', 'key_id': 0x77, 'key': 'W', 'scale': 1.0, 'axis': 'Y',
      });
    });

    test('quality presets expand to per-category tiers and defaults follow the spec', () {
      expect(kQualityPresets, ['Low', 'Medium', 'High', 'Epic', 'Cinematic']);
      expect(ScalabilityPresets.forPreset('Low').shadowQuality, 'low');
      expect(ScalabilityPresets.forPreset('low').antiAliasing, 'none');
      expect(ScalabilityPresets.forPreset('Cinematic').antiAliasing, 'taa');
      expect(ScalabilityPresets.forPreset('Epic').toMap(), const ScalabilityCategory().toMap());
      const fresh = EngineScalabilitySettings();
      expect(fresh.vsyncEnabled, isFalse);
      expect(fresh.targetFps, 0);
    });

    test('maps & modes, physics and packaging round-trip', () {
      final p = LuminaProject(
        projectName: 'P',
        description: 'A test game',
        mapsAndModes: const ProjectMapsAndModes(editorStartupMap: 'contents/levels/L_A.lmas', gameDefaultMap: 'contents/levels/L_B.lmas', defaultGameMode: 'BP_MyMode'),
        physics: const ProjectPhysicsSettings(gravityZ: -500, fixedTimestep: 0.02),
        packaging: const ProjectPackagingSettings(targets: ['windows'], outputDir: 'dist'),
      );
      final back = LuminaProject.fromMap(jsonDecode(jsonEncode(p.toMap())) as Map<String, dynamic>);
      expect(back.description, 'A test game');
      expect(back.mapsAndModes.editorStartupMap, 'contents/levels/L_A.lmas');
      expect(back.mapsAndModes.gameDefaultMap, 'contents/levels/L_B.lmas');
      expect(back.mapsAndModes.defaultGameMode, 'BP_MyMode');
      expect(back.physics.gravityZ, -500);
      expect(back.physics.fixedTimestep, 0.02);
      expect(back.packaging.targets, ['windows']);
      expect(back.packaging.outputDir, 'dist');
      expect(flutterBuildSubcommand('android'), 'apk');
    });
  });

  // Plugin settings and keys this version does not know.
  group('LuminaProject plugin_settings and unknown keys', () {
    test('plugin_settings round-trips through JSON', () {
      const project = LuminaProject(projectName: 'P', pluginSettings: {
        'lumina_plugin_miniai': {'defaultMode': 'plan'},
      });
      final back = LuminaProject.fromMap(jsonDecode(jsonEncode(project.toMap())) as Map<String, dynamic>);
      expect(back.pluginSettings, {
        'lumina_plugin_miniai': {'defaultMode': 'plan'},
      });
      expect(back.copyWith(description: 'x').pluginSettings, back.pluginSettings);
    });

    test('an unknown top-level key survives a load and a save; known keys win', () {
      final map = {
        ...const LuminaProject(projectName: 'P').toMap(),
        'future_feature': {'a': 1},
      };
      final back = LuminaProject.fromMap(map);
      expect(back.extraFields, {'future_feature': {'a': 1}});
      final saved = back.copyWith(description: 'changed').toMap();
      expect(saved['future_feature'], {'a': 1});
      expect(saved['description'], 'changed');
      expect(saved['project_name'], 'P');
    });

    test('empty plugin settings write no key', () {
      expect(const LuminaProject(projectName: 'P').toMap().containsKey('plugin_settings'), isFalse);
    });
  });
}
