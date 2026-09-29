import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/views/launcher_view.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_transform.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../helpers/shared_editor_preferences.dart';

/// Units smoke: a Third Person project created through
/// the launcher is stored in centimetres, Z up. The editor viewport and
/// Play-In-Editor place its yard identically: every primitive's viewport
/// transform equals its PIE runtime transform. PNGs of both and a WebM.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('units: editor and PIE agree on the Third Person yard', (tester) async {
    const name = 'units: editor and PIE agree on the Third Person yard';
    final projects = Directory.systemTemp.createTempSync('lumina_smoke_units_');
    final config = Directory.systemTemp.createTempSync('lumina_smoke_units_cfg_');
    addTearDown(() {
      projects.deleteSync(recursive: true);
      config.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Future<void> settle([int frames = 20]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
    }

    SmokeRecorder? rec;
    // Project creation is recorded as a time-lapse: a frame a second.
    Future<bool> pumpUntil(bool Function() done, {int seconds = 420}) async {
      final deadline = DateTime.now().add(Duration(seconds: seconds));
      final sinceFrame = Stopwatch()..start();
      while (DateTime.now().isBefore(deadline)) {
        if (done()) return true;
        await settle(6);
        if (rec != null && sinceFrame.elapsedMilliseconds >= 1000) {
          await rec.captureIfChanged();
          sinceFrame.reset();
        }
      }
      return done();
    }

    useSharedEditor(config);
    // Launcher → New Project → Third Person → Create.
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(theme: luminaEditorTheme(), home: LauncherView(viewModel: LauncherViewModel(configDir: config))),
    ));
    await settle(30);
    rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    await rec.hold(const Duration(seconds: 1));
    final newProject = find.text('New Project...').evaluate().isNotEmpty ? find.text('New Project...').last : find.text('Create New Project').last;
    await tester.tap(newProject);
    await settle();
    await rec.hold(const Duration(seconds: 1));
    await rec.typeText(find.widgetWithText(TextField, 'my_lumina_game').first, 'units_yard');
    await settle(6);
    await tester.enterText(find.byType(TextField).last, projects.path);
    await settle(6);
    await rec.hold(const Duration(milliseconds: 500));
    await tester.tap(find.text('Third Person'));
    await settle(6);
    await rec.hold(const Duration(seconds: 1));
    await tester.tap(find.text('Create Project'));
    await settle(6);
    expect(await pumpUntil(() => find.byType(ViewportWidget).evaluate().isNotEmpty), isTrue, reason: 'the project did not open');
    await settle(40);
    await rec.hold(const Duration(seconds: 1));
    final vm = tester.widget<ViewportWidget>(find.byType(ViewportWidget)).viewModel;
    expect(vm.project.worldUnits, kWorldUnitsCentimetres);
    expect(vm.project.upAxis, kUpAxisZ);
    expect(find.byKey(const ValueKey('legacy_units_banner')), findsNothing);

    Future<Uint8List> shot() => SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));

    vm.frameLevelBounds();
    await settle(30);
    SmokeArtifacts.saveScreenshot('$name 01 editor', await shot());
    await rec.hold(const Duration(milliseconds: 1500));

    // Play.
    await tester.tap(find.byKey(const ValueKey('toolbar_play')));
    await settle(40);
    await rec.hold(const Duration(seconds: 1));
    final pie = vm.pieController;
    expect(pie.isPlaying, isTrue, reason: 'PIE error: ${pie.lastError}');
    final world = pie.game!.world!;

    // Every primitive the template seeds sits where the viewport draws it.
    var compared = 0;
    for (final actor in vm.actors.where((a) => a.type == 'Primitive')) {
      final runtime = world.persistentLevel.actors.firstWhere((r) => r.key == ValueKey(actor.id));
      final viewport = EditorTransforms.actorMatrix(actor);
      final placed = runtime.rootComponent.worldTransform;
      for (var i = 0; i < 16; i++) {
        expect(placed.storage[i], closeTo(viewport.storage[i], 1e-3), reason: '${actor.name} element $i');
      }
      compared++;
    }
    expect(compared, greaterThanOrEqualTo(20), reason: 'the yard seeds at least 20 primitives');
    final platform = vm.actors.firstWhere((a) => a.name == 'Platform');
    final platformRuntime = world.persistentLevel.actors.firstWhere((r) => r.key == ValueKey(platform.id));
    expect(platformRuntime.rootComponent.worldLocation.y, closeTo(platform.location[2], 1e-6), reason: 'stored Z is runtime Y');

    await settle(20);
    SmokeArtifacts.saveScreenshot(name, await shot());

    // Walk the mannequin across the yard: W held, then a turn with D.
    final pawn = pie.possessedPawn;
    expect(pawn, isNotNull, reason: 'Play possessed a pawn');
    final start = pawn!.actorLocation.clone();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    await rec.hold(const Duration(milliseconds: 1500));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
    await rec.hold(const Duration(milliseconds: 800));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    await rec.hold(const Duration(milliseconds: 500));
    expect((pawn.actorLocation - start).length, greaterThan(10), reason: 'W walked the character');

    await tester.tap(find.byKey(const ValueKey('toolbar_stop')));
    await settle(20);
    await rec.hold(const Duration(seconds: 1));
    rec.save(name);
  }, timeout: const Timeout(Duration(minutes: 12)));
}
