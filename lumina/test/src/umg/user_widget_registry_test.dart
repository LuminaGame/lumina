import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

class _Panel extends LuminaUserWidget {
  int ticks = 0;
  final List<String> calls = [];

  @override
  void onWidgetConstruct() => calls.add('construct');

  @override
  void onWidgetDestruct() => calls.add('destruct');

  @override
  void onWidgetTick(double inDeltaTime) => ticks++;
}

void main() {
  tearDown(() {
    LuminaUserWidgets.game.clear();
    LuminaUserWidgets.editor.clear();
  });

  test('an editor panel script survives the game registry being cleared and only the editor world ticks it', () {
    LuminaUserWidgets.editor.register('EPW_BatchRename', _Panel.new);
    LuminaUserWidgets.game.register('WBP_Hud', _Panel.new);

    final gameWorld = LuminaWorld(worldType: LuminaWorldType.game)..beginPlay();
    final editorWorld = LuminaWorld(worldType: LuminaWorldType.game)..beginPlay();

    final panel = <String, Object?>{'class': 'EPW_BatchRename', 'inViewport': false, 'elements': <String, Object?>{}};
    final script = LuminaUserWidgets.editor.attach(editorWorld, panel)! as _Panel;
    expect(LuminaUserWidgets.game.attach(gameWorld, {'class': 'EPW_BatchRename'}), isNull,
        reason: 'the game registry does not know editor panels');

    // Play starts: PIE clears the game registry.
    LuminaUserWidgets.clear();
    expect(LuminaUserWidgets.game.has('WBP_Hud'), isFalse);
    expect(LuminaUserWidgets.editor.has('EPW_BatchRename'), isTrue);
    expect(identical(LuminaUserWidgets.of(panel), script), isTrue);

    // The panel is shown: Construct, and editor-world ticks reach it.
    panel['inViewport'] = true;
    LuminaUserWidgets.addedToViewport(panel);
    expect(script.calls, ['construct']);
    gameWorld.tick(1 / 60);
    gameWorld.tick(1 / 60);
    expect(script.ticks, 0, reason: 'game Tick never reaches an editor panel');
    editorWorld.tick(1 / 60);
    expect(script.ticks, 1);

    // Hidden: no ticks; closed: Destruct.
    panel['inViewport'] = false;
    editorWorld.tick(1 / 60);
    expect(script.ticks, 1);
    LuminaUserWidgets.removedFromParent(panel);
    expect(script.calls, ['construct', 'destruct']);
  });

  test('the static members keep acting on the game registry', () {
    LuminaUserWidgets.register('WBP_Hud', _Panel.new);
    expect(LuminaUserWidgets.game.has('WBP_Hud'), isTrue);
    expect(LuminaUserWidgets.editor.has('WBP_Hud'), isFalse);
    expect(LuminaUserWidgets.classNames, ['WBP_Hud']);
    LuminaUserWidgets.unregister('WBP_Hud');
    expect(LuminaUserWidgets.has('WBP_Hud'), isFalse);
  });
}
