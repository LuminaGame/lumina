import 'dart:convert';
import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

import '../smoke/smoke_helper.dart';

/// OpenDLSS-NR (experimental, third-party) on the external post pass: the
/// model folder validation, the capability check and the pass itself, run on
/// synthetic models of the network's layout (never real weights).
void main() {
  late Directory temp;

  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('opendlss_nr_test');
  });

  tearDownAll(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Future<Directory> synthetic(String name, {bool random = false}) async {
    final dir = Directory('${temp.path}/$name');
    OpenDlssNr.writeSyntheticModel(dir.path, seed: 7, random: random);
    return dir;
  }

  Future<Map<String, dynamic>> readManifest(Directory dir) async =>
      jsonDecode(await File('${dir.path}/manifest.json').readAsString()) as Map<String, dynamic>;

  Future<void> writeManifest(Directory dir, Map<String, dynamic> manifest) =>
      File('${dir.path}/manifest.json').writeAsString(jsonEncode(manifest));

  group('model validation', () {
    test('a synthetic model of the network layout is valid', () async {
      final dir = await synthetic('valid');
      final check = OpenDlssNr.validateModel(dir.path, verifyHashes: true);
      expect(check.code, OpenDlssNrModelCode.ok, reason: check.message);
      expect(check.blockCount, 71);
      expect(check.tensorCount, 153);
      expect(check.stageCount, 11);
      expect(check.totalBytes, greaterThan(140 * 1000 * 1000));
    });

    test('a missing folder or manifest is "missing"', () async {
      expect(OpenDlssNr.validateModel('${temp.path}/nowhere').code, OpenDlssNrModelCode.missing);
      expect(OpenDlssNr.validateModel('').code, OpenDlssNrModelCode.missing);
      final empty = await Directory('${temp.path}/empty').create();
      final check = OpenDlssNr.validateModel(empty.path);
      expect(check.code, OpenDlssNrModelCode.missing);
      expect(check.message, contains('manifest.json'));
    });

    test('a stage file one byte short is rejected naming the stage', () async {
      final dir = await synthetic('truncated');
      final file = File('${dir.path}/model/stage3.bin');
      final bytes = await file.readAsBytes();
      await file.writeAsBytes(bytes.sublist(0, bytes.length - 1));
      final check = OpenDlssNr.validateModel(dir.path);
      expect(check.code, OpenDlssNrModelCode.stageMismatch);
      expect(check.message, contains('stage3'));
    });

    test('a manifest of another network (70 blocks) is rejected', () async {
      final dir = await synthetic('blocks');
      final manifest = await readManifest(dir);
      (manifest['totals'] as Map<String, dynamic>)['blockCount'] = 70;
      await writeManifest(dir, manifest);
      final check = OpenDlssNr.validateModel(dir.path);
      expect(check.code, OpenDlssNrModelCode.invalidManifest);
      expect(check.message, contains('70'));
    });

    test('a tensor past the end of its stage is rejected', () async {
      final dir = await synthetic('past');
      final manifest = await readManifest(dir);
      final tensor = (manifest['tensors'] as List).first as Map<String, dynamic>;
      tensor['stageOffset'] = 1 << 30;
      await writeManifest(dir, manifest);
      expect(OpenDlssNr.validateModel(dir.path).code, OpenDlssNrModelCode.layoutMismatch);
    });

    test('a tensor of the wrong size or a missing tensor is rejected', () async {
      final dir = await synthetic('layout');
      final manifest = await readManifest(dir);
      final tensors = manifest['tensors'] as List;
      final block5 = tensors.cast<Map<String, dynamic>>().firstWhere((t) => t['name'] == 'block5.layer0.layer');
      block5['byteLength'] = (block5['byteLength'] as int) - 16;
      await writeManifest(dir, manifest);
      final check = OpenDlssNr.validateModel(dir.path);
      expect(check.code, OpenDlssNrModelCode.layoutMismatch);
      expect(check.message, contains('block5.layer0.layer'));

      tensors.removeWhere((t) => (t as Map)['name'] == 'block70.layer0.blend_scale');
      block5['byteLength'] = (block5['byteLength'] as int) + 16;
      await writeManifest(dir, manifest);
      final missing = OpenDlssNr.validateModel(dir.path);
      expect(missing.code, OpenDlssNrModelCode.layoutMismatch);
      expect(missing.message, contains('blend_scale'));
    });

    test('not JSON, a deeply nested manifest or an unsafe stage file name is rejected', () async {
      final dir = await synthetic('bad');
      final original = await readManifest(dir);
      await File('${dir.path}/manifest.json').writeAsString('not json {');
      expect(OpenDlssNr.validateModel(dir.path).code, OpenDlssNrModelCode.invalidManifest);
      await File('${dir.path}/manifest.json').writeAsString('${'[' * 5000}${']' * 5000}');
      expect(OpenDlssNr.validateModel(dir.path).code, OpenDlssNrModelCode.invalidManifest);
      ((original['stages'] as List).first as Map<String, dynamic>)['file'] = '../../outside.bin';
      await writeManifest(dir, original);
      expect(OpenDlssNr.validateModel(dir.path).code, OpenDlssNrModelCode.stageMismatch);
    });

    test('a changed stage byte fails only the hash check', () async {
      final dir = await synthetic('hash');
      final file = File('${dir.path}/model/stage0.bin');
      final bytes = await file.readAsBytes();
      bytes[100] ^= 0x01;
      await file.writeAsBytes(bytes);
      expect(OpenDlssNr.validateModel(dir.path).code, OpenDlssNrModelCode.ok);
      expect(OpenDlssNr.validateModel(dir.path, verifyHashes: true).code, OpenDlssNrModelCode.hashMismatch);
    });
  });

  test('the noop backend cannot run the pass and says why', () async {
    final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    final view = engine.createView();
    try {
      final capability = OpenDlssNr.capability(engine);
      expect(capability.supported, isFalse);
      expect(capability.code, OpenDlssNrCapabilityCode.notVulkan);
      expect(capability.reason, contains('Vulkan'));
      final dir = await synthetic('noop');
      expect(() => OpenDlssNr.loadModel(engine, dir.path), throwsA(isA<StateError>()));
    } finally {
      view.dispose();
      engine.dispose();
    }
  });

  group('the pass on Vulkan (GPU 1)', () {
    SmokeRig? rig;
    LoadedGltf? gltf;
    OpenDlssNrModel? model;
    OpenDlssNrPass? pass;

    void boot({int width = 1024, int height = 768}) {
      OpenDlssNr.requestDeviceFeatures();
      FilamentEngine? engine;
      try {
        engine = FilamentEngine.create(backend: FilamentBackend.vulkan);
      } catch (_) {
        engine = null;
      }
      if (engine == null) return;
      rig = SmokeRig.adopt(engine, width: width, height: height);
      rig!.addSun();
      gltf = loadGltfIntoScene(rig!, 'Props/AC_units/ac_unit_a_300x300.glb');
    }

    tearDown(() {
      pass?.destroy();
      pass = null;
      model?.destroy();
      model = null;
      if (gltf != null) gltf!.dispose(rig!.scene);
      gltf = null;
      rig?.dispose();
      rig = null;
    });

    bool skipWithout() {
      if (rig == null) {
        markTestSkipped('needs a Vulkan device');
        return true;
      }
      final capability = OpenDlssNr.capability(rig!.engine);
      if (!capability.supported) {
        markTestSkipped('OpenDLSS-NR not supported here: ${capability.reason}');
        return true;
      }
      return false;
    }

    test('the RTX PRO 2000 runs it once the features are requested', () {
      boot();
      if (rig == null) return markTestSkipped('needs a Vulkan device');
      final capability = OpenDlssNr.capability(rig!.engine);
      // ignore: avoid_print
      print('capability: $capability');
      expect(capability.supported, isTrue, reason: capability.reason);
    });

    test('a synthetic model runs every frame without failing and is timed', () async {
      boot();
      if (skipWithout()) return;
      final r = rig!;
      final dir = await synthetic('gpu', random: true);
      model = OpenDlssNr.loadModel(r.engine, dir.path);
      pass = OpenDlssNrPass.create(engine: r.engine, view: r.view, model: model!);
      final frame = r.renderFrame(warmup: 40);
      final status = pass!.status;
      // ignore: avoid_print
      print('1024x768: ${status.gpuMs.toStringAsFixed(2)} ms last, ${status.gpuMsAverage.toStringAsFixed(2)} ms average, '
          '${status.dispatches} dispatches, ${(status.deviceBytes / (1 << 20)).toStringAsFixed(0)} MiB');
      expect(status.failed, isFalse, reason: status.failure);
      expect(status.frames, greaterThanOrEqualTo(40));
      expect((status.width, status.height), (1024, 768));
      expect(status.gpuMsAverage, greaterThan(0));
      expect(frame.any((b) => b != 0), isTrue);
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('a bypassed pass leaves the frame as it was', () async {
      boot(width: 512, height: 384);
      if (skipWithout()) return;
      final r = rig!;
      final reference = r.renderFrame(warmup: 6);
      final dir = await synthetic('bypass');
      model = OpenDlssNr.loadModel(r.engine, dir.path);
      pass = OpenDlssNrPass.create(engine: r.engine, view: r.view, model: model!, controls: const OpenDlssNrControls(enabled: false));
      final through = r.renderFrame(warmup: 6);
      expect(pass!.status.failed, isFalse, reason: pass!.status.failure);
      var sum = 0;
      for (var i = 0; i < reference.length; i++) {
        sum += (reference[i] - through[i]).abs();
      }
      expect(sum / reference.length, lessThan(2.0));
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('1920x1080 is timed too', () async {
      boot(width: 1920, height: 1080);
      if (skipWithout()) return;
      final r = rig!;
      final dir = await synthetic('gpu1080', random: true);
      model = OpenDlssNr.loadModel(r.engine, dir.path);
      pass = OpenDlssNrPass.create(engine: r.engine, view: r.view, model: model!);
      r.renderFrame(warmup: 40);
      final status = pass!.status;
      // ignore: avoid_print
      print('1920x1080: ${status.gpuMs.toStringAsFixed(2)} ms last, ${status.gpuMsAverage.toStringAsFixed(2)} ms average, '
          '${status.dispatches} dispatches, ${(status.deviceBytes / (1 << 20)).toStringAsFixed(0)} MiB');
      expect(status.failed, isFalse, reason: status.failure);
      // Filament sizes the colour target in whole tiles: 1920x1088 for a 1920x1080 view.
      expect(status.width, 1920);
      expect(status.height, inInclusiveRange(1080, 1088));
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('a model that cannot load gives a reason and no pass', () async {
      boot(width: 320, height: 240);
      if (rig == null) return markTestSkipped('needs a Vulkan device');
      expect(
        () => OpenDlssNr.loadModel(rig!.engine, '${temp.path}/not_there'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', isNotEmpty)),
      );
    });
  });
}
