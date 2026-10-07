import 'dart:convert';
import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/models/editor_actor_catalog.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_level_post_process.dart';
import 'package:lumina_ui/ui/features/main_editor/services/environment_actor_properties.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_controller.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/outliner_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/environment_lighting_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/environment_lighting_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

/// 05 — the placeable environment actors: the
/// Exponential Height Fog, the Post Process Volume and the Local Fog Volume.
/// Every scenario runs against a real temp project and, where it renders, a
/// real Filament engine, scene and view.
void main() {
  late Directory tempDir;
  setUp(() => tempDir = Directory.systemTemp.createTempSync('lumina_env_actors_'));
  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  EditorViewModel vm() => EditorViewModel(
        initialProject: const LuminaProject(projectName: 'EnvActors'),
        projectLocation: tempDir.path,
        enableTimers: false,
        autoInitAssets: false,
      );

  Future<void> pumpDetails(WidgetTester tester, EditorViewModel model) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: DetailsWidget(viewModel: model))));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// A real engine, scene and view, and the service attached to them.
  ({EditorLevelPostProcess service, FilamentEngine engine, FilamentScene scene}) attachService(String owner) {
    final lease = FilamentEngineHost.acquire(owner: owner)!;
    addTearDown(lease.release);
    final scene = lease.engine.createScene();
    addTearDown(scene.dispose);
    final view = lease.engine.createView();
    addTearDown(view.dispose);
    view.scene = scene;
    final service = EditorLevelPostProcess()..attach(lease.engine, scene, view);
    addTearDown(service.detach);
    return (service: service, engine: lease.engine, scene: scene);
  }

  /// The level file the editor saved, as the `metadata.actors` it stores.
  List<EditorActorNode> savedActors(EditorViewModel model) {
    final lmas = File('${model.projectDirPath}/contents/levels/L_DefaultLevel.lmas');
    expect(lmas.existsSync(), isTrue);
    final json = jsonDecode(lmas.readAsStringSync()) as Map<String, dynamic>;
    return [
      for (final a in ((json['metadata'] as Map)['actors'] as List))
        EditorActorNode.fromMap(Map<String, dynamic>.from(a as Map)),
    ];
  }

  // -------------------------------------------------------------------------
  // Exponential Height Fog
  // -------------------------------------------------------------------------
  group('Exponential Height Fog (03)', () {
    testWidgets('Place Actors lists Visual Effects → Exponential Height Fog; one per level', (tester) async {
      final model = vm();
      addTearDown(model.dispose);
      tester.view.physicalSize = const Size(700, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: OutlinerWidget(viewModel: model))));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('VISUAL EFFECTS'), findsOneWidget);
      final entry = find.byKey(const ValueKey('spawn_actor_ExponentialHeightFog'));
      expect(entry, findsOneWidget);
      expect(find.descendant(of: entry, matching: find.text('Exponential Height Fog')), findsOneWidget);
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();

      final fog = model.actors.singleWhere((a) => a.type == 'ExponentialHeightFog');
      final component = fog.components.singleWhere((c) => c.type == 'LuminaExponentialHeightFogComponent');
      expect(component.properties, LuminaHeightFogSettings.defaults.toProperties());
      expect(EditorActorCatalog.byId('ExponentialHeightFog')!.icon, LucideIcons.cloudFog);
      expect(EditorActorCatalog.byId('ExponentialHeightFog')!.color, EditorColors.chart2);

      // A second one is refused, in the dialog and in the view model.
      expect(model.spawnRefusalFor('ExponentialHeightFog'), contains('already has'));
      model.spawnNewActor('ExponentialHeightFog');
      expect(model.actors.where((a) => a.type == 'ExponentialHeightFog'), hasLength(1));
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      final refusedButton = tester.widget<OutlineButton>(find.byKey(const ValueKey('spawn_actor_ExponentialHeightFog')));
      expect(refusedButton.onPressed, isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the Details panel shows the fog rows with /m and cm units', (tester) async {
      final model = vm();
      addTearDown(model.dispose);
      model.spawnNewActor('ExponentialHeightFog');
      model.selectActorById(model.actors.single.id);
      await pumpDetails(tester, model);
      for (final label in [
        'Exponential Height Fog',
        'Enabled',
        'Fog Density',
        'Fog Height Falloff',
        'Start Distance',
        'Fog Cutoff Distance',
        'Fog Max Opacity',
        'Fog Inscattering Color',
        'Use Sky Color',
      ]) {
        expect(find.text(label, skipOffstage: false), findsWidgets, reason: '$label is in the Details panel');
      }
      expect(find.textContaining('/m', skipOffstage: false), findsWidgets);
      expect(find.textContaining('cm', skipOffstage: false), findsWidgets);
      expect(find.textContaining('fog height', skipOffstage: false), findsWidgets, reason: 'the note says Z is the fog height');
      await tester.pumpWidget(const SizedBox());
    });

    test('EditorLevelPostProcess applies the fog actor live: height = Z, density per cm, undo, move, delete', () {
      final model = vm();
      addTearDown(model.dispose);
      final (:service, engine: _, scene: _) = attachService('env_actors_fog');

      // The environment section's fallback fog, used whenever no actor exists.
      model.setLevelEnvironment({
        'postProcess': {'fogEnabled': true, 'fogDensity': 0.03, 'fogHeightFalloff': 2.0, 'fogColorHex': '#FF0000'},
      });
      model.spawnNewActor('ExponentialHeightFog');
      final fog = model.actors.single;
      model.selectActorById(fog.id);
      model.updateActorLocation([100.0, 200.0, 250.0]);
      final component = EnvironmentActorProperties.componentOf(fog)!;

      void sync() => service.sync(
            model.actors,
            quality: LuminaPostProcessSettings.standard(),
            environmentSection: model.levelEnvironment,
            cameraAuthoring: const [0.0, -800.0, 300.0],
            isVisible: model.isEffectivelyVisible,
          );

      sync();
      expect(service.appliedForTest!.fog.enabled, isTrue);
      expect(service.appliedForTest!.fog.height, closeTo(250.0, 1e-9), reason: 'height = authored Z, no factor');
      expect(service.appliedForTest!.fog.density, closeTo(0.0002, 1e-12), reason: '0.02 /m = 0.0002 /cm');
      expect(service.realisedForTest[fog.id]!.rootComponent, isA<LuminaExponentialHeightFogComponent>());

      model.updateComponentPropertyWithTransaction(fog.id, component.id, 'fogDensity', 0.05);
      sync();
      expect(service.appliedForTest!.fog.density, closeTo(0.0005, 1e-12));
      model.transactions.undo();
      sync();
      expect(service.appliedForTest!.fog.density, closeTo(0.0002, 1e-12));

      model.updateActorLocation([100.0, 200.0, 400.0]);
      sync();
      expect(service.appliedForTest!.fog.height, closeTo(400.0, 1e-9), reason: 'the fog plane follows the gizmo');

      // Quality baseline survives: the actor never resets the preset's bloom.
      final quality = LuminaPostProcessSettings.standard().copyWith(bloom: const BloomOptions(enabled: true, strength: 0.42));
      service.sync(model.actors, quality: quality, environmentSection: model.levelEnvironment, isVisible: model.isEffectivelyVisible);
      expect(service.appliedForTest!.bloom.strength, closeTo(0.42, 1e-9));
      expect(service.appliedForTest!.fog.height, closeTo(400.0, 1e-9));

      model.deleteActorSubtreeWithTransaction(fog.id);
      sync();
      expect(service.realisedForTest, isEmpty);
      final fallback = service.appliedForTest!.fog;
      expect(fallback.enabled, isTrue, reason: 'the environment section\'s fog is the fallback');
      expect(fallback.density, closeTo(0.0003, 1e-12));
      expect(fallback.colorR, closeTo(1.0, 1e-6));
      expect(fallback.colorG, closeTo(0.0, 1e-6));

      model.setLevelEnvironment(const {});
      sync();
      expect(service.appliedForTest!.fog.enabled, isFalse, reason: 'no actor and no section: no fog');
    });

    test('save → reload the .lmas round-trips every fog property; codegen emits the component', () async {
      final model = vm();
      addTearDown(model.dispose);
      model.spawnNewActor('ExponentialHeightFog');
      final fog = model.actors.single;
      model.selectActorById(fog.id); // the Details panel edits the selection
      final component = EnvironmentActorProperties.componentOf(fog)!;
      final authored = <String, dynamic>{
        'enabled': false,
        'fogDensity': 0.07,
        'fogHeightFalloff': 1.25,
        'startDistance': 1500.0,
        'fogCutoffDistance': 90000.0,
        'fogMaxOpacity': 0.6,
        'inscatteringColorHex': '#336699',
        'useSkyColor': true,
      };
      authored.forEach((k, v) => model.updateComponentPropertyWithTransaction(fog.id, component.id, k, v));
      await model.saveLevelAndGenerateCode();

      final reloaded = savedActors(model).singleWhere((a) => a.type == 'ExponentialHeightFog');
      final props = EnvironmentActorProperties.propertiesOf(reloaded);
      authored.forEach((k, v) => expect(props[k], v, reason: '$k round-trips'));

      final dart = File('${model.projectDirPath}/lib/levels/l_default_level.dart').readAsStringSync();
      expect(dart, contains('LuminaExponentialHeightFogComponent('));
    });

    test('Play builds a LuminaExponentialHeightFogComponent with the authored values at (x, z, −y)', () {
      final actor = EditorActorNode(
        id: 'fog',
        name: 'ExponentialHeightFog',
        type: 'ExponentialHeightFog',
        location: [100.0, 200.0, 250.0],
        components: [EnvironmentActorProperties.seedHeightFog('fog')],
      );
      EnvironmentActorProperties.componentOf(actor)!.properties
        ..['fogDensity'] = 0.08
        ..['fogMaxOpacity'] = 0.5
        ..['inscatteringColorHex'] = '#FF8000';
      final built = EditorPieGame.mapEditorActor(actor) as LuminaActor;
      final root = built.rootComponent as LuminaExponentialHeightFogComponent;
      expect(root.fogDensity, 0.08);
      expect(root.fogMaxOpacity, 0.5);
      expect(root.inscatteringColor.x, closeTo(1.0, 1e-6));
      expect(root.relativeLocation.x, closeTo(100.0, 1e-9));
      expect(root.relativeLocation.y, closeTo(250.0, 1e-9));
      expect(root.relativeLocation.z, closeTo(-200.0, 1e-9));
      expect(root.settings.height, closeTo(250.0, 1e-9));
    });

    testWidgets('the Environment editor marks its Height Fog section a fallback only while a fog actor exists', (tester) async {
      final model = vm();
      addTearDown(model.dispose);
      final env = EnvironmentLightingViewModel(editor: model)..open();
      addTearDown(env.dispose);
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SizedBox(
            width: 1400,
            height: 900,
            child: EnvironmentLightingSubEditor(assetName: 'Environment', editorViewModel: model, viewModel: env),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Height Fog'));
      await tester.pump(const Duration(milliseconds: 400));
      const note = 'Fallback only — the level\'s Exponential Height Fog actor overrides this section.';
      expect(find.text(note), findsNothing);

      model.spawnNewActor('ExponentialHeightFog');
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text(note), findsOneWidget);

      // Hiding it in the Outliner puts the section back in charge.
      final fog = model.actors.singleWhere((a) => a.type == 'ExponentialHeightFog');
      model.setActorVisibilityWithTransaction(fog.id, false);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text(note), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  // -------------------------------------------------------------------------
  // Post Process Volume
  // -------------------------------------------------------------------------
  group('Post Process Volume (04)', () {
    EditorActorNode volume(
      String id, {
      List<double> location = const [0.0, 0.0, 0.0],
      List<double> scale = const [1.0, 1.0, 1.0],
      Map<String, dynamic> properties = const {},
    }) {
      final seed = EnvironmentActorProperties.seedPostProcessVolume(id);
      seed.properties.addAll(properties);
      return EditorActorNode(
        id: id,
        name: id,
        type: 'PostProcessVolume',
        location: List<double>.from(location),
        scale: List<double>.from(scale),
        components: [seed],
      );
    }

    testWidgets('spawning seeds the component; the Details panel shows the Volume and Post Process Settings blocks', (tester) async {
      final model = vm();
      addTearDown(model.dispose);
      model.spawnNewActor('PostProcessVolume');
      final placed = model.actors.single;
      expect(EditorActorCatalog.byId('PostProcessVolume')!.category, 'Visual Effects');
      expect(EditorActorCatalog.byId('PostProcessVolume')!.icon, LucideIcons.squareDashed);
      expect(EditorActorCatalog.byId('PostProcessVolume')!.unique, isFalse);
      final props = EnvironmentActorProperties.propertiesOf(placed);
      expect(props, EnvironmentActorProperties.postProcessVolumeDefaults());
      expect(props['extentX'], 400.0);
      expect(props['blendRadius'], 100.0);
      expect(props['blendWeight'], 1.0);
      expect(props['priority'], 0.0);
      for (final k in LuminaPostProcessOverrides.keys) {
        expect(props[LuminaPostProcessOverrides.overrideKey(k)], isFalse, reason: 'every override starts off');
      }

      model.selectActorById(placed.id);
      await pumpDetails(tester, model);
      for (final label in [
        'Volume',
        'Extent X',
        'Extent Y',
        'Extent Z',
        'Infinite Extent (Unbound)',
        'Priority',
        'Blend Radius',
        'Blend Weight',
        'Post Process Settings',
        'Override: Bloom Intensity',
        'Bloom Intensity',
        'Depth of Field',
        'Focus Distance',
        'Temperature',
        'TAA',
      ]) {
        expect(find.text(label, skipOffstage: false), findsWidgets, reason: '$label is in the Details panel');
      }
      expect(find.textContaining('Filament applies one post-process state to the whole view', skipOffstage: false), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    test('EditorLevelPostProcess blends a bloom volume by the editor camera: inside, far outside, halfway through the blend radius', () {
      final (:service, engine: _, scene: _) = attachService('env_actors_ppv_blend');
      final quality = LuminaPostProcessSettings.standard();
      final baseline = quality.bloom.enabled ? quality.bloom.strength : 0.0;
      final actors = [
        volume('ppv', properties: {
          'extentX': 300.0,
          'extentY': 300.0,
          'extentZ': 300.0,
          'overrideBloomIntensity': true,
          'bloomIntensity': 6.0,
        }),
      ];
      double bloomAt(List<double> camera) {
        service.sync(actors, quality: quality, cameraAuthoring: camera);
        final bloom = service.appliedForTest!.bloom;
        return bloom.enabled ? bloom.strength : 0.0;
      }

      expect(bloomAt(const [0.0, 0.0, 100.0]), closeTo(0.75, 1e-9), reason: 'inside: 6 of 8');
      expect(bloomAt(const [0.0, 0.0, 2000.0]), closeTo(baseline, 1e-9), reason: 'outside: the baseline');
      expect(bloomAt(const [0.0, 0.0, 350.0]), closeTo((baseline + 0.75) / 2, 1e-9),
          reason: '50 cm outside the top face with a 100 cm blend radius: halfway');
      expect(bloomAt(const [350.0, 0.0, 0.0]), closeTo((baseline + 0.75) / 2, 1e-9), reason: 'the same on the X face');
      expect(bloomAt(const [0.0, 0.0, 2000.0]), closeTo(baseline, 1e-9), reason: 'leaving restores the baseline');
    });

    test('two overlapping volumes: the higher priority wins', () {
      final (:service, engine: _, scene: _) = attachService('env_actors_ppv_priority');
      final actors = [
        volume('low', properties: {'priority': 0.0, 'overrideSaturation': true, 'saturation': 0.0}),
        volume('high', properties: {'priority': 10.0, 'overrideSaturation': true, 'saturation': 2.0}),
      ];
      service.sync(actors, quality: LuminaPostProcessSettings.standard(), cameraAuthoring: const [0.0, 0.0, 50.0]);
      expect(service.appliedForTest!.colorGrade.saturation, closeTo(2.0, 1e-9));
      // Swapping the priorities swaps the winner.
      final swapped = [
        volume('low', properties: {'priority': 10.0, 'overrideSaturation': true, 'saturation': 0.0}),
        volume('high', properties: {'priority': 0.0, 'overrideSaturation': true, 'saturation': 2.0}),
      ];
      service.sync(swapped, quality: LuminaPostProcessSettings.standard(), cameraAuthoring: const [0.0, 0.0, 50.0]);
      expect(service.appliedForTest!.colorGrade.saturation, closeTo(0.0, 1e-9));
    });

    test('an unbound volume applies at any camera position; a disabled one applies nowhere', () {
      final (:service, engine: _, scene: _) = attachService('env_actors_ppv_unbound');
      final quality = LuminaPostProcessSettings.standard();
      service.sync([
        volume('everywhere', properties: {'unbound': true, 'overrideSaturation': true, 'saturation': 1.7}),
      ], quality: quality, cameraAuthoring: const [90000.0, -90000.0, 5000.0]);
      expect(service.appliedForTest!.colorGrade.saturation, closeTo(1.7, 1e-9));
      service.sync([
        volume('off', properties: {'enabled': false, 'overrideSaturation': true, 'saturation': 1.7}),
      ], quality: quality, cameraAuthoring: const [0.0, 0.0, 0.0]);
      expect(service.appliedForTest!.colorGrade.saturation, closeTo(quality.colorGrade.saturation, 1e-9));
      // Hidden in the Outliner is off too.
      service.sync([
        volume('hidden', properties: {'unbound': true, 'overrideSaturation': true, 'saturation': 1.7}),
      ], quality: quality, cameraAuthoring: const [0.0, 0.0, 0.0], isVisible: (_) => false);
      expect(service.appliedForTest!.colorGrade.saturation, closeTo(quality.colorGrade.saturation, 1e-9));
    });

    testWidgets('the viewport draws the box: bright selected, dim otherwise, sized by extent × scale, none when unbound', (tester) async {
      final model = vm();
      model.spawnNewActor('PostProcessVolume');
      final placed = model.actors.single;
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: ViewportWidget(viewModel: model)));
      dynamic viewport() => tester.state(find.byType(ViewportWidget));
      for (var i = 0; i < 60 && viewport().nativeSceneForTest == null; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      }
      await tester.pump(const Duration(milliseconds: 16));
      Map<String, ({double alpha, Vector3 halfExtent})> wires() =>
          viewport().volumeWireStateForTest as Map<String, ({double alpha, Vector3 halfExtent})>;

      expect((viewport().volumeWiresForTest as Map).keys, [placed.id]);
      expect(wires()[placed.id]!.alpha, 0.35, reason: 'unselected volumes stay visible, dim');
      model.selectActorById(placed.id);
      await tester.pump(const Duration(milliseconds: 16));
      expect(wires()[placed.id]!.alpha, 1.0);
      expect(wires()[placed.id]!.halfExtent.x, closeTo(400.0, 1e-9));

      model.updateActorScale([2.0, 2.0, 2.0]);
      await tester.pump(const Duration(milliseconds: 16));
      expect(wires()[placed.id]!.halfExtent.x, closeTo(800.0, 1e-9), reason: 'the box follows the actor scale');

      model.selectActorById(null);
      await tester.pump(const Duration(milliseconds: 16));
      expect(wires()[placed.id]!.alpha, 0.35);

      final component = EnvironmentActorProperties.componentOf(placed)!;
      model.selectActorById(placed.id);
      model.updateComponentPropertyWithTransaction(placed.id, component.id, 'unbound', true);
      await tester.pump(const Duration(milliseconds: 16));
      expect(wires(), isEmpty, reason: 'an unbound volume draws no box');
      expect((viewport().volumeWiresForTest as Map), isEmpty);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      model.dispose();
    });

    test('Play builds a LuminaPostProcessVolumeComponent: runtime half-extent (x, z, y), priority, blend and overrides', () {
      final actor = volume('ppv', location: const [100.0, 200.0, 300.0], properties: {
        'extentX': 100.0,
        'extentY': 200.0,
        'extentZ': 300.0,
        'priority': 5.0,
        'blendRadius': 250.0,
        'blendWeight': 0.5,
        'overrideSaturation': true,
        'saturation': 1.5,
        'overrideDofFocusDistance': true,
        'dofFocusDistance': 750.0,
      });
      final built = EditorPieGame.mapEditorActor(actor) as LuminaActor;
      final root = built.rootComponent as LuminaPostProcessVolumeComponent;
      expect(root.extent, Vector3(100.0, 300.0, 200.0));
      expect(root.priority, 5.0);
      expect(root.blendRadius, 250.0);
      expect(root.blendWeight, 0.5);
      expect(root.overrides.saturation, 1.5);
      expect(root.overrides.dofFocusDistance, 750.0);
      expect(root.overrides.bloomIntensity, isNull, reason: 'not overridden');
      expect(root.relativeLocation, Vector3(100.0, 300.0, -200.0));
    });

    test('save → reload the .lmas round-trips the volume including its override flags', () async {
      final model = vm();
      addTearDown(model.dispose);
      model.spawnNewActor('PostProcessVolume');
      final placed = model.actors.single;
      model.selectActorById(placed.id);
      final component = EnvironmentActorProperties.componentOf(placed)!;
      final authored = <String, dynamic>{
        'extentX': 650.0,
        'unbound': true,
        'priority': 3.0,
        'blendRadius': 40.0,
        'overrideBloomIntensity': true,
        'bloomIntensity': 5.5,
        'overrideTemperature': true,
        'temperature': -0.4,
        'overrideTaaEnabled': true,
        'taaEnabled': true,
      };
      authored.forEach((k, v) => model.updateComponentPropertyWithTransaction(placed.id, component.id, k, v));
      await model.saveLevelAndGenerateCode();
      final props = EnvironmentActorProperties.propertiesOf(savedActors(model).singleWhere((a) => a.type == 'PostProcessVolume'));
      authored.forEach((k, v) => expect(props[k], v, reason: '$k round-trips'));
      expect(props['overrideSaturation'], isFalse);
      final dart = File('${model.projectDirPath}/lib/levels/l_default_level.dart').readAsStringSync();
      expect(dart, contains('LuminaPostProcessVolumeComponent.fromProperties('));
    });
  });

  // -------------------------------------------------------------------------
  // Local Fog Volume
  // -------------------------------------------------------------------------
  group('Local Fog Volume (05)', () {
    EditorActorNode fogVolume(
      String id, {
      List<double> location = const [0.0, 0.0, 0.0],
      Map<String, dynamic> properties = const {},
    }) {
      final seed = EnvironmentActorProperties.seedLocalFogVolume(id);
      seed.properties.addAll(properties);
      return EditorActorNode(id: id, name: id, type: 'LocalFogVolume', location: List<double>.from(location), components: [seed]);
    }

    /// The Environment editor's fog section as the baseline fog: 0.02 /m.
    const environment = {
      'postProcess': {'fogEnabled': true, 'fogDensity': 0.02, 'fogHeightFalloff': 1.0, 'fogColorHex': '#B8C4D6'},
    };

    testWidgets('spawning seeds the component; the Details panel states the approximation and shows the rows', (tester) async {
      final model = vm();
      addTearDown(model.dispose);
      final entry = EditorActorCatalog.byId('LocalFogVolume')!;
      expect(entry.category, 'Visual Effects');
      expect(entry.icon, LucideIcons.cloud);
      expect(entry.unique, isFalse);
      expect(entry.description, contains('Approximation: no volumetric scattering.'));
      model.spawnNewActor('LocalFogVolume');
      final placed = model.actors.single;
      expect(EnvironmentActorProperties.propertiesOf(placed), EnvironmentActorProperties.localFogVolumeDefaults());

      model.selectActorById(placed.id);
      await pumpDetails(tester, model);
      for (final label in ['Local Fog Volume', 'Shape', 'Radius', 'Extent X', 'Fog Albedo', 'Fog Density', 'Height Falloff', 'Radial Attenuation', 'Enabled']) {
        expect(find.text(label, skipOffstage: false), findsWidgets, reason: '$label is in the Details panel');
      }
      expect(find.textContaining('no volumetric scattering', skipOffstage: false), findsOneWidget);
      expect(find.textContaining('volumetric scattering', skipOffstage: false).evaluate().map((e) => (e.widget as Text).data ?? ''),
          everyElement(isNot(contains('supports volumetric'))),
          reason: 'nothing claims volumetric scattering');
      await tester.pumpWidget(const SizedBox());
    });

    test('EditorLevelPostProcess realises the shell in the viewport scene: a loaded, shadowless mesh', () async {
      final (:service, engine: _, :scene) = attachService('env_actors_localfog_shell');
      service.sync([fogVolume('lfv')], quality: LuminaPostProcessSettings.standard(), environmentSection: environment, cameraAuthoring: const [0.0, -3000.0, 500.0]);
      final realised = service.realisedForTest['lfv']!;
      final fog = realised.rootComponent as LuminaLocalFogVolumeComponent;
      expect(service.world!.persistentLevel.actors, contains(realised));
      final shell = fog.shell!;
      expect(shell.castShadows, isFalse);
      await shell.loaded.timeout(const Duration(seconds: 20));
      expect(shell.isLoaded, isTrue);
      expect(shell.entities, isNotEmpty);
      expect(shell.entities.where(scene.hasEntity), isNotEmpty, reason: 'the shell is drawn in the viewport scene');
    });

    test('camera inside the sphere scales the baseline fog by 1 + 10·density and tints it; far outside it is the baseline', () {
      final (:service, engine: _, scene: _) = attachService('env_actors_localfog_scale');
      final actors = [fogVolume('lfv', properties: {'fogAlbedoHex': '#FF8040'})];
      service.sync(actors, quality: LuminaPostProcessSettings.standard(), environmentSection: environment, cameraAuthoring: const [0.0, 0.0, 0.0]);
      final baseline = service.baseline.fog;
      expect(baseline.density, closeTo(0.0002, 1e-12));
      final inside = service.appliedForTest!.fog;
      expect(inside.density, closeTo(0.0002 * (1 + 10 * 0.35), 1e-12));
      expect(inside.colorR, closeTo(1.0, 1e-6));
      expect(inside.colorG, closeTo(0x80 / 255.0, 1e-6));
      expect(inside.colorB, closeTo(0x40 / 255.0, 1e-6));

      service.sync(actors, quality: LuminaPostProcessSettings.standard(), environmentSection: environment, cameraAuthoring: const [0.0, -5000.0, 0.0]);
      final outside = service.appliedForTest!.fog;
      expect(outside.density, closeTo(0.0002, 1e-12));
      expect(outside.colorR, closeTo(baseline.colorR, 1e-6));
    });

    test('a density edit rebuilds the shell under a new key and raises the scale; undo restores both', () {
      final model = vm();
      addTearDown(model.dispose);
      final (:service, engine: _, scene: _) = attachService('env_actors_localfog_edit');
      model.setLevelEnvironment(environment);
      model.spawnNewActor('LocalFogVolume');
      final placed = model.actors.single;
      model.selectActorById(placed.id);
      model.updateActorLocation([0.0, 0.0, 0.0]);
      final component = EnvironmentActorProperties.componentOf(placed)!;
      void sync() => service.sync(model.actors,
          quality: LuminaPostProcessSettings.standard(),
          environmentSection: model.levelEnvironment,
          cameraAuthoring: const [0.0, 0.0, 100.0],
          isVisible: model.isEffectivelyVisible);
      LuminaLocalFogVolumeComponent realised() => service.realisedForTest[placed.id]!.rootComponent as LuminaLocalFogVolumeComponent;

      sync();
      final firstKey = realised().shell!.meshAssetPath;
      expect(service.appliedForTest!.fog.density, closeTo(0.0002 * 4.5, 1e-12));

      model.updateComponentPropertyWithTransaction(placed.id, component.id, 'fogDensity', 0.8);
      sync();
      expect(realised().shell!.meshAssetPath, isNot(firstKey));
      expect(service.appliedForTest!.fog.density, closeTo(0.0002 * 9.0, 1e-12));

      model.transactions.undo();
      sync();
      expect(realised().shell!.meshAssetPath, firstKey);
      expect(service.appliedForTest!.fog.density, closeTo(0.0002 * 4.5, 1e-12));
      expect(service.world!.persistentLevel.actors.where((a) => a.rootComponent is LuminaLocalFogVolumeComponent), hasLength(1),
          reason: 'the old realisation left the world');
    });

    testWidgets('the viewport draws the volume outline only while it is selected', (tester) async {
      final model = vm();
      model.spawnNewActor('LocalFogVolume');
      final placed = model.actors.single;
      model.selectActorById(null);
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: ViewportWidget(viewModel: model)));
      dynamic viewport() => tester.state(find.byType(ViewportWidget));
      for (var i = 0; i < 60 && viewport().nativeSceneForTest == null; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      }
      await tester.pump(const Duration(milliseconds: 16));
      expect((viewport().volumeWiresForTest as Map).keys, isEmpty, reason: 'unselected: the shell shows, no outline');
      model.selectActorById(placed.id);
      await tester.pump(const Duration(milliseconds: 16));
      expect((viewport().volumeWiresForTest as Map).keys, [placed.id]);
      final state = (viewport().volumeWireStateForTest as Map<String, ({double alpha, Vector3 halfExtent})>)[placed.id]!;
      expect(state.halfExtent, Vector3.all(500.0), reason: 'a sphere of radius 500');
      model.selectActorById(null);
      await tester.pump(const Duration(milliseconds: 16));
      expect((viewport().volumeWiresForTest as Map).keys, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      model.dispose();
    });

    test('Play builds a LuminaLocalFogVolumeComponent with the authored shape, sizes, albedo, falloffs and transform', () {
      final actor = fogVolume('lfv', location: const [100.0, 200.0, 300.0], properties: {
        'shape': 'box',
        'radius': 650.0,
        'extentX': 100.0,
        'extentY': 200.0,
        'extentZ': 300.0,
        'fogAlbedoHex': '#FF8000',
        'fogDensity': 0.6,
        'heightFalloff': 1.5,
        'radialAttenuation': 0.2,
      });
      final root = (EditorPieGame.mapEditorActor(actor) as LuminaActor).rootComponent as LuminaLocalFogVolumeComponent;
      expect(root.shape, LuminaLocalFogShape.box);
      expect(root.radius, 650.0);
      expect(root.extent, Vector3(100.0, 300.0, 200.0));
      expect(root.fogAlbedo.x, closeTo(1.0, 1e-6));
      expect(root.fogAlbedo.y, closeTo(0x80 / 255.0, 1e-6));
      expect(root.fogDensity, 0.6);
      expect(root.heightFalloff, 1.5);
      expect(root.radialAttenuation, 0.2);
      expect(root.relativeLocation, Vector3(100.0, 300.0, -200.0));
    });

    test('save → reload the .lmas round-trips every Local Fog Volume property; codegen emits it', () async {
      final model = vm();
      addTearDown(model.dispose);
      model.spawnNewActor('LocalFogVolume');
      final placed = model.actors.single;
      model.selectActorById(placed.id);
      final component = EnvironmentActorProperties.componentOf(placed)!;
      final authored = <String, dynamic>{
        'shape': 'box',
        'radius': 900.0,
        'extentX': 300.0,
        'extentY': 350.0,
        'extentZ': 120.0,
        'fogAlbedoHex': '#224466',
        'fogDensity': 0.55,
        'heightFalloff': 2.5,
        'radialAttenuation': 0.1,
        'enabled': false,
      };
      authored.forEach((k, v) => model.updateComponentPropertyWithTransaction(placed.id, component.id, k, v));
      await model.saveLevelAndGenerateCode();
      final props = EnvironmentActorProperties.propertiesOf(savedActors(model).singleWhere((a) => a.type == 'LocalFogVolume'));
      authored.forEach((k, v) => expect(props[k], v, reason: '$k round-trips'));
      final dart = File('${model.projectDirPath}/lib/levels/l_default_level.dart').readAsStringSync();
      expect(dart, contains('LuminaLocalFogVolumeComponent.fromProperties('));
    });
  });
}
