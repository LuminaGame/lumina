import 'dart:convert';
import 'package:test/test.dart';
import 'package:lumina_core/lumina_core.dart';

void main() {
  group('LuminaProject & EngineScalabilitySettings Tests', () {
    test('Should construct LuminaProject with default scalability settings', () {
      final proj = LuminaProject(
        projectName: 'my_lumina_game',
        engineVersion: '0.0.1',
        activeLevel: 'contents/levels/L_DefaultLevel.lmas',
        isDirty: true,
        lastModifiedTimestamp: '2026-08-07T15:58:00Z',
        lastCodeGeneratedTimestamp: '2026-08-07T15:57:00Z',
      );

      expect(proj.projectName, equals('my_lumina_game'));
      expect(proj.engineVersion, equals('0.0.1'));
      expect(proj.isDirty, isTrue);
      expect(proj.settings.vsyncEnabled, isFalse, reason: 'VSync off by default');
      expect(proj.settings.targetFps, 0, reason: '0 = unlimited');
      expect(proj.settings.qualityPreset, equals('epic'));
      expect(proj.settings.scalability.viewDistance, equals('epic'));
      expect(proj.settings.scalability.shadowQuality, equals('high'));
      expect(proj.settings.scalability.antiAliasing, equals('fxaa'));
    });

    test('Should serialize to JSON and deserialize back correctly', () {
      final proj = LuminaProject(
        projectName: 'space_shooter',
        engineVersion: '0.0.1',
        activeLevel: 'contents/levels/L_Space.lmas',
        isDirty: false,
        lastModifiedTimestamp: '2026-08-07T16:00:00Z',
        lastCodeGeneratedTimestamp: '2026-08-07T16:00:00Z',
        settings: EngineScalabilitySettings(
          targetFps: 120,
          vsyncEnabled: false,
          qualityPreset: 'high',
          scalability: ScalabilityCategory(
            viewDistance: 'high',
            shadowQuality: 'medium',
            antiAliasing: 'msaa',
            postProcessing: 'high',
            textureQuality: 'epic',
            shadingQuality: 'high',
          ),
        ),
      );

      final map = proj.toMap();
      final jsonStr = jsonEncode(map);
      final decodedMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      final restored = LuminaProject.fromMap(decodedMap);

      expect(restored.projectName, equals('space_shooter'));
      expect(restored.settings.targetFps, equals(120));
      expect(restored.settings.vsyncEnabled, isFalse);
      expect(restored.settings.qualityPreset, equals('high'));
      expect(restored.settings.scalability.antiAliasing, equals('msaa'));
    });
  });
}
