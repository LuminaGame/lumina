import 'package:flutter/widgets.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_widgets/lumina_widgets.dart';

class _LevelGame extends LuminaGame {
  _LevelGame(this.levelName);
  final String levelName;

  @override
  LuminaObject? build(LuminaBuildContext context) => LuminaNodeGroup(children: [LuminaActor()]);
}

/// A presenter as an XR runtime module installs one: it receives the game
/// unmounted and shows its own widget.
class _Presented extends StatelessWidget {
  const _Presented(this.game, this.levelName);
  final LuminaGame game;
  final String levelName;

  @override
  Widget build(BuildContext context) => Text('presented $levelName', textDirection: TextDirection.ltr);
}

/// An immersive presenter takes the game away from the 2D game widget, and
/// Change Level hands it the next game.
void main() {
  final presented = <(LuminaGame, String)>[];
  setUp(() {
    presented.clear();
    LuminaLevelPreloader.instance.manifestResolver = (levelName) => const <LuminaAssetRef>[];
    LuminaGameHost.immersivePresenter = (game, {required levelName}) {
      presented.add((game, levelName));
      return _Presented(game, levelName);
    };
  });
  tearDown(() {
    LuminaGameHost.immersivePresenter = null;
    LuminaLevelPreloader.instance.reset();
  });

  testWidgets('the presenter shows the game instead of the 2D game widget; Change Level swaps it', (tester) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: LuminaGameHost(
        initialLevel: 'L_Room',
        levelNames: const {'L_Room', 'L_Other'},
        createGame: _LevelGame.new,
      ),
    ));
    await tester.pump();
    final state = tester.state<LuminaGameHostState>(find.byType(LuminaGameHost));
    expect(state.isImmersive, isTrue);
    expect(find.byType(FilamentWidget), findsNothing);
    expect(find.byType(LuminaGameWidget), findsNothing);
    expect(find.text('presented L_Room'), findsOneWidget);
    expect(presented.last.$1, same(state.game));
    expect(state.game.world, isNull, reason: 'the presenter mounts the game on its own engine');

    final change = state.changeLevel('L_Other');
    // The presenter mounts and plays the new game; here it is ticked by hand.
    for (var i = 0; i < 20 && identical(state.game, presented.first.$1); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    final next = state.game;
    expect(find.text('presented L_Other'), findsOneWidget);
    final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    final scene = engine.createScene();
    next.mountGame(engine, scene);
    next.world!.beginPlay();
    next.tickGame(1 / 72);
    await tester.pump();
    await change;
    next.disposeGame();
    scene.dispose();
    engine.dispose();
  });
}
