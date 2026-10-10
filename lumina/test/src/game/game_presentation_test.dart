import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

import 'display_test_support.dart';

void main() {
  late Directory temp;
  late String settingsPath;

  setUp(() {
    resetDisplay();
    LuminaGamePresentation.reset();
    temp = Directory.systemTemp.createTempSync('lumina_presentation_');
    settingsPath = LuminaGameWindow.settingsFileFor('${temp.path}/SaveGames');
  });

  tearDown(() {
    resetDisplay();
    LuminaGamePresentation.reset();
    temp.deleteSync(recursive: true);
  });

  const flutter = LuminaPresentationMode.flutter;
  const direct = LuminaPresentationMode.direct;

  group('resolve', () {
    test('Flutter by default, Direct with frame generation', () {
      expect(LuminaGamePresentation.resolve(project: flutter), const LuminaPresentationDecision(flutter));
      expect(LuminaGamePresentation.resolve(project: flutter, frameGeneration: true),
          const LuminaPresentationDecision(direct, reason: 'frame generation'));
    });

    test('the project setting, and the player choice over it', () {
      expect(LuminaGamePresentation.resolve(project: direct), const LuminaPresentationDecision(direct, reason: 'project setting'));
      expect(LuminaGamePresentation.resolve(project: direct, player: flutter),
          const LuminaPresentationDecision(flutter, reason: 'player setting'));
      expect(LuminaGamePresentation.resolve(project: flutter, player: direct),
          const LuminaPresentationDecision(direct, reason: 'player setting'));
    });

    test('a player who chose Flutter keeps it with frame generation on', () {
      expect(LuminaGamePresentation.resolve(project: direct, player: flutter, frameGeneration: true).mode, flutter);
    });

    test('parse accepts the ids, nothing else', () {
      expect(LuminaPresentationMode.parse('direct'), direct);
      expect(LuminaPresentationMode.parse(' Flutter '), flutter);
      expect(LuminaPresentationMode.parse('vulkan'), isNull);
      expect(LuminaPresentationMode.parse(3), isNull);
    });
  });

  group('in force', () {
    test('frame generation turns Direct on and off', () {
      LuminaGamePresentation.setProjectDefault(flutter);
      LuminaGamePresentation.setFrameGenerationRequested(true);
      expect(LuminaGamePresentation.decision.value.mode, direct);
      LuminaGamePresentation.setFrameGenerationRequested(false);
      expect(LuminaGamePresentation.decision.value.mode, flutter);
    });

    test('a fallback keeps Flutter with its reason until the request changes', () {
      LuminaGamePresentation.setProjectDefault(direct);
      LuminaGamePresentation.reportFallback('unsupported on the web');
      expect(LuminaGamePresentation.requested.value.mode, direct);
      expect(LuminaGamePresentation.decision.value,
          const LuminaPresentationDecision(flutter, reason: 'unsupported on the web'));
      LuminaGamePresentation.setFrameGenerationRequested(true);
      expect(LuminaGamePresentation.decision.value, const LuminaPresentationDecision(direct, reason: 'frame generation'));
    });

    test('no view generates frames before a game applies frame generation', () {
      expect(LuminaRtxController.frameGenerationActive.value, isFalse);
    });
  });

  group('GameUserSettings.json', () {
    test('the player choice is restored before the first frame; other keys are kept', () async {
      File(settingsPath)
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode({'presentation': 'direct', 'target_fps': 90, 'custom': 'kept'}));
      LuminaGamePresentation.setProjectDefault(flutter);
      await LuminaGameWindow.restore(settingsFilePath: settingsPath);
      expect(LuminaGamePresentation.playerChoice, direct);
      expect(LuminaGamePresentation.decision.value, const LuminaPresentationDecision(direct, reason: 'player setting'));

      await LuminaGameUserSettingsFile.update(settingsPath, LuminaGamePresentation.settingsPatch());
      final saved = jsonDecode(File(settingsPath).readAsStringSync()) as Map<String, dynamic>;
      expect(saved['presentation'], 'direct');
      expect(saved['custom'], 'kept');
    });

    test('an unknown value leaves the project default', () async {
      File(settingsPath)
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode({'presentation': 'metal'}));
      LuminaGamePresentation.setProjectDefault(direct);
      await LuminaGameWindow.restore(settingsFilePath: settingsPath);
      expect(LuminaGamePresentation.playerChoice, isNull);
      expect(LuminaGamePresentation.decision.value.reason, 'project setting');
    });
  });
}
