import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// Set Show Mouse Cursor / Set Input Mode changed flags on
/// the player controller that nothing read. The controller now publishes its
/// cursor state, and the owners of the pointer (PIE, the built game) follow
/// it.
void main() {
  test('setShowMouseCursor / setInputMode* notify listeners once per change', () {
    final pc = LuminaPlayerController();
    var notified = 0;
    pc.cursorState.addListener(() => notified++);
    expect(pc.wantsFreeCursor, isFalse, reason: 'a game starts with the mouse captured');

    pc.setShowMouseCursor(true);
    expect(notified, 1);
    expect(pc.bShowMouseCursor, isTrue);
    expect(pc.wantsFreeCursor, isTrue);
    pc.setShowMouseCursor(true);
    expect(notified, 1, reason: 'no change, no notification');

    pc.setShowMouseCursor(false);
    expect(pc.wantsFreeCursor, isFalse);
    pc.setInputModeUIOnly();
    expect(notified, 3);
    expect(pc.wantsFreeCursor, isTrue, reason: 'UI-only input frees the pointer');
    pc.setInputModeGameAndUI();
    expect(notified, 4);
    expect(pc.wantsFreeCursor, isTrue);
    pc.setInputModeGameOnly();
    expect(notified, 5);
    expect(pc.wantsFreeCursor, isFalse);
  });

  test("the user's graph, Target wired from Get Player Controller (variant B), leaves the cursor shown", () {
    final character = LuminaTemplateCharacter(thirdPerson: true);
    final pc = LuminaPlayerController()..possess(character);
    final ctx = LuminaBlueprintCallContext(character);
    final got = LuminaBlueprintFunctionLibrary.functions['get_player_controller']!(ctx, {'player_index': 0});
    LuminaBlueprintFunctionLibrary.functions['set_show_mouse_cursor']!(
        ctx, {'target': got['return_value'], 'show_mouse_cursor': true});
    expect(pc.bShowMouseCursor, isTrue);
    expect(pc.wantsFreeCursor, isTrue);
  });
}
