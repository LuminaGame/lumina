import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_filament/flutter_filament.dart' show FilamentView;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/features/main_editor/models/editor_actor_catalog.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/outliner_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// "Spawn New Actor Into Scene" used to offer five hardcoded types
/// while the editor, the viewport and the code generator supported ten, so a
/// sky, a spot light or a skeletal mesh could not be placed at all.
///
/// This is the GPU scenario for that fix: it boots the real editor on a real
/// project in a temp directory, opens the real dialog from the real World
/// Outliner and spawns **one of every type the catalog lists**, by tapping the
/// dialog's own entries — never by calling the view model's `spawnNewActor`
/// directly. It then saves the level, reopens it in a fresh view model reading
/// the `.lmas` back off disk, and proves the frame really changed by asking
/// the live Filament scene for its renderable count and by projecting each
/// spawned actor through the native camera.
///
/// Note on evidence: the editor viewport runs temporal anti-aliasing, so every
/// frame differs from the last and a whole-viewport pixel diff proves nothing.
/// The assertions below are therefore specific — engine renderable count,
/// triangle count, and a per-actor patch diff at the actor's own projected
/// screen position.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Spawn Smoke: every catalog actor type spawns from the dialog, round-trips through the .lmas and reaches the renderer',
      (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_spawn_types_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeSpawnTypes')..createSync(recursive: true);
    Directory('${pDir.path}/contents/levels').createSync(recursive: true);

    const project = LuminaProject(
      projectName: 'SmokeSpawnTypes',
      activeLevel: 'contents/levels/L_Main.lmas',
    );
    File('${pDir.path}/SmokeSpawnTypes.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

    final levelFile = File('${pDir.path}/contents/levels/L_Main.lmas');

    try {
      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      addTearDown(vm.dispose);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());

      // The starter level carries a sky already — that is what makes the
      // Environment entry refuse a second one further down.
      expect(vm.actors.any((a) => a.type == 'Environment'), isTrue,
          reason: 'the seeded starter level must already own a sky');
      final seededIds = vm.actors.map((a) => a.id).toSet();

      tester.view.physicalSize = const Size(1600, 1000);
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

      Future<void> settle([int frames = 20]) async {
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
        }
      }

      await settle(40);

      // --- Artifact plumbing -------------------------------------------------
      // The session on video: each screenshot is followed by a second of the
      // running editor, and every dialog and spawn is held on screen.
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      Future<Uint8List> shot(String name) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot(name, png);
        await rec.hold(const Duration(milliseconds: 800));
        return png;
      }

      dynamic viewportState() => tester.state(find.byType(ViewportWidget));
      FilamentView? liveView() {
        final finder = find.byType(ViewportWidget);
        if (finder.evaluate().isEmpty) return null;
        final dynamic state = tester.state(finder);
        return state.nativeViewForTest as FilamentView?;
      }

      final view = liveView();
      final hasRenderer = view != null && view.scene != null;
      if (!hasRenderer) {
        debugPrint('[spawn_smoke] no live Filament scene in this run; engine-side assertions skipped');
      }

      final renderablesBefore = hasRenderer ? view.scene!.renderableCount : 0;
      final trianglesBefore = vm.totalTriangles;
      debugPrint('[spawn_smoke] baseline: ${vm.actors.length} actors, '
          'renderables=$renderablesBefore, triangles=$trianglesBefore');

      final beforePng = await shot('spawn_actor_types_before');

      // --- Drive the real dialog, once per catalog type ----------------------
      final addButton = find.descendant(
        of: find.byType(OutlinerWidget),
        matching: find.text('Add'),
      );
      expect(addButton, findsOneWidget, reason: 'the World Outliner must offer its Add button');

      Future<void> openDialog() async {
        await tester.tap(addButton);
        await settle(12);
        expect(find.text('Spawn New Actor Into Scene'), findsOneWidget,
            reason: 'the real spawn dialog must open from the outliner');
        await rec.hold(const Duration(milliseconds: 500));
      }

      Future<void> closeDialog() async {
        await tester.tap(find.text('Cancel').last);
        await settle(12);
        expect(find.text('Spawn New Actor Into Scene'), findsNothing);
      }

      // Places each spawned actor somewhere of its own so the round-trip and
      // the projection assertions have something to bite on.
      final placements = <String, List<double>>{};
      final rotations = <String, List<double>>{};
      final scales = <String, List<double>>{};
      final spawnedIdByType = <String, String>{};
      final refusedTypes = <String, String>{};

      final catalog = EditorActorCatalog.all;
      expect(catalog, isNotEmpty);
      debugPrint('[spawn_smoke] catalog at HEAD: ${catalog.map((t) => t.id).join(', ')}');

      for (var i = 0; i < catalog.length; i++) {
        final type = catalog[i];

        // Spawn at the root, not under whatever happens to be selected.
        vm.clearSelection();
        await settle(4);

        await openDialog();

        final entry = find.byKey(ValueKey('spawn_actor_${type.id}'));
        expect(entry, findsOneWidget, reason: '${type.id} must have an entry in the real dialog');
        await tester.ensureVisible(entry);
        await settle(4);

        final refusal = vm.spawnRefusalFor(type.id);
        if (refusal != null) {
          // The Environment case: the level already has a sky, so the entry is
          // disabled and says why instead of creating a second one.
          refusedTypes[type.id] = refusal;
          final button = tester.widget<OutlineButton>(entry);
          expect(button.onPressed, isNull,
              reason: '${type.id} must be disabled while the level already has one');
          expect(
            find.descendant(of: entry, matching: find.text(refusal)),
            findsOneWidget,
            reason: 'the refusal reason must be shown on the ${type.id} entry',
          );
          final countBefore = vm.actors.length;
          await tester.tap(entry, warnIfMissed: false);
          await settle(8);
          expect(vm.actors.length, countBefore,
              reason: 'tapping a refused entry must not spawn anything');
          await shot('spawn_actor_types_${type.id.toLowerCase()}_refused');
          await closeDialog();
          continue;
        }

        final countBefore = vm.actors.length;
        await tester.tap(entry);
        await settle(14);

        expect(find.text('Spawn New Actor Into Scene'), findsNothing,
            reason: 'spawning must close the dialog');
        expect(vm.actors.length, countBefore + 1,
            reason: 'tapping ${type.id} must add exactly one actor');

        final spawned = vm.actors.last;
        expect(spawned.type, type.id);
        expect(spawned.parentId, isNull, reason: 'nothing was selected, so it lands at the root');
        spawnedIdByType[type.id] = spawned.id;

        // Give it a transform of its own, through the real selection + details
        // path, so the save/reopen assertion is about real data.
        // Spread across the editor camera's actual framing (it sits ~400 units
        // out), so each actor lands in its own part of the frame instead of a
        // pile at the origin, and the Cube is big enough to read in the PNG.
        // Editor space is Z-up, and the editor camera frames roughly 400 units
        // at the origin: spread them across X and stack them up Z so each one
        // lands in its own part of the frame instead of piling at the origin.
        final location = <double>[
          (i - (catalog.length - 1) / 2) * 28.0,
          0.0,
          20.0 + i * 12.0,
        ];
        final rotation = <double>[0.0, i * 11.0, 0.0];
        final s = type.id == 'Primitive' ? 25.0 : 2.0 + i * 0.5;
        final scale = <double>[s, s, s];
        vm.selectActors([spawned.id]);
        await settle(2);
        vm.updateActorLocation(location);
        vm.updateActorRotation(rotation);
        vm.updateActorScale(scale);
        await settle(6);
        placements[spawned.id] = location;
        rotations[spawned.id] = rotation;
        scales[spawned.id] = scale;
        await rec.hold(const Duration(milliseconds: 700));
      }

      vm.clearSelection();
      await settle(30);

      expect(refusedTypes.keys, contains('Environment'),
          reason: 'the unique sky must be the type that refuses a second copy');
      expect(spawnedIdByType.length, catalog.length - refusedTypes.length,
          reason: 'every non-refused catalog type must have produced an actor');

      final afterPng = await shot('spawn_actor_types_all_spawned');

      // --- The engine actually got them --------------------------------------
      final trianglesAfter = vm.totalTriangles;
      debugPrint('[spawn_smoke] after spawning: ${vm.actors.length} actors, '
          'triangles $trianglesBefore -> $trianglesAfter');
      expect(trianglesAfter, greaterThan(trianglesBefore),
          reason: 'the spawned Cube builds real geometry, so the triangle count must rise');

      if (hasRenderer) {
        final renderablesAfter = view.scene!.renderableCount;
        debugPrint('[spawn_smoke] filament renderables $renderablesBefore -> $renderablesAfter');
        expect(renderablesAfter, greaterThan(renderablesBefore),
            reason: 'the spawned actors must reach the live Filament scene, not just the tree');
      }

      // Per-actor projected positions: distinct, on screen, and taken from the
      // native camera's own matrices — i.e. where Filament draws them.
      final viewportSize = tester.getSize(find.byType(ViewportWidget));
      final projected = <String, Offset>{};
      for (final entry in placements.entries) {
        final loc = entry.value;
        final p = viewportState().nativeProjectForTest(loc[0], loc[1], loc[2], viewportSize) as Offset?;
        if (p != null) projected[entry.key] = p;
      }
      if (hasRenderer) {
        expect(projected.length, placements.length,
            reason: 'every spawned actor must project through the native camera');
        final distinct = projected.values.map((o) => '${o.dx.round()}x${o.dy.round()}').toSet();
        expect(distinct.length, projected.length,
            reason: 'the actors were placed apart, so they must project apart');
        final viewportRect0 = tester.getRect(find.byType(ViewportWidget));
        for (final e in projected.entries) {
          expect(e.value.dx, inInclusiveRange(0, viewportRect0.width),
              reason: '${e.key} projects off the side of the viewport');
          expect(e.value.dy, inInclusiveRange(0, viewportRect0.height),
              reason: '${e.key} projects off the top or bottom of the viewport');
        }
        final list = projected.entries
            .map((e) => '${e.key}@(${e.value.dx.toStringAsFixed(0)},${e.value.dy.toStringAsFixed(0)})')
            .join(' ');
        debugPrint('[spawn_smoke] projections: $list');
      }

      // The Cube is the one spawned type that draws pixels of its own. Compare
      // only the patch it projects into: a whole-frame diff would be dominated
      // by temporal anti-aliasing jitter and would prove nothing.
      final cubeId = spawnedIdByType['Primitive'];
      if (hasRenderer && cubeId != null && projected.containsKey(cubeId)) {
        final viewportRect = tester.getRect(find.byType(ViewportWidget));
        final centre = viewportRect.topLeft + projected[cubeId]!;
        final a = img.decodePng(beforePng);
        final b = img.decodePng(afterPng);
        if (a != null && b != null && a.width == b.width && a.height == b.height) {
          const half = 20;
          var sumA = 0, sumB = 0, n = 0;
          for (var y = centre.dy.round() - half; y <= centre.dy.round() + half; y++) {
            for (var x = centre.dx.round() - half; x <= centre.dx.round() + half; x++) {
              if (x < 0 || y < 0 || x >= a.width || y >= a.height) continue;
              final pa = a.getPixel(x, y);
              final pb = b.getPixel(x, y);
              sumA += (pa.r + pa.g + pa.b) ~/ 3;
              sumB += (pb.r + pb.g + pb.b) ~/ 3;
              n++;
            }
          }
          if (n > 0) {
            final meanA = sumA / n, meanB = sumB / n;
            debugPrint('[spawn_smoke] cube patch mean luminance ${meanA.toStringAsFixed(1)} -> '
                '${meanB.toStringAsFixed(1)} over $n px at '
                '(${centre.dx.toStringAsFixed(0)}, ${centre.dy.toStringAsFixed(0)})');
            expect((meanB - meanA).abs(), greaterThan(2.0),
                reason: 'the spawned cube must change the pixels where it lands '
                    '(mean $meanA -> $meanB)');
          }
        }
      }

      // --- Save, then reopen from disk ---------------------------------------
      await tester.runAsync(vm.saveLevelAndGenerateCode);
      await settle(10);

      expect(levelFile.existsSync(), isTrue, reason: 'Save Level must write the .lmas');
      final onDisk = jsonDecode(levelFile.readAsStringSync()) as Map<String, dynamic>;
      final diskActors = (onDisk['metadata']['actors'] as List).cast<Map<String, dynamic>>();
      for (final type in catalog) {
        if (refusedTypes.containsKey(type.id)) continue;
        expect(diskActors.where((a) => a['id'] == spawnedIdByType[type.id]!).length, 1,
            reason: '${type.id} must be in the level file exactly once');
      }
      expect(diskActors.where((a) => a['type'] == 'Environment').length, 1,
          reason: 'the level file must still hold exactly one sky');

      final reopened = EditorViewModel(
        initialProject: project,
        projectLocation: tempProjectsDir.path,
        enableTimers: false,
      );
      addTearDown(reopened.dispose);
      await tester.runAsync(() => reopened.ensureDefaultLevelAssets());

      expect(reopened.actors.length, vm.actors.length,
          reason: 'the reopened level must hold every actor that was saved');

      for (final type in catalog) {
        if (refusedTypes.containsKey(type.id)) continue;
        final id = spawnedIdByType[type.id]!;
        final saved = vm.actors.firstWhere((a) => a.id == id);
        final loaded = reopened.actors.where((a) => a.id == id).toList();
        expect(loaded, hasLength(1), reason: '${type.id} ($id) must survive the reopen');
        final r = loaded.single;
        expect(r.type, type.id);
        expect(r.name, saved.name);
        for (var axis = 0; axis < 3; axis++) {
          expect(r.location[axis], closeTo(placements[id]![axis], 1e-6),
              reason: '${type.id} location[$axis] must round-trip');
          expect(r.rotation[axis], closeTo(rotations[id]![axis], 1e-6),
              reason: '${type.id} rotation[$axis] must round-trip');
          expect(r.scale[axis], closeTo(scales[id]![axis], 1e-6),
              reason: '${type.id} scale[$axis] must round-trip');
        }
      }

      // Names stayed unique against the seeded actors, which is the other half
      // of the bug (`spawnNewActor` used to name from `_actors.length + 1`).
      final names = reopened.actors.map((a) => a.name).toList();
      expect(names.toSet().length, names.length, reason: 'actor names must be unique: $names');
      expect(seededIds.difference(reopened.actors.map((a) => a.id).toSet()), isEmpty,
          reason: 'spawning must not have displaced the seeded actors');

      await shot('spawn_actor_types_reopened_from_disk');

      rec.save('Spawn Smoke: every catalog actor type spawns from the dialog, round-trips through the .lmas and reaches the renderer');
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  });
}
