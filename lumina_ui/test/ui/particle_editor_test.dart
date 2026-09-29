// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/particle_system_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/particle_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/particle/curve_editors.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/particle/particle_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Every scenario runs against a real temp project whose PARTICLE `.lmas`
/// lives on disk. The emitter simulation is the real
/// `LuminaParticleSystemComponent` — pure Dart CPU SoA, so the playback
/// scenarios need no GPU; only the Filament render path does, and that is
/// covered by integration_test/smoke/particle_editor_smoke_test.dart.
void main() {
  late Directory tempDir;
  late Directory projDir;
  late String assetPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_particle_editor_test_');
    projDir = Directory('${tempDir.path}/VfxGame')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'VfxGame', activeLevel: 'contents/levels/L_Main.lmas');
    File('${projDir.path}/VfxGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    assetPath = '${projDir.path}/contents/effects/PS_Fountain.lmas';
    Directory('${projDir.path}/contents/effects').createSync(recursive: true);
    // A brand new PARTICLE asset exactly as the Content Browser writes one:
    // no particle_system document yet.
    File(assetPath).writeAsBytesSync(
      const LuminaAsset(assetId: 'PS_Fountain', name: 'PS_Fountain', type: AssetType.particle).toProtoBufferBytes(),
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  ParticleEditorViewModel openVm() {
    final vm = ParticleEditorViewModel(assetPath: assetPath, projectDirPath: projDir.path);
    vm.open();
    return vm;
  }

  LuminaAsset readAsset() => LuminaAsset.fromBytes(File(assetPath).readAsBytesSync());

  /// Writes a real FILAMESH `.lmas` the mesh renderer picker can select.
  String writeMeshAsset(String name) {
    final path = '${projDir.path}/contents/meshes/$name.lmas';
    Directory('${projDir.path}/contents/meshes').createSync(recursive: true);
    File(path).writeAsBytesSync(LuminaAsset(
      assetId: name,
      name: name,
      type: AssetType.filamesh,
      rawPayload: Uint8List.fromList(utf8.encode('glTF-placeholder')),
    ).toProtoBufferBytes());
    return path;
  }

  group('document defaults & persistence', () {
    test('a new PARTICLE .lmas opens with one emitter carrying the engine defaults', () {
      final vm = openVm();
      expect(vm.isLoaded, isTrue);
      expect(vm.emitters, hasLength(1));
      expect(vm.emitters.single.enabled, isTrue);

      final c = vm.config;
      final defaults = LuminaParticleEmitterConfig();
      expect(c.spawnRate, defaults.spawnRate);
      expect(c.spawnRate, 10.0);
      expect(c.maxParticles, 256);
      expect(c.gravity.x, 0.0);
      expect(c.gravity.y, -980.0, reason: 'engine default, cm/s²');
      expect(c.gravity.z, 0.0);
      expect(c.looping, isTrue);
      expect(c.duration, 1.0);
      expect(c.billboard, isTrue);
      expect(c.meshAssetPath, isNull);
      expect(c.bursts, isEmpty);
      expect(vm.isDirty, isFalse);
      vm.dispose();
    });

    test('full field-by-field round trip through the .lmas on disk', () async {
      final vm = openVm();
      vm.setSpawnRate(50.0);
      vm.addBurst(0.5, 5);
      vm.setConeAngleDegrees(15.0);
      vm.setMaxParticles(512);
      vm.setLifetimeMin(0.25);
      vm.setLifetimeMax(2.5);
      vm.setSpeedMin(1.5);
      vm.setSpeedMax(6.0);
      vm.setInheritVelocityScale(Vector3(0.1, 0.2, 0.3));
      vm.setGravity(Vector3(0.0, -3.5, 1.0));
      vm.setDrag(0.4);
      vm.setLooping(false);
      vm.setDuration(4.0);
      vm.setBillboard(true);
      vm.addColorStop(0.0, Vector4(1, 1, 1, 1));
      vm.addColorStop(1.0, Vector4(1, 0, 0, 0));
      vm.addSizePoint(0.0, 0.0);
      vm.addSizePoint(0.2, 1.0);
      vm.addSizePoint(1.0, 0.0);
      vm.renameEmitter(0, 'Fountain');
      expect(vm.isDirty, isTrue);

      expect(await vm.save(), isTrue);
      expect(vm.isDirty, isFalse);

      // Re-read the bytes on disk through a second view model.
      final reopened = ParticleEditorViewModel(assetPath: assetPath, projectDirPath: projDir.path)..open();
      final c = reopened.config;
      expect(reopened.emitters.single.name, 'Fountain');
      expect(c.spawnRate, 50.0);
      expect(c.bursts, hasLength(1));
      expect(c.bursts.single.time, 0.5);
      expect(c.bursts.single.count, 5);
      expect(c.coneAngleDegrees, 15.0);
      expect(c.maxParticles, 512);
      expect(c.lifetimeMin, 0.25);
      expect(c.lifetimeMax, 2.5);
      expect(c.speedMin, 1.5);
      expect(c.speedMax, 6.0);
      expect(c.inheritVelocityScale.x, closeTo(0.1, 1e-9));
      expect(c.inheritVelocityScale.z, closeTo(0.3, 1e-9));
      expect(c.gravity.y, -3.5);
      expect(c.gravity.z, 1.0);
      expect(c.drag, 0.4);
      expect(c.looping, isFalse);
      expect(c.duration, 4.0);
      expect(c.billboard, isTrue);
      expect(c.meshAssetPath, isNull);
      expect(c.colorOverLife, hasLength(2));
      expect(c.colorOverLife.last.rgba.w, 0.0);
      expect(c.sizeOverLife, hasLength(3));
      expect(c.sizeOverLife[1].scale, 1.0);
      expect(reopened.isDirty, isFalse);

      // The document is a versioned JSON payload in the asset metadata.
      final raw = readAsset().metadata[ParticleSystemDocument.metadataKey];
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      expect(decoded['v'], ParticleSystemDocument.currentVersion);
      expect((decoded['emitters'] as List), hasLength(1));

      vm.dispose();
      reopened.dispose();
    });
  });

  group('validation', () {
    test('lifetimeMin > lifetimeMax reports an inline error and blocks save', () async {
      final vm = openVm();
      vm.setLifetimeMax(1.0);
      vm.setLifetimeMin(2.0);
      expect(vm.errorFor('lifetime'), isNotNull);
      expect(vm.canSave, isFalse);
      expect(await vm.save(), isFalse);

      vm.setLifetimeMax(3.0);
      expect(vm.errorFor('lifetime'), isNull);
      expect(vm.canSave, isTrue);
      expect(await vm.save(), isTrue);
      vm.dispose();
    });

    test('maxParticles 0 is rejected, the pool cap stays >= 1', () {
      final vm = openVm();
      vm.setMaxParticles(0);
      expect(vm.errorFor('maxParticles'), isNotNull);
      expect(vm.config.maxParticles, greaterThanOrEqualTo(1));
      expect(vm.canSave, isFalse);
      vm.setMaxParticles(64);
      expect(vm.errorFor('maxParticles'), isNull);
      vm.dispose();
    });

    test('a burst at or after the loop duration is flagged', () {
      final vm = openVm();
      vm.setDuration(1.0);
      vm.addBurst(2.0, 3);
      expect(vm.errorFor('bursts'), isNotNull);
      expect(vm.canSave, isFalse);
      vm.setBurstTime(0, 0.5);
      expect(vm.errorFor('bursts'), isNull);
      vm.dispose();
    });
  });

  group('gradient & curve editors sample exactly like the runtime', () {
    test('colorOverLife stops interpolate linearly and re-sort by t', () {
      final vm = openVm();
      vm.addColorStop(0.0, Vector4(1, 1, 1, 1));
      vm.addColorStop(1.0, Vector4(1, 0, 0, 0));

      final mid = vm.sampleColorAt(0.5);
      expect(mid.x, closeTo(1.0, 1e-9));
      expect(mid.y, closeTo(0.5, 1e-9));
      expect(mid.z, closeTo(0.5, 1e-9));
      expect(mid.w, closeTo(0.5, 1e-9));

      // Parity with the engine's own sampler.
      final runtime = vm.config.sampleColorAt(0.5);
      expect(runtime.y, closeTo(mid.y, 1e-9));

      // Dragging a stop re-sorts the list by t.
      vm.moveColorStop(0, 0.9);
      expect(vm.config.colorOverLife.map((s) => s.t).toList(), [0.9, 1.0]);
      expect(vm.config.colorOverLife.first.rgba.y, closeTo(1.0, 1e-9), reason: 'white stop moved, not swapped');
      // t is clamped into [0, 1].
      vm.moveColorStop(0, 5.0);
      expect(vm.config.colorOverLife.first.t, 1.0);
      vm.dispose();
    });

    test('sizeOverLife points interpolate linearly and clamp outside [0, 1]', () {
      final vm = openVm();
      vm.addSizePoint(0.0, 0.0);
      vm.addSizePoint(0.2, 1.0);
      vm.addSizePoint(1.0, 0.0);

      expect(vm.sampleSizeAt(0.1), closeTo(0.5, 1e-9));
      expect(vm.sampleSizeAt(0.6), closeTo(0.5, 1e-9));
      expect(vm.sampleSizeAt(1.5), closeTo(0.0, 1e-9));
      expect(vm.sampleSizeAt(0.6), closeTo(vm.config.sampleSizeAt(0.6), 1e-9));

      vm.removeSizePoint(1);
      expect(vm.config.sizeOverLife, hasLength(2));
      vm.dispose();
    });
  });

  group('emitter list', () {
    test('add / duplicate / disable / delete all reach the document', () async {
      final vm = openVm();
      vm.setSpawnRate(33.0);
      vm.addEmitter('Sparks');
      expect(vm.emitters, hasLength(2));
      expect(vm.selectedEmitterIndex, 1);
      expect(vm.emitters[1].name, 'Sparks');

      vm.duplicateEmitter(1);
      expect(vm.emitters, hasLength(3));
      expect(vm.emitters[2].name, 'Sparks Copy');

      vm.setEmitterEnabled(2, false);
      expect(vm.emitters[2].enabled, isFalse);
      expect(vm.enabledEmitters, hasLength(2));

      expect(await vm.save(), isTrue);
      final reopened = ParticleEditorViewModel(assetPath: assetPath, projectDirPath: projDir.path)..open();
      expect(reopened.emitters, hasLength(3), reason: 'disabled emitters stay in the file');
      expect(reopened.emitters[2].enabled, isFalse);
      expect(reopened.emitters[0].config.spawnRate, 33.0);

      reopened.deleteEmitter(2);
      expect(reopened.emitters, hasLength(2));
      // The last emitter can never be deleted — a system always has one.
      reopened.deleteEmitter(1);
      reopened.deleteEmitter(0);
      expect(reopened.emitters, hasLength(1));

      vm.dispose();
      reopened.dispose();
    });
  });

  group('mesh renderer', () {
    test('picking a FILAMESH sets meshAssetPath + an AssetReference, billboard drops it', () async {
      final meshPath = writeMeshAsset('SM_Shard');
      final vm = openVm();
      expect(vm.availableMeshes.map((a) => a.fileName), contains('SM_Shard.lmas'));

      final mesh = vm.availableMeshes.firstWhere((a) => a.fileName == 'SM_Shard.lmas');
      vm.setMeshAsset(mesh);
      expect(vm.config.billboard, isFalse);
      expect(vm.config.meshAssetPath, isNotNull);
      expect(File('${projDir.path}/${vm.config.meshAssetPath}').existsSync() || File(meshPath).existsSync(), isTrue);
      expect(await vm.save(), isTrue);

      var refs = readAsset().references;
      expect(refs.where((r) => r.slotName == '${ParticleSystemDocument.meshSlotPrefix}0'), hasLength(1));

      vm.setBillboard(true);
      expect(vm.config.meshAssetPath, isNull);
      expect(await vm.save(), isTrue);
      refs = readAsset().references;
      expect(refs.where((r) => r.slotName.startsWith(ParticleSystemDocument.meshSlotPrefix)), isEmpty);
      vm.dispose();
    });
  });

  group('preview playback drives the real LuminaParticleSystemComponent', () {
    test('play 1.0 s at spawnRate 10 with a fixed seed yields 10 live particles', () {
      final vm = openVm();
      vm.setSpawnRate(10.0);
      vm.setLifetimeMin(5.0);
      vm.setLifetimeMax(5.0);
      vm.play();
      expect(vm.isPlaying, isTrue);

      for (var i = 0; i < 10; i++) {
        vm.advance(0.1);
      }
      expect(vm.activeParticleCount, 10);
      expect(vm.simTime, closeTo(1.0, 1e-6));
      // The count really is the component's own live count.
      expect(vm.components.single.liveParticleCount, vm.activeParticleCount);

      vm.resetSimulation();
      expect(vm.activeParticleCount, 0);
      expect(vm.simTime, 0.0);
      vm.dispose();
    });

    test('Step Frame advances exactly one 1/60 s tick while paused', () {
      final vm = openVm();
      vm.setSpawnRate(60.0);
      vm.setLifetimeMin(5.0);
      vm.setLifetimeMax(5.0);
      vm.pause();
      vm.advance(1.0); // paused: nothing moves
      expect(vm.activeParticleCount, 0);
      expect(vm.simTime, 0.0);

      vm.stepFrame();
      expect(vm.isPlaying, isFalse);
      expect(vm.simTime, closeTo(1.0 / 60.0, 1e-9));
      expect(vm.activeParticleCount, 1);
      vm.dispose();
    });

    test('sim speed scales the tick and disabled emitters are not instantiated', () {
      final vm = openVm();
      vm.setSpawnRate(10.0);
      vm.setLifetimeMin(5.0);
      vm.setLifetimeMax(5.0);
      vm.addEmitter('Sparks');
      vm.setEmitterEnabled(1, false);
      vm.play();
      vm.setSimSpeed(2.0);
      for (var i = 0; i < 10; i++) {
        vm.advance(0.05);
      }
      expect(vm.simTime, closeTo(1.0, 1e-6));
      expect(vm.components, hasLength(1), reason: 'only enabled emitters get a component');
      expect(vm.activeParticleCount, 10);
      vm.dispose();
    });

    test('editing a field rebuilds the component from the fresh immutable config', () {
      final vm = openVm();
      vm.play();
      for (var i = 0; i < 30; i++) {
        vm.advance(1.0 / 60.0);
      }
      final before = vm.components.single;
      vm.setMaxParticles(64);
      expect(vm.components.single, isNot(same(before)));
      expect(vm.activeParticleCount, 0, reason: 'a config change resets the simulation');
      vm.dispose();
    });
  });

  group('widget', () {
    Future<void> pumpEditor(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1800, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: ParticleSubEditor(
          assetName: 'PS_Fountain',
          assetPath: assetPath,
          projectDirPath: projDir.path,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('the real emitter stack renders', (tester) async {
      await pumpEditor(tester);
      expect(find.text('PARTICLE VFX'), findsOneWidget);
      expect(find.text('EMITTERS'), findsOneWidget);
      expect(find.byKey(const ValueKey('particle_stage_spawn')), findsOneWidget);
      expect(find.byType(ParticleGradientEditor), findsOneWidget);
      expect(find.byType(ParticleCurveEditor), findsOneWidget);
      // Future-scope doc features must not appear as dead controls.
      expect(find.textContaining('Scratch Pad'), findsNothing);
      expect(find.textContaining('Simulate on GPU'), findsNothing);
    });

    testWidgets('editing spawnRate in the inspector marks the editor dirty', (tester) async {
      await pumpEditor(tester);
      final field = find.byKey(const ValueKey('particle_spawn_rate'));
      expect(field, findsOneWidget);
      await tester.enterText(field, '50');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const ValueKey('particle_dirty_indicator')), findsOneWidget);
      expect(find.textContaining('Spawn Rate: 50'), findsWidgets);
    });

    testWidgets('Play toggles the stats overlay and the count climbs', (tester) async {
      await pumpEditor(tester);
      expect(find.textContaining('Active Particles: 0'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('particle_play')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('particle_step')), findsOneWidget);
      for (var i = 0; i < 12; i++) {
        await tester.tap(find.byKey(const ValueKey('particle_step')));
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.textContaining('Active Particles: 0'), findsNothing);
    });
  });
}
