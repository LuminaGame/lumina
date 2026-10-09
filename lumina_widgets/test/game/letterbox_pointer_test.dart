import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_widgets/lumina_widgets.dart';

/// A game whose world has the input subsystem a generated game registers,
/// and an actor Blueprints run on.
class _UiGame extends LuminaGame {
  final LuminaCharacter actor = LuminaCharacter();

  @override
  LuminaObject? build(LuminaBuildContext context) {
    final world = context.world;
    if (world != null && world.getSubsystem<LuminaInputSubsystem>() == null) {
      world.registerSubsystem(LuminaInputSubsystem());
    }
    world?.gameMode ??= LuminaGameMode();
    return LuminaNodeGroup(children: [actor]);
  }
}

const _corner = LuminaBlueprintWidgetClass(name: 'WBP_Corner', elements: [
  LuminaBlueprintWidgetElement(name: 'Corner', fieldName: 'corner', typeName: 'button', props: {'label': 'Corner'}),
]);

/// In borderless fullscreen with a chosen resolution smaller than the
/// monitor, the picture is letterboxed: the game's UI is laid out in the
/// picture at the chosen resolution, the mouse position is in render pixels
/// and clicks on the black bars reach nothing.
void main() {
  var pressed = 0;

  setUp(() {
    pressed = 0;
    LuminaWidgetBuilderRegistry.clear();
    // A button 200x60 (UI pixels at the chosen resolution) in the bottom
    // right corner of the screen.
    LuminaWidgetBuilderRegistry.register(
      'WBP_Corner',
      _corner,
      (context, instance) => Align(
        alignment: Alignment.bottomRight,
        child: SizedBox(
          width: 200,
          height: 60,
          child: LuminaUmgButton(key: const ValueKey('corner'), onPressed: () => pressed++, child: const Text('Corner')),
        ),
      ),
    );
    LuminaLevelPreloader.instance.manifestResolver = (levelName) => const <LuminaAssetRef>[];
  });

  tearDown(() {
    LuminaWidgetBuilderRegistry.clear();
    LuminaGameDisplay.resetForTesting();
    LuminaLevelPreloader.instance.reset();
  });

  for (final dpr in [1.0, 2.0]) {
    testWidgets('letterboxed 1920x1080 on a 3440x1440 monitor at DPR $dpr: UI, mouse position and clicks in render space',
        (tester) async {
      tester.view.physicalSize = const Size(3440, 1440);
      tester.view.devicePixelRatio = dpr;
      addTearDown(tester.view.reset);
      LuminaGameDisplay.renderResolution.value = (1920, 1080);

      late _UiGame game;
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: LuminaGameHost(
          initialLevel: 'L_Main',
          captureMouse: false,
          createGame: (_) => game = _UiGame(),
        ),
      ));
      await tester.pump();
      await tester.pump();
      final world = game.world!;
      final input = world.getSubsystem<LuminaInputSubsystem>()!;
      final hud = LuminaBlueprintFunctionLibrary.createWidget(game.actor, 'WBP_Corner');
      LuminaBlueprintFunctionLibrary.addToViewport(game.actor, hud, 0);
      await tester.pump();
      await tester.pump();

      // The picture: 1440 / dpr high, 2560 / dpr wide, centred.
      final left = 440 / dpr;
      final scale = (1440 / dpr) / 1080; // window logical px per render px
      Offset screen(double x, double y) => Offset(left + x * scale, y * scale);

      // The button sits in the picture's bottom right corner, at the chosen
      // resolution's scale, not on the black bar.
      final button = tester.getRect(find.byKey(const ValueKey('corner')));
      expect(button.right, closeTo(screen(1920, 0).dx, 0.5));
      expect(button.bottom, closeTo(1440 / dpr, 0.5));
      // 200 UI px are 200 * dpr render px.
      expect(button.width, closeTo(200 * dpr * scale, 0.5));

      // A click where the game draws the button presses it, and the UI takes
      // the click: the game sees no mouse button.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: screen(960, 540));
      await mouse.moveTo(screen(1900, 1060));
      await tester.pump();
      expect(input.mousePosition.x, closeTo(1900, 0.01));
      expect(input.mousePosition.y, closeTo(1060, 0.01));
      await mouse.down(screen(1900, 1060));
      expect(input.isKeyDown(LuminaKey.mouseLeft), isFalse);
      await mouse.up();
      await tester.pump();
      expect(pressed, 1);

      // A click in the picture outside the UI reaches the game at its render
      // pixel (a trace under the cursor deprojects from there).
      await mouse.moveTo(screen(12, 34));
      await tester.pump();
      expect(input.mousePosition.x, closeTo(12, 0.01));
      expect(input.mousePosition.y, closeTo(34, 0.01));
      await mouse.down(screen(12, 34));
      expect(input.isKeyDown(LuminaKey.mouseLeft), isTrue);
      await mouse.up();
      expect(input.isKeyDown(LuminaKey.mouseLeft), isFalse);

      // On the black bar: the position clamps to the picture's edge and a
      // click reaches nothing.
      await mouse.moveTo(Offset(left / 2, 720 / dpr));
      await tester.pump();
      expect(input.mousePosition.x, closeTo(0, 0.01));
      expect(input.mousePosition.y, closeTo(540, 0.01));
      await mouse.down(Offset(left / 2, 720 / dpr));
      expect(input.isKeyDown(LuminaKey.mouseLeft), isFalse);
      await mouse.up();
      await tester.pump();
      expect(pressed, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets('windowed (no chosen resolution): the mouse position is the window position in view pixels',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    late _UiGame game;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: LuminaGameHost(initialLevel: 'L_Main', captureMouse: false, createGame: (_) => game = _UiGame()),
    ));
    await tester.pump();
    await tester.pump();
    final input = game.world!.getSubsystem<LuminaInputSubsystem>()!;

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(10, 10));
    await mouse.moveTo(const Offset(100, 50));
    await tester.pump();
    // The game view renders physical pixels: 2x the logical position.
    expect(input.mousePosition.x, closeTo(200, 0.01));
    expect(input.mousePosition.y, closeTo(100, 0.01));
    await mouse.down(const Offset(100, 50));
    expect(input.isKeyDown(LuminaKey.mouseLeft), isTrue);
    await mouse.up();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
