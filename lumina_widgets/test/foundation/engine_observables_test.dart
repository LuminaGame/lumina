import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_widgets/lumina_widgets.dart';

/// The engine tells its listeners about changes through `lumina_core`'s pure
/// change types; a widget listens through the Flutter views
/// (`asListenable()`, `asValueListenable()`).
void main() {
  test('the game instance, a player controller cursor and the widget subsystem notify through pure signals', () {
    final instance = LuminaGameInstance();
    expect(instance, isA<ChangeEmitter>());
    expect(instance, isNot(isA<Listenable>()), reason: 'the engine holds no Flutter notifier');
    var worldChanges = 0;
    instance.asListenable().addListener(() => worldChanges++);
    instance.setInitialWorld(LuminaWorld(worldType: LuminaWorldType.game));
    instance.replaceWorld(LuminaWorld(worldType: LuminaWorldType.game));
    expect(worldChanges, 1);

    final controller = LuminaPlayerController();
    var cursor = 0;
    final listenable = controller.cursorState.asListenable();
    expect(identical(listenable, controller.cursorState.asListenable()), isTrue, reason: 'one view per signal');
    listenable.addListener(() => cursor++);
    controller.setShowMouseCursor(true);
    controller.setShowMouseCursor(true);
    expect(cursor, 1, reason: 'only a change notifies');
    expect(controller.wantsFreeCursor, isTrue);

    final subsystem = LuminaWidgetSubsystem();
    final active = subsystem.activeWidgets.asValueListenable();
    final seen = <int>[];
    active.addListener(() => seen.add(active.value.length));
    subsystem.addWidget({'class': 'WBP_HUD', 'zOrder': 1});
    subsystem.addWidget({'class': 'WBP_Menu', 'zOrder': 0});
    expect(seen, [1, 2]);
    expect(active.value.first['class'], 'WBP_Menu', reason: 'sorted by zOrder');
  });

  testWidgets('a ValueListenableBuilder rebuilds from the GPU in use', (tester) async {
    final previous = LuminaGraphicsDevices.inUse.value;
    addTearDown(() => LuminaGraphicsDevices.inUse.value = previous);
    LuminaGraphicsDevices.inUse.value = 'GPU A';
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: ValueListenableBuilder<String?>(
        valueListenable: LuminaGraphicsDevices.inUse.asValueListenable(),
        builder: (context, gpu, _) => Text(gpu ?? 'none'),
      ),
    ));
    expect(find.text('GPU A'), findsOneWidget);
    LuminaGraphicsDevices.inUse.value = 'GPU B';
    await tester.pump();
    expect(find.text('GPU B'), findsOneWidget);
  });

  test('ensureInitialized hands the engine Flutter\'s platform, asset bundle and video player', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    LuminaWidgets.ensureInitialized();
    expect(LuminaWidgets.isInitialized, isTrue);
    expect(LuminaPlatform.current, LuminaWidgets.platformOf(defaultTargetPlatform));
    expect(LuminaAssets.bundleProvider, isNotNull);
    final playback = LuminaVideoPlayback.factory!(source: 'clip.mp4', loop: true);
    expect(playback, isA<LuminaVideoController>());
    expect((playback as LuminaVideoController).loop, isTrue);
    playback.dispose();
    for (final p in TargetPlatform.values) {
      expect(LuminaWidgets.platformOf(p).name, p.name, reason: 'the engine enum names Flutter\'s platforms the same');
    }
  });

  test('the bundle provider reads the procedural sky assets the lumina package ships', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    LuminaWidgets.ensureInitialized();
    final bytes = await LuminaAssets.bundleProvider!('packages/lumina/assets/sky/moon_disk.png');
    expect(bytes.sublist(1, 4), 'PNG'.codeUnits);
  });
}
