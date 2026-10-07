import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/particle_system_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/particle_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/particle/curve_editors.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/particle/particle_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector4;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Particle editor smoke: boot the real editor on a real
/// temp project, create a PARTICLE `.lmas` through the real asset repository,
/// open it through the shell's own tab path, edit `spawnRate` in the real
/// inspector field, add over-life gradient stops and size curve points, press
/// Play and pump ~1 s of real Filament frames while the **real**
/// `LuminaParticleSystemComponent` simulates inside the sub-editor's lumina
/// preview world, capture PNG + WebM evidence, then Save and assert the
/// `.lmas` on disk carries every edited field.
///
/// A real prop from `test-assets/` goes through the real import pipeline so
/// the Render stage's mesh picker has an actual FILAMESH to select.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const usedAssets = [
    'Props/Barrels/fuel_barrel_red.glb',
  ];

  testWidgets('Particle Smoke: emitter stack edits + live CPU emitter preview round-trip through the .lmas',
      (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_particle_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeVfx')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SmokeVfx', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokeVfx.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

    try {
      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());

      // Real prop through the real import pipeline — the mesh renderer picker
      // must offer an actual asset.
      final propSrc = File('${SmokeArtifacts.testAssetsDir.path}/${usedAssets[0]}');
      expect(propSrc.existsSync(), isTrue, reason: 'seed asset ${usedAssets[0]} must exist');
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: propSrc.path));

      // The PARTICLE asset the editor opens — created exactly the way the
      // Content Browser's New Asset → Particle System does it.
      await tester.runAsync(() => AssetRepository().createAsset(
            projectPath: pDir.path,
            subFolder: 'effects',
            fileName: 'PS_Fountain.lmas',
            type: AssetType.particle,
          ));
      vm.refreshAssets();
      final particleAsset = vm.realAssets.firstWhere((a) => a.fileName == 'PS_Fountain.lmas');
      final particlePath = particleAsset.lmasPath ?? '${pDir.path}/contents/effects/PS_Fountain.lmas';

      tester.view.physicalSize = const Size(1920, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: ShadcnApp(
            theme: luminaEditorTheme(),
            home: MainEditorView(viewModel: vm),
          ),
        ),
      );

      // Live binding: animations run on the real clock, so a bare pump loop
      // advances nothing. Each frame waits for real time to pass.
      Future<void> settle([int frames = 20]) async {
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
        }
      }

      await settle(30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));

      // --- open through the real shell tab path ---------------------------
      vm.openSubEditorTab('PARTICLE', asset: particleAsset);
      await settle(25);
      await rec.hold(const Duration(milliseconds: 1500));
      expect(find.byType(ParticleSubEditor), findsOneWidget);
      expect(find.text('EMITTERS'), findsOneWidget);
      expect(find.byType(ParticleGradientEditor), findsOneWidget);
      expect(find.byType(ParticleCurveEditor), findsOneWidget);

      final pvm = (tester.state(find.byType(ParticleSubEditor)) as dynamic).viewModelForTest
          as ParticleEditorViewModel;
      expect(pvm.isLoaded, isTrue);
      expect(pvm.emitters, hasLength(1));
      expect(pvm.config.spawnRate, 10.0, reason: 'a fresh PARTICLE asset carries the engine defaults');
      expect(pvm.config.maxParticles, 256);
      expect(pvm.activeParticleCount, 0);

      /// The right panel's fields sit in a scroll view; an `Accordion` section
      /// in the left stack can render collapsed, which clips its content to
      /// zero height so the controls are found but cannot be tapped.
      Future<void> openStage(String title) async {
        final trigger = find.descendant(of: find.byType(AccordionTrigger), matching: find.text(title));
        if (trigger.evaluate().isEmpty) return;
        await tester.tap(trigger.first, warnIfMissed: false);
        await settle(12);
      }

      // --- edit spawnRate through the real inspector field ----------------
      final spawnField = find.byKey(const ValueKey('particle_spawn_rate'));
      expect(spawnField, findsOneWidget);
      await tester.tap(spawnField);
      await settle(4);
      await tester.enterText(spawnField, '50');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(10);
      expect(pvm.config.spawnRate, 50.0);
      expect(find.byKey(const ValueKey('particle_dirty_indicator')), findsOneWidget);
      await rec.hold(const Duration(seconds: 1));

      // Longer-lived, faster particles make a readable frame.
      pvm.setLifetimeMin(1.5);
      pvm.setLifetimeMax(2.5);
      pvm.setSpeedMin(1.2);
      pvm.setSpeedMax(2.4);
      pvm.setConeAngleDegrees(28.0);
      pvm.addBurst(0.5, 12);
      // Over-life gradient + size curve, sampled by the runtime itself.
      pvm.addColorStop(0.0, Vector4(1.0, 0.85, 0.25, 1.0));
      pvm.addColorStop(1.0, Vector4(0.9, 0.15, 0.05, 0.0));
      pvm.addSizePoint(0.0, 0.2);
      pvm.addSizePoint(0.25, 1.0);
      pvm.addSizePoint(1.0, 0.0);
      await settle(8);
      await rec.hold(const Duration(milliseconds: 1500));
      expect(pvm.sampleColorAt(0.5).y, closeTo(0.5, 0.01));
      expect(pvm.sampleSizeAt(0.125), closeTo(0.6, 1e-6));

      // --- Play: the real component simulates in the preview world --------
      await tester.tap(find.byKey(const ValueKey('particle_play')));
      await settle(6);
      expect(pvm.isPlaying, isTrue);

      // Three seconds of the simulation running, on video.
      await rec.hold(const Duration(seconds: 3));

      final liveWhilePlaying = pvm.activeParticleCount;
      final previewLive = pvm.isPreviewAttached;
      if (previewLive) {
        // The preview scene's ticker drives advance() on the real clock.
        expect(liveWhilePlaying, greaterThan(0),
            reason: 'the real LuminaParticleSystemComponent spawned particles');
        expect(pvm.simTime, greaterThan(0.0));
        expect(pvm.preview.liveSpriteCount, greaterThan(0), reason: 'sprites follow real particle positions');
      } else {
        // skip-degrade (manny_load_test pattern): no GPU renderer in this run,
        // so drive the same real component by hand instead.
        debugPrint('[particle_editor_smoke] preview world not attached; stepping the component directly');
        for (var i = 0; i < 60; i++) {
          pvm.stepFrame();
        }
      }
      // The preview runs on a real 60 Hz timer, so the live count moves between
      // frames: pause before comparing the model against the painted HUD.
      pvm.pause();
      await settle(6);
      expect(pvm.activeParticleCount, greaterThan(0));
      expect(pvm.activeParticleCount, pvm.components.fold<int>(0, (n, c) => n + c.liveParticleCount));
      expect(find.textContaining('Active Particles: ${pvm.activeParticleCount}'), findsOneWidget);
      // The engine component draws its own particles.
      expect(pvm.components.fold<int>(0, (n, c) => n + c.renderedParticleCount), pvm.activeParticleCount,
          reason: 'every live particle reached the scene as real geometry');

      final playingPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('particle_editor_live_preview', playingPng, usedAssets: usedAssets);
      await rec.hold(const Duration(seconds: 1));

      // --- Pause, then Reset Sim uses the component's own reset -----------
      // Resume first: the HUD comparison above paused the transport.
      if (!pvm.isPlaying) {
        pvm.play();
        await settle(4);
      }
      await tester.tap(find.byKey(const ValueKey('particle_play')));
      await settle(4);
      expect(pvm.isPlaying, isFalse, reason: 'the transport toggled to paused');

      await tester.tap(find.byKey(const ValueKey('particle_reset_sim')));
      await settle(4);
      expect(pvm.simTime, 0.0);
      expect(pvm.activeParticleCount, 0, reason: 'Reset Sim calls the component\'s own resetSimulation');
      await rec.hold(const Duration(seconds: 1));

      // --- Step Frame advances exactly one 1/60 s tick while paused -------
      await tester.tap(find.byKey(const ValueKey('particle_step')));
      await settle(4);
      expect(pvm.isPlaying, isFalse);
      expect(pvm.simTime, closeTo(1.0 / 60.0, 1e-6));
      await rec.hold(const Duration(seconds: 1));

      // --- Render stage: pick the real imported mesh ----------------------
      await openStage('RENDER');
      final meshAsset = pvm.availableMeshes.firstWhere(
        (a) => a.fileName.toLowerCase().contains('barrel'),
        orElse: () => pvm.availableMeshes.first,
      );
      pvm.setMeshAsset(meshAsset);
      await settle(6);
      await rec.hold(const Duration(milliseconds: 1500));
      expect(pvm.config.billboard, isFalse);
      expect(pvm.config.meshAssetPath, meshAsset.relativePath);
      // Back to the built-in quad for the saved document.
      pvm.setBillboard(true);
      await settle(4);
      expect(pvm.config.meshAssetPath, isNull);

      // --- Save and re-read the bytes on disk -----------------------------
      expect(pvm.canSave, isTrue);
      final saved = await tester.runAsync(() => pvm.save());
      expect(saved, isTrue);
      await settle(6);

      final onDisk = LuminaAsset.fromBytes(File(particlePath).readAsBytesSync());
      expect(onDisk.type, AssetType.particle);
      final raw = onDisk.metadata[ParticleSystemDocument.metadataKey];
      expect(raw, isNotNull);
      final doc = ParticleSystemDocument.fromJson(jsonDecode(raw!) as Map<String, dynamic>);
      expect(doc.version, ParticleSystemDocument.currentVersion);
      expect(doc.emitters, hasLength(1));
      final savedConfig = doc.emitters.single.config;
      expect(savedConfig.spawnRate, 50.0);
      expect(savedConfig.lifetimeMin, 1.5);
      expect(savedConfig.lifetimeMax, 2.5);
      expect(savedConfig.coneAngleDegrees, 28.0);
      expect(savedConfig.bursts, hasLength(1));
      expect(savedConfig.bursts.single.count, 12);
      expect(savedConfig.colorOverLife, hasLength(2));
      expect(savedConfig.sizeOverLife, hasLength(3));
      expect(savedConfig.billboard, isTrue);
      expect(savedConfig.meshAssetPath, isNull);
      expect(onDisk.references.where((r) => r.slotName.startsWith(ParticleSystemDocument.meshSlotPrefix)), isEmpty);

      final savedPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('particle_editor_saved_document', savedPng, usedAssets: usedAssets);
      await rec.hold(const Duration(milliseconds: 1500));
      rec.save('Particle Smoke: emitter stack edits + live CPU emitter preview round-trip through the .lmas', usedAssets: usedAssets);
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  });
}
