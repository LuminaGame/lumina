import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_mouse_capture/lumina_mouse_capture.dart';
import 'package:lumina_widgets/lumina_widgets.dart';

/// A level game with the input subsystem a generated game registers.
class _LevelGame extends LuminaGame {
  _LevelGame(this.levelName);

  final String levelName;

  @override
  LuminaObject? build(LuminaBuildContext context) {
    final world = context.world;
    if (world != null && world.getSubsystem<LuminaInputSubsystem>() == null) {
      world.registerSubsystem(LuminaInputSubsystem());
    }
    world?.gameMode ??= LuminaGameMode();
    return LuminaNodeGroup(children: [LuminaActor()]);
  }
}

Widget _app(Widget host) => Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(width: 320, height: 180, child: host),
    );

/// The game screen generated games show: keyboard and pointer input reach
/// the running world, and Change Level swaps the game.
void main() {
  late List<String> created;

  LuminaGameHost host({Set<String>? levels}) => LuminaGameHost(
        initialLevel: 'L_Main',
        levelNames: levels ?? const {'L_Main', 'L_Second'},
        createGame: (level) {
          created.add(level);
          return _LevelGame(level);
        },
      );

  setUp(() {
    created = [];
    // What a generated main() sets: every level's (here empty) asset list.
    LuminaLevelPreloader.instance.manifestResolver = (levelName) => const <LuminaAssetRef>[];
  });
  tearDown(LuminaLevelPreloader.instance.reset);

  Future<LuminaGameHostState> pumpHost(WidgetTester tester, {Set<String>? levels}) async {
    await tester.pumpWidget(_app(host(levels: levels)));
    await tester.pump();
    await tester.pump();
    return tester.state<LuminaGameHostState>(find.byType(LuminaGameHost));
  }

  testWidgets('keyboard keys reach the input subsystem through the engine key table', (tester) async {
    final state = await pumpHost(tester);
    expect(created, ['L_Main']);
    final world = state.game.world;
    expect(world, isNotNull, reason: 'the game widget mounted the game');
    final input = world!.getSubsystem<LuminaInputSubsystem>()!;

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    expect(input.isKeyDown(LuminaKey.keyW), isTrue);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    expect(input.isKeyDown(LuminaKey.keyLeftShift), isTrue);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    expect(input.isKeyDown(LuminaKey.keyW), isFalse);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('a level name the game does not have is refused; a known one swaps the game', (tester) async {
    final state = await pumpHost(tester);
    final first = state.game;
    expect(LuminaGame.onChangeLevelRequested, isNotNull, reason: 'the host answers Change Level');
    await expectLater(state.changeLevel('L_Nowhere'), throwsStateError);

    var done = false;
    state.changeLevel('L_Second').then((_) => done = true);
    for (var i = 0; i < 60 && !done; i++) {
      // The preload and the new view's set-up finish outside the fake clock.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(done, isTrue, reason: 'Change Level completes after the new level begins play');
    expect(identical(state.game, first), isFalse);
    expect(created, ['L_Main', 'L_Second']);
    expect(state.game.world?.hasBegunPlay, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(LuminaGame.onChangeLevelRequested, isNull, reason: 'a disposed host stops answering');
  });

  testWidgets('the host captures the mouse at start, turns with its motion, frees it for the cursor and takes it back', (tester) async {
    final backend = RecordingMouseCaptureBackend(simulateLock: true);
    final previous = LuminaMouseCapture.backend;
    LuminaMouseCapture.backend = backend;
    addTearDown(() => LuminaMouseCapture.backend = previous);

    final state = await pumpHost(tester);
    await tester.pump();
    expect(backend.requests.first, startsWith('capture('), reason: 'captured once the first frame laid out');
    final size = tester.getSize(find.byType(LuminaGameHost));
    expect(backend.lastCentre, Offset(size.width / 2, size.height / 2), reason: 'held at the centre of the game');
    expect(backend.isCaptured, isTrue);

    // Relative motion from the captured mouse is Mouse X / Mouse Y.
    final world = state.game.world!;
    final input = world.getSubsystem<LuminaInputSubsystem>()!;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    expect(input.lastInputDevice, 'Keyboard');
    backend.emitMotion(12, -3);
    await tester.pump();
    expect(input.lastInputDevice, 'Mouse', reason: 'the captured motion reached the input subsystem');

    // Show Mouse Cursor frees the pointer; hiding it takes it back.
    // Player 0 logs in (a game's own game mode does it at BeginPlay); the
    // host follows its controller from the next frame.
    world.gameMode!.login();
    await tester.pump();
    final controller = LuminaGameplayStatics.getPlayerController(world, playerIndex: 0);
    expect(controller, isNotNull, reason: 'the game mode gave player 0 a controller');
    {
      controller!.setShowMouseCursor(true);
      await tester.pump();
      expect(state.freeCursor, isTrue);
      expect(backend.requests.last, 'release');
      controller.setShowMouseCursor(false);
      await tester.pump();
      expect(state.freeCursor, isFalse);
      expect(backend.requests.last, startsWith('capture('));
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(backend.requests.last, 'release', reason: 'a closed game gives the mouse back');
  });
}
