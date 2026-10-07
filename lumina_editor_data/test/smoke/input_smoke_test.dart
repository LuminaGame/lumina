import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina/testing.dart';

import '../helpers/nested_gnome_shell.dart';

void main() {
  group('Input Module Smoke Tests', () {
    test('Scenario 01: Enhanced Input subsystem, context priority shadowing, and key injection', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final inputSubsystem = LuminaInputSubsystem();
      world.subsystems.registerSubsystem(inputSubsystem, world);

      final gameContext = LuminaInputMappingContext();
      final menuContext = LuminaInputMappingContext();

      final jumpAction = LuminaInputAction('Jump');
      final menuSelectAction = LuminaInputAction('MenuSelect');

      gameContext.mapKey(LuminaKey.keySpace, jumpAction);
      menuContext.mapKey(LuminaKey.keySpace, menuSelectAction);

      inputSubsystem.addMappingContext(gameContext, priority: 0);
      inputSubsystem.addMappingContext(menuContext, priority: 100);

      final actor = LuminaPawn();
      final inputComponent = LuminaInputComponent(subsystem: inputSubsystem);
      actor.addComponent(inputComponent);
      world.persistentLevel.registerActor(actor);

      int jumpCount = 0;
      int menuSelectCount = 0;

      inputComponent.bindAction(jumpAction, TriggerState.triggered, (_) => jumpCount++);
      inputComponent.bindAction(menuSelectAction, TriggerState.triggered, (_) => menuSelectCount++);

      world.beginPlay();

      // Priority 100 menuContext intercepts keySpace -> jump not fired
      inputSubsystem.injectKeyDown(LuminaKey.keySpace);
      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }
      expect(jumpCount, equals(0));
      expect(menuSelectCount, equals(3)); // Key is latched across 3 frames

      // Remove menuContext -> gameContext becomes top priority
      inputSubsystem.removeMappingContext(menuContext);
      world.tick(1.0 / 60.0);

      expect(jumpCount, equals(1)); // Now jump receives the latched keySpace

      inputSubsystem.injectKeyUp(LuminaKey.keySpace);
      world.tick(1.0 / 60.0);
      expect(jumpCount, equals(1)); // KeyUp stops further triggers

      final usedAssets = [
        'Props/Access_cards/access_card_red.glb',
        'Props/Barrels/bent_barrel.glb',
      ];

      const testTitle = 'Input Module Smoke Tests Scenario 01: Enhanced Input subsystem, context priority shadowing, and key injection';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
      );

      world.cleanup();
    });

    test('Scenario 02: Input modifier chain (DeadZone + Scalar + Negate) execution', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final inputSubsystem = LuminaInputSubsystem();
      world.subsystems.registerSubsystem(inputSubsystem, world);

      final gameContext = LuminaInputMappingContext();
      final aimAction = LuminaInputAction('AimAxis');

      gameContext.mapKey(
        LuminaKey.gamepadLeftStickX,
        aimAction,
        modifiers: [
          LuminaDeadZoneModifier(lowerThreshold: 0.2, upperThreshold: 1.0),
          LuminaScalarModifier.uniform(2.0),
          LuminaNegateModifier(),
        ],
      );

      inputSubsystem.addMappingContext(gameContext, priority: 0);

      final actor = LuminaPawn();
      final inputComponent = LuminaInputComponent(subsystem: inputSubsystem);
      actor.addComponent(inputComponent);
      world.persistentLevel.registerActor(actor);

      double receivedAim = 0.0;
      inputComponent.bindAction(aimAction, TriggerState.triggered, (val) {
        receivedAim = val.asAxis1D;
      });

      world.beginPlay();

      // 0.6 -> DeadZone gives 0.5 -> Scalar(2.0) gives 1.0 -> Negate gives -1.0
      inputSubsystem.injectAnalog(LuminaKey.gamepadLeftStickX, 0.6);
      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      expect(receivedAim, closeTo(-1.0, 1e-9));

      final usedAssets = [
        'Props/AC_units/ac_unit_a_300x300.glb',
        'Props/Barrels/dented_barrel.glb',
      ];

      const testTitle = 'Input Module Smoke Tests Scenario 02: Input modifier chain (DeadZone + Scalar + Negate) execution';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
      );

      world.cleanup();
    });

    test('Scenario 03: Input trigger state machine and full event transition sequence', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final inputSubsystem = LuminaInputSubsystem();
      world.subsystems.registerSubsystem(inputSubsystem, world);

      final gameContext = LuminaInputMappingContext();
      final chargeAction = LuminaInputAction('ChargeAttack');

      gameContext.mapKey(
        LuminaKey.keySpace,
        chargeAction,
        triggers: [LuminaHoldTrigger(holdTimeThreshold: 0.1, isOneShot: true)],
      );

      inputSubsystem.addMappingContext(gameContext, priority: 0);

      final actor = LuminaPawn();
      final inputComponent = LuminaInputComponent(subsystem: inputSubsystem);
      actor.addComponent(inputComponent);
      world.persistentLevel.registerActor(actor);

      final recordedEvents = <TriggerState>[];
      for (final s in TriggerState.values) {
        inputComponent.bindAction(chargeAction, s, (_) => recordedEvents.add(s));
      }

      world.beginPlay();

      // Press and hold for 0.15s (3 ticks of 0.05s)
      inputSubsystem.injectKeyDown(LuminaKey.keySpace);
      world.tick(0.05); // tick 1: started (ongoing)
      world.tick(0.05); // tick 2: ongoing (threshold 0.1 reached -> triggered)
      world.tick(0.05); // tick 3: one-shot holds -> none

      // Release key
      inputSubsystem.injectKeyUp(LuminaKey.keySpace);
      world.tick(0.05);

      expect(recordedEvents.contains(TriggerState.started), isTrue);
      expect(recordedEvents.contains(TriggerState.triggered), isTrue);

      final usedAssets = [
        'Props/Barrels/fuel_barrel_black.glb',
        'Props/Barrels/fuel_barrel_red.glb',
      ];

      const testTitle = 'Input Module Smoke Tests Scenario 03: Input trigger state machine and full event transition sequence';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
      );

      world.cleanup();
    });


    test('Scenario 04: Mouse capture — pointer lock and relative motion in a nested headless GNOME Shell', () async {
      // The lumina_mouse_capture plugin, built into its example app
      // by Flutter's own Linux build, runs inside a nested, isolated,
      // headless GNOME Shell (bwrap, GPU hidden, private D-Bus and HOME);
      // input comes from Mutter's RemoteDesktop API on that bus. The desktop
      // and pointer of the person at this machine are never touched.
      const testTitle =
          'Input Module Smoke Tests Scenario 04: Mouse capture — pointer lock and relative motion in a nested headless GNOME Shell';
      final unavailable = await NestedGnomeShell.unavailableReason();
      if (unavailable != null) {
        markTestSkipped('nested GNOME Shell unavailable: $unavailable');
        return;
      }

      // The plugin lives in the tools repo; its example is built where the
      // workspace resolved it (the local ../tools checkout).
      final example = Directory('${NestedGnomeShell.packageDir}/example').absolute.path;
      final build = await Process.run('flutter', ['build', 'linux', '--debug'], workingDirectory: example);
      expect(build.exitCode, 0, reason: 'the example app (and the plugin\'s native code) must build:\n${build.stdout}\n${build.stderr}');
      final binary = '$example/build/linux/x64/debug/bundle/lumina_mouse_capture_example';
      expect(File(binary).existsSync(), isTrue);

      final work = Directory.systemTemp.createTempSync('input_smoke_capture_');
      final shell = await NestedGnomeShell.start();
      Process? app;
      Process? decoy;
      final shots = <String, List<int>>{};
      Future<void> shot(String phase) async => shots[phase] = await shell.screenshot('${work.path}/$phase.png');
      Future<void> pause(int ms) => Future<void>.delayed(Duration(milliseconds: ms));
      double sum(List<Map<String, dynamic>> events, String key) =>
          events.fold(0.0, (a, e) => a + (e[key] as num).toDouble());
      try {
        app = await Process.start(binary, const [], environment: shell.clientEnvironment, includeParentEnvironment: false);
        app.stderr.drain<void>();
        final log = JsonEventLog(app);
        final support = await log.waitFor('support', timeout: const Duration(seconds: 90));
        expect(support['kind'], 'wayland', reason: 'the plugin must find the Wayland lock protocols: $support');
        expect(support['lock'], isTrue);
        expect(support['relative'], isTrue);
        expect(support['reason'], 'platform channel', reason: 'the real plugin, not the recording backend');

        await shell.connectInput();
        await shell.startRecording('${work.path}/frames');
        await shell.key(Keysym.escape); // GNOME opens the overview at start-up.
        await pause(1200);
        for (var i = 0; i < 80 && log.since(0, 'pointer').isEmpty; i++) {
          await shell.move(15, 10);
          await pause(40);
        }
        expect(log.since(0, 'pointer'), isNotEmpty, reason: 'the pointer must reach the app window');
        await pause(800);
        await shot('released_at_start');

        // --- C captures: the compositor locks the pointer ------------------
        var mark = log.mark;
        await shell.key(Keysym.c);
        final capture = await log.waitFor('capture', since: mark, where: (e) => e['ok'] == true);
        await log.waitFor('locked', since: mark);
        await pause(700);

        mark = log.mark;
        for (var i = 0; i < 20; i++) {
          await shell.move(10, 0);
          await pause(25);
        }
        await shell.move(0, -5);
        await pause(500);
        expect(sum(log.since(mark, 'motion'), 'dx'), closeTo(200, 1), reason: 'relative moves arrive as deltas');
        expect(sum(log.since(mark, 'motion'), 'dy'), closeTo(-5, 1));
        expect(log.since(mark, 'pointer'), isEmpty, reason: 'a locked pointer does not move');
        await shot('locked');

        // Far past every edge of the 1280×800 screen, slowly enough to watch.
        mark = log.mark;
        for (var i = 0; i < 150; i++) {
          await shell.move(20, -6);
          await pause(25);
        }
        await pause(500);
        expect(sum(log.since(mark, 'motion'), 'dx'), closeTo(3000, 2),
            reason: '3000 px to the right, past the screen edge, still turns the view');
        expect(sum(log.since(mark, 'motion'), 'dy'), closeTo(-900, 2));
        expect(log.since(mark, 'pointer'), isEmpty);
        await shot('turned_past_the_edges');

        // --- F4 releases: the pointer is back at the capture centre ---------
        mark = log.mark;
        await shell.key(Keysym.f4);
        await log.waitFor('release', since: mark);
        await pause(300);
        for (var i = 0; i < 5; i++) {
          await shell.move(4, 0);
          await pause(50);
        }
        await pause(500);
        final after = log.since(mark, 'pointer');
        expect(after, isNotEmpty, reason: 'released, the pointer moves again');
        expect(log.since(mark, 'motion'), isEmpty, reason: 'released, no deltas');
        final first = after.first;
        final cx = (capture['cx'] as num).toDouble();
        final cy = (capture['cy'] as num).toDouble();
        expect(((first['x'] as num) - cx).abs(), lessThan(30), reason: 'the pointer reappears at the capture centre: $first vs ($cx, $cy)');
        expect(((first['y'] as num) - cy).abs(), lessThan(30));
        await pause(600);
        await shot('released_at_the_centre');

        // --- A click captures again ----------------------------------------
        mark = log.mark;
        await shell.click();
        await log.waitFor('locked', since: mark);
        for (var i = 0; i < 40; i++) {
          await shell.move(-15, 3);
          await pause(25);
        }
        await pause(400);
        expect(sum(log.since(mark, 'motion'), 'dx'), closeTo(-600, 2));
        await shot('recaptured');

        // --- Another window takes the focus: the capture is lost ------------
        mark = log.mark;
        decoy = await Process.start(binary, const [],
            environment: {...shell.clientEnvironment, 'LMC_DECOY': '1'}, includeParentEnvironment: false);
        await log.waitFor('lost', since: mark, timeout: const Duration(seconds: 60));
        await pause(1500);
        await shot('lost_to_another_window');

        final frames = await shell.stopRecording();
        expect(frames, isNotEmpty);

        // The video: the recorded screen on a 30 fps timeline.
        img.Image decode(String path) {
          final image = img.decodePng(File(path).readAsBytesSync())!;
          return image.numChannels == 4 ? image : image.convert(numChannels: 4);
        }

        final firstFrame = decode(frames.first.path);
        final recorder = SmokeVideoRecorder(width: firstFrame.width, height: firstFrame.height, fps: 30, testName: testTitle);
        final start = frames.first.t;
        final length = frames.last.t - start;
        var index = 0;
        var decodedIndex = -1;
        Uint8List? rgba;
        for (var k = 0; k * (1 / 30) <= length; k++) {
          final t = start + k / 30;
          while (index + 1 < frames.length && frames[index + 1].t <= t) {
            index++;
          }
          if (index != decodedIndex) {
            final frame = decode(frames[index].path);
            rgba = frame.getBytes(order: img.ChannelOrder.rgba);
            decodedIndex = index;
          }
          recorder.addFrame(rgba!);
        }
        final video = recorder.finish();
        SmokeArtifacts.saveVideo(testTitle, video);
        SmokeArtifacts.saveScreenshot(testTitle, Uint8List.fromList(shots['turned_past_the_edges']!));
        for (final phase in ['released_at_start', 'locked', 'released_at_the_centre', 'recaptured', 'lost_to_another_window']) {
          SmokeArtifacts.saveScreenshot('$testTitle — $phase', Uint8List.fromList(shots[phase]!));
        }
        // ignore: avoid_print
        print('[input_smoke] ${frames.length} screen frames over ${length.toStringAsFixed(1)} s '
            '(${(frames.length / length).toStringAsFixed(1)} captured fps), video ${recorder.seconds.toStringAsFixed(1)} s');
      } finally {
        decoy?.kill();
        app?.kill();
        await app?.exitCode.timeout(const Duration(seconds: 10), onTimeout: () => -1);
        await shell.stop();
        if (work.existsSync()) work.deleteSync(recursive: true);
      }
    }, timeout: const Timeout(Duration(minutes: 20)));

    test('Scenario 05: the built Third Person game captures the mouse — relative motion turns its camera past the screen edge in a nested headless GNOME Shell', () async {
      // A real Third Person project (flutter create + the template),
      // built for Linux with its generated launcher, runs inside a
      // nested, isolated GNOME Shell. The launcher captures the pointer on
      // start; motion injected through Mutter's RemoteDesktop must keep
      // turning the game camera long after an uncaptured pointer would have
      // stopped at the 1280 px screen edge.
      const testTitle =
          'Input Module Smoke Tests Scenario 05: the built Third Person game captures the mouse in a nested headless GNOME Shell';
      final unavailable = await NestedGnomeShell.unavailableReason();
      if (unavailable != null) {
        markTestSkipped('nested GNOME Shell unavailable: $unavailable');
        return;
      }

      final root = Directory.systemTemp.createTempSync('input_smoke_game_');
      final config = Directory('${root.path}/config')..createSync();
      NestedGnomeShell? shell;
      Process? game;
      final shots = <String, List<int>>{};
      Future<void> pause(int ms) => Future<void>.delayed(Duration(milliseconds: ms));
      try {
        await ProjectRepository(configDir: config)
            .createProject(projectName: 'capture_game', projectLocation: root.path, template: kThirdPersonTemplateId);
        final projectDir = '${root.path}/capture_game';
        expect(File('$projectDir/lib/main.dart').readAsStringSync(), contains('LuminaMouseCapture.backend.capture'),
            reason: 'the generated launcher captures');
        final build = await Process.run('flutter', ['build', 'linux', '--debug'], workingDirectory: projectDir);
        expect(build.exitCode, 0, reason: 'the generated game must build for Linux:\n${build.stdout}\n${build.stderr}');
        final binary = '$projectDir/build/linux/x64/debug/bundle/capture_game';
        expect(File(binary).existsSync(), isTrue);

        shell = await NestedGnomeShell.start();
        final work = Directory('${root.path}/shots')..createSync();
        Future<img.Image> shot(String phase) async {
          final bytes = await shell!.screenshot('${work.path}/$phase.png');
          shots[phase] = bytes;
          return img.decodePng(Uint8List.fromList(bytes))!;
        }

        // The share of the game view (below the shell's top bar and the
        // window title) whose grey level moved by more than 20: the level's
        // floor and sky are flat, so a turning camera shows as the character,
        // its shadow and the walls sweeping across pixels, not as a change in
        // the mean.
        double diff(img.Image a, img.Image b) {
          var changed = 0;
          var n = 0;
          for (var y = 96; y < a.height - 8; y += 6) {
            for (var x = 8; x < a.width - 8; x += 6) {
              final pa = a.getPixel(x, y);
              final pb = b.getPixel(x, y);
              if (((pa.r + pa.g + pa.b) - (pb.r + pb.g + pb.b)).abs() / 3.0 > 20) changed++;
              n++;
            }
          }
          return changed / n;
        }

        // The game renders with Filament on the GPU the harness selected
        // (FILAMENT_GPU & co. from this process); its window is drawn by the
        // nested shell in software.
        game = await Process.start(binary, const [], workingDirectory: '$projectDir/build/linux/x64/debug/bundle',
            environment: shell.clientEnvironment, includeParentEnvironment: false);
        final gameLog = <String>[];
        game.stdout.transform(utf8.decoder).listen((t) => gameLog.add(t));
        game.stderr.transform(utf8.decoder).listen((t) => gameLog.add(t));
        await shell.connectInput();
        await shell.key(Keysym.escape); // GNOME opens the overview at start-up.
        // Wait for the level to be on screen: two shots a second apart that
        // are no longer blank and barely differ.
        img.Image? last;
        var ready = false;
        for (var i = 0; i < 90 && !ready; i++) {
          await pause(1000);
          final now = await shot('boot');
          if (last != null) {
            final d = diff(last, now);
            final lit = now.getPixel(now.width ~/ 2, now.height ~/ 2);
            ready = d < 0.01 && (lit.r + lit.g + lit.b) > 60;
          }
          last = now;
        }
        expect(ready, isTrue, reason: 'the game must draw its level in the nested shell');
        // The nested pointer starts at the screen's top-left corner, over the
        // shell's top bar: bring it to the centre, over the game (the Wayland
        // lock needs the pointer on the window; the launcher retries its
        // start-up capture when the pointer arrives).
        for (var i = 0; i < 64; i++) {
          await shell.move(10, 6.25);
          await pause(20);
        }
        await pause(1500);

        await shell.startRecording('${work.path}/frames');
        final a = await shot('at_start');
        await pause(1000);
        final b = await shot('still');
        final idle = diff(a, b);

        // 1500 px to the right: an uncaptured pointer hits the screen edge
        // within ~640 px.
        for (var i = 0; i < 75; i++) {
          await shell.move(20, 0);
          await pause(25);
        }
        await pause(800);
        final c = await shot('turned_1500px');
        // …and 1500 px more: only a captured pointer still turns the view.
        for (var i = 0; i < 75; i++) {
          await shell.move(20, 0);
          await pause(25);
        }
        await pause(800);
        final d = await shot('turned_past_the_edge');
        // The character's idle animation alone moves a sliver of the view.
        final threshold = math.max(0.012, idle * 2.5);
        // ignore: avoid_print
        print('[input_smoke] game view change (share of pixels): idle ${idle.toStringAsFixed(4)}, '
            'first 1500 px ${diff(b, c).toStringAsFixed(4)}, next 1500 px ${diff(c, d).toStringAsFixed(4)} (threshold ${threshold.toStringAsFixed(4)})');
        // The stills go into the report before the checks, so a failure shows
        // what the nested screen looked like.
        for (final phase in ['at_start', 'still', 'turned_1500px', 'turned_past_the_edge']) {
          SmokeArtifacts.saveScreenshot('$testTitle — $phase', Uint8List.fromList(shots[phase]!));
        }
        final logTail = gameLog.join().split('\n').where((l) => l.trim().isNotEmpty).toList();
        // ignore: avoid_print
        print('[input_smoke] game log (last 30 lines):\n${logTail.skip(logTail.length > 30 ? logTail.length - 30 : 0).join('\n')}');
        expect(diff(b, c), greaterThan(threshold), reason: 'relative motion turns the game camera');
        expect(diff(c, d), greaterThan(threshold), reason: 'the camera keeps turning past the screen edge: the pointer is captured');
        // A last look at the turned view: the recording runs well over 10 s.
        await pause(3000);

        final frames = await shell.stopRecording();
        expect(frames, isNotEmpty);
        img.Image decode(String path) {
          final image = img.decodePng(File(path).readAsBytesSync())!;
          return image.numChannels == 4 ? image : image.convert(numChannels: 4);
        }

        final firstFrame = decode(frames.first.path);
        final recorder = SmokeVideoRecorder(width: firstFrame.width, height: firstFrame.height, fps: 30, testName: testTitle);
        final start = frames.first.t;
        final length = frames.last.t - start;
        var index = 0;
        var decodedIndex = -1;
        Uint8List? rgba;
        for (var k = 0; k * (1 / 30) <= length; k++) {
          final t = start + k / 30;
          while (index + 1 < frames.length && frames[index + 1].t <= t) {
            index++;
          }
          if (index != decodedIndex) {
            rgba = decode(frames[index].path).getBytes(order: img.ChannelOrder.rgba);
            decodedIndex = index;
          }
          recorder.addFrame(rgba!);
        }
        final video = recorder.finish();
        SmokeArtifacts.saveVideo(testTitle, video);
        SmokeArtifacts.saveScreenshot(testTitle, Uint8List.fromList(shots['turned_past_the_edge']!));
        // ignore: avoid_print
        print('[input_smoke] game: ${frames.length} screen frames over ${length.toStringAsFixed(1)} s, video ${recorder.seconds.toStringAsFixed(1)} s');
      } finally {
        game?.kill();
        await game?.exitCode.timeout(const Duration(seconds: 10), onTimeout: () => -1);
        await shell?.stop();
        if (root.existsSync()) root.deleteSync(recursive: true);
      }
    }, timeout: const Timeout(Duration(minutes: 45)));
  });
}
