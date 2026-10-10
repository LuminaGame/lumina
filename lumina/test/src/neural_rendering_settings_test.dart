import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_core/lumina_core.dart' show ProjectNeuralRenderingSettings;

/// OpenDLSS-NR (experimental, third-party) at runtime: the weights path a view
/// uses, the game user setting, and the controller's states on GPU 1 with
/// synthetic models (never real weights).
void main() {
  tearDown(() {
    LuminaNeuralRendering.projectOptIn = null;
    LuminaNeuralRendering.editorWeightsPath = null;
  });

  const acknowledged = ProjectNeuralRenderingSettings(enabled: true, acknowledgedAt: '2026-10-10T09:00:00.000Z');

  group('weights path', () {
    test('the editor path wins, then the player setting, then the environment', () {
      const env = {LuminaNeuralRendering.weightsEnvironmentVariable: '/env/nr'};
      expect(LuminaNeuralRendering.resolveWeightsPath(environment: env), '/env/nr');
      expect(LuminaNeuralRendering.resolveWeightsPath(userSetting: '/player/nr/manifest.json', environment: env), '/player/nr');
      LuminaNeuralRendering.editorWeightsPath = '/editor/nr';
      expect(LuminaNeuralRendering.resolveWeightsPath(userSetting: '/player/nr', environment: env), '/editor/nr');
      LuminaNeuralRendering.editorWeightsPath = null;
      expect(LuminaNeuralRendering.resolveWeightsPath(environment: const {}), '');
    });

    test('the player setting is kept in GameUserSettings.json only when set', () async {
      final dir = await Directory.systemTemp.createTemp('lumina_nr_settings');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/${LuminaGameUserSettingsFile.fileName}';
      final a = LuminaWorld(worldType: LuminaWorldType.game).userSettings;
      expect(a.toMap().containsKey(LuminaNeuralRendering.userSettingsKey), isFalse);
      a.setNeuralRenderingWeightsPath(' D:/models/nr ');
      expect(await a.saveSettings(path: path), isTrue);
      final b = LuminaWorld(worldType: LuminaWorldType.game).userSettings;
      expect(await b.loadSettings(path: path), isTrue);
      expect(b.neuralRenderingWeightsPath, 'D:/models/nr');
      // no view: nothing runs, nothing throws
      expect(b.neuralRenderingStatus.state, LuminaNeuralRenderingState.off);
    });
  });

  group('controller', () {
    late Directory temp;
    setUpAll(() async {
      temp = await Directory.systemTemp.createTemp('lumina_nr_controller');
    });
    tearDownAll(() => temp.delete(recursive: true));

    test('off unless the project opted in and accepted the warning; unsupported on the noop backend', () async {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      final view = engine.createView();
      final controller = LuminaNeuralRenderingController(engine: engine, view: view);
      try {
        await controller.apply(null);
        expect(controller.status.value.state, LuminaNeuralRenderingState.off);
        await controller.apply(const ProjectNeuralRenderingSettings(enabled: true));
        expect(controller.status.value.state, LuminaNeuralRenderingState.off);
        await controller.apply(acknowledged, weightsPath: temp.path);
        expect(controller.status.value.state, LuminaNeuralRenderingState.unsupported);
        expect(controller.status.value.reason, contains('Vulkan'));
      } finally {
        controller.dispose();
        view.dispose();
        engine.dispose();
      }
    });

    group('on GPU 1', () {
      FilamentEngine? engine;
      FilamentView? view;
      LuminaNeuralRenderingController? controller;

      setUp(() {
        LuminaNeuralRendering.requestDeviceFeatures();
        try {
          engine = FilamentEngine.create(backend: FilamentBackend.vulkan);
        } catch (_) {
          engine = null;
        }
        if (engine != null) {
          view = engine!.createView();
          controller = LuminaNeuralRenderingController(engine: engine!, view: view!);
        }
      });

      tearDown(() {
        controller?.dispose();
        view?.dispose();
        engine?.dispose();
        controller = null;
        view = null;
        engine = null;
      });

      bool skip() {
        if (engine == null) {
          markTestSkipped('needs a Vulkan device');
          return true;
        }
        final capability = OpenDlssNr.capability(engine!);
        if (!capability.supported) {
          markTestSkipped('OpenDLSS-NR not supported here: ${capability.reason}');
          return true;
        }
        return false;
      }

      test('no weights path: weights missing, with the places to set one', () async {
        if (skip()) return;
        await controller!.apply(acknowledged, weightsPath: '');
        expect(controller!.status.value.state, LuminaNeuralRenderingState.weightsMissing);
        expect(controller!.status.value.reason, contains(LuminaNeuralRendering.weightsEnvironmentVariable));
      });

      test('a synthetic model of the right layout runs; a wrong-size one is invalid weights', () async {
        if (skip()) return;
        final good = '${temp.path}/good';
        OpenDlssNr.writeSyntheticModel(good);
        await controller!.apply(acknowledged.copyWith(intensity: 0.5), weightsPath: '$good/manifest.json');
        expect(controller!.status.value.state, LuminaNeuralRenderingState.running, reason: controller!.status.value.reason);
        expect(controller!.passStatus?.failed, isFalse);

        final bad = '${temp.path}/bad';
        OpenDlssNr.writeSyntheticModel(bad);
        final stage = File('$bad/model/stage5.bin');
        final bytes = await stage.readAsBytes();
        await stage.writeAsBytes(bytes.sublist(0, bytes.length - 3));
        await controller!.apply(acknowledged, weightsPath: bad);
        expect(controller!.status.value.state, LuminaNeuralRenderingState.invalidWeights);
        expect(controller!.status.value.reason, contains('stage5'));
        expect(controller!.passStatus, isNull, reason: 'the previous pass was released');

        await controller!.apply(null);
        expect(controller!.status.value.state, LuminaNeuralRenderingState.off);
      });
    });
  });
}
