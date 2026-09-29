import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// Every keyboard key maps to a [LuminaKey] through one
/// table (`LuminaKey.fromKeyId`), so a Project Settings binding on V, F5, an
/// arrow or a numpad key reaches PIE and the built game.
void main() {
  /// The keys a full keyboard sends (what the Project Settings key picker can
  /// capture), with the LuminaKey each must become.
  final keyboard = <LogicalKeyboardKey, LuminaKey>{
    LogicalKeyboardKey.keyA: LuminaKey.keyA, LogicalKeyboardKey.keyB: LuminaKey.keyB,
    LogicalKeyboardKey.keyC: LuminaKey.keyC, LogicalKeyboardKey.keyD: LuminaKey.keyD,
    LogicalKeyboardKey.keyE: LuminaKey.keyE, LogicalKeyboardKey.keyF: LuminaKey.keyF,
    LogicalKeyboardKey.keyG: LuminaKey.keyG, LogicalKeyboardKey.keyH: LuminaKey.keyH,
    LogicalKeyboardKey.keyI: LuminaKey.keyI, LogicalKeyboardKey.keyJ: LuminaKey.keyJ,
    LogicalKeyboardKey.keyK: LuminaKey.keyK, LogicalKeyboardKey.keyL: LuminaKey.keyL,
    LogicalKeyboardKey.keyM: LuminaKey.keyM, LogicalKeyboardKey.keyN: LuminaKey.keyN,
    LogicalKeyboardKey.keyO: LuminaKey.keyO, LogicalKeyboardKey.keyP: LuminaKey.keyP,
    LogicalKeyboardKey.keyQ: LuminaKey.keyQ, LogicalKeyboardKey.keyR: LuminaKey.keyR,
    LogicalKeyboardKey.keyS: LuminaKey.keyS, LogicalKeyboardKey.keyT: LuminaKey.keyT,
    LogicalKeyboardKey.keyU: LuminaKey.keyU, LogicalKeyboardKey.keyV: LuminaKey.keyV,
    LogicalKeyboardKey.keyW: LuminaKey.keyW, LogicalKeyboardKey.keyX: LuminaKey.keyX,
    LogicalKeyboardKey.keyY: LuminaKey.keyY, LogicalKeyboardKey.keyZ: LuminaKey.keyZ,
    LogicalKeyboardKey.digit0: LuminaKey.key0, LogicalKeyboardKey.digit1: LuminaKey.key1,
    LogicalKeyboardKey.digit2: LuminaKey.key2, LogicalKeyboardKey.digit3: LuminaKey.key3,
    LogicalKeyboardKey.digit4: LuminaKey.key4, LogicalKeyboardKey.digit5: LuminaKey.key5,
    LogicalKeyboardKey.digit6: LuminaKey.key6, LogicalKeyboardKey.digit7: LuminaKey.key7,
    LogicalKeyboardKey.digit8: LuminaKey.key8, LogicalKeyboardKey.digit9: LuminaKey.key9,
    LogicalKeyboardKey.f1: LuminaKey.keyF1, LogicalKeyboardKey.f2: LuminaKey.keyF2,
    LogicalKeyboardKey.f3: LuminaKey.keyF3, LogicalKeyboardKey.f4: LuminaKey.keyF4,
    LogicalKeyboardKey.f5: LuminaKey.keyF5, LogicalKeyboardKey.f6: LuminaKey.keyF6,
    LogicalKeyboardKey.f7: LuminaKey.keyF7, LogicalKeyboardKey.f8: LuminaKey.keyF8,
    LogicalKeyboardKey.f9: LuminaKey.keyF9, LogicalKeyboardKey.f10: LuminaKey.keyF10,
    LogicalKeyboardKey.f11: LuminaKey.keyF11, LogicalKeyboardKey.f12: LuminaKey.keyF12,
    LogicalKeyboardKey.arrowUp: LuminaKey.keyArrowUp, LogicalKeyboardKey.arrowDown: LuminaKey.keyArrowDown,
    LogicalKeyboardKey.arrowLeft: LuminaKey.keyArrowLeft, LogicalKeyboardKey.arrowRight: LuminaKey.keyArrowRight,
    LogicalKeyboardKey.space: LuminaKey.keySpace, LogicalKeyboardKey.tab: LuminaKey.keyTab,
    LogicalKeyboardKey.enter: LuminaKey.keyEnter, LogicalKeyboardKey.escape: LuminaKey.keyEscape,
    LogicalKeyboardKey.backspace: LuminaKey.keyBackspace, LogicalKeyboardKey.delete: LuminaKey.keyDelete,
    LogicalKeyboardKey.insert: LuminaKey.keyInsert, LogicalKeyboardKey.home: LuminaKey.keyHome,
    LogicalKeyboardKey.end: LuminaKey.keyEnd, LogicalKeyboardKey.pageUp: LuminaKey.keyPageUp,
    LogicalKeyboardKey.pageDown: LuminaKey.keyPageDown,
    LogicalKeyboardKey.shiftLeft: LuminaKey.keyLeftShift, LogicalKeyboardKey.shiftRight: LuminaKey.keyRightShift,
    LogicalKeyboardKey.controlLeft: LuminaKey.keyLeftControl, LogicalKeyboardKey.controlRight: LuminaKey.keyRightControl,
    LogicalKeyboardKey.altLeft: LuminaKey.keyLeftAlt, LogicalKeyboardKey.altRight: LuminaKey.keyRightAlt,
    LogicalKeyboardKey.metaLeft: LuminaKey.keyLeftMeta, LogicalKeyboardKey.metaRight: LuminaKey.keyRightMeta,
    LogicalKeyboardKey.capsLock: LuminaKey.keyCapsLock, LogicalKeyboardKey.numLock: LuminaKey.keyNumLock,
    LogicalKeyboardKey.scrollLock: LuminaKey.keyScrollLock, LogicalKeyboardKey.printScreen: LuminaKey.keyPrintScreen,
    LogicalKeyboardKey.pause: LuminaKey.keyPause, LogicalKeyboardKey.contextMenu: LuminaKey.keyContextMenu,
    LogicalKeyboardKey.numpad0: LuminaKey.keyNumpad0, LogicalKeyboardKey.numpad1: LuminaKey.keyNumpad1,
    LogicalKeyboardKey.numpad2: LuminaKey.keyNumpad2, LogicalKeyboardKey.numpad3: LuminaKey.keyNumpad3,
    LogicalKeyboardKey.numpad4: LuminaKey.keyNumpad4, LogicalKeyboardKey.numpad5: LuminaKey.keyNumpad5,
    LogicalKeyboardKey.numpad6: LuminaKey.keyNumpad6, LogicalKeyboardKey.numpad7: LuminaKey.keyNumpad7,
    LogicalKeyboardKey.numpad8: LuminaKey.keyNumpad8, LogicalKeyboardKey.numpad9: LuminaKey.keyNumpad9,
    LogicalKeyboardKey.numpadAdd: LuminaKey.keyNumpadAdd, LogicalKeyboardKey.numpadSubtract: LuminaKey.keyNumpadSubtract,
    LogicalKeyboardKey.numpadMultiply: LuminaKey.keyNumpadMultiply, LogicalKeyboardKey.numpadDivide: LuminaKey.keyNumpadDivide,
    LogicalKeyboardKey.numpadDecimal: LuminaKey.keyNumpadDecimal, LogicalKeyboardKey.numpadEnter: LuminaKey.keyNumpadEnter,
    LogicalKeyboardKey.numpadEqual: LuminaKey.keyNumpadEqual, LogicalKeyboardKey.numpadComma: LuminaKey.keyNumpadComma,
    LogicalKeyboardKey.minus: LuminaKey.keyMinus, LogicalKeyboardKey.equal: LuminaKey.keyEqual,
    LogicalKeyboardKey.bracketLeft: LuminaKey.keyBracketLeft, LogicalKeyboardKey.bracketRight: LuminaKey.keyBracketRight,
    LogicalKeyboardKey.backslash: LuminaKey.keyBackslash, LogicalKeyboardKey.semicolon: LuminaKey.keySemicolon,
    LogicalKeyboardKey.quote: LuminaKey.keyQuote, LogicalKeyboardKey.backquote: LuminaKey.keyBackquote,
    LogicalKeyboardKey.comma: LuminaKey.keyComma, LogicalKeyboardKey.period: LuminaKey.keyPeriod,
    LogicalKeyboardKey.slash: LuminaKey.keySlash, LogicalKeyboardKey.intlBackslash: LuminaKey.keyIntlBackslash,
  };

  test('every keyboard key maps through LuminaKey.fromKeyId and back through keyId', () {
    for (final e in keyboard.entries) {
      expect(LuminaKey.fromKeyId(e.key.keyId), e.value, reason: '${e.key.debugName} (0x${e.key.keyId.toRadixString(16)})');
      expect(e.value.keyId, e.key.keyId, reason: e.value.id);
      expect(LuminaKey.values, contains(e.value), reason: e.value.id);
    }
    // An apostrophe sent as its own code point is the same key as Flutter's `quote`.
    expect(LuminaKey.fromKeyId(0x27), LuminaKey.keyQuote);
    expect(LuminaKey.fromKeyId(0x12345678), isNull);
  });

  test('the mouse and gamepad keys carry the manifest sentinels; values names every key once', () {
    expect(LuminaKey.fromKeyId(-1), LuminaKey.mouseX);
    expect(LuminaKey.fromKeyId(-2), LuminaKey.mouseY);
    expect(LuminaKey.fromKeyId(-3), LuminaKey.gamepadFaceButtonRight);
    expect(LuminaKey.fromKeyId(-4), LuminaKey.gamepadLeftThumbstick);
    expect(LuminaKey.fromKeyId(-5), LuminaKey.gamepadRightThumbstick);
    for (final k in [LuminaKey.mouseLeft, LuminaKey.mouseRight, LuminaKey.mouseMiddle, LuminaKey.mouseThumb1, LuminaKey.mouseThumb2]) {
      expect(k.keyId, isNotNull, reason: k.id);
      expect(k.keyId!, lessThan(0), reason: k.id);
      expect(LuminaKey.fromKeyId(k.keyId!), k);
    }
    expect(LuminaKey.values, containsAll([LuminaKey.keyLeftAlt, LuminaKey.gamepadRightThumbstick, LuminaKey.touchDrag]));
    expect(LuminaKey.values.map((k) => k.id).toSet().length, LuminaKey.values.length, reason: 'ids are unique');
    final ids = [for (final k in LuminaKey.values) if (k.keyId != null) k.keyId];
    expect(ids.toSet().length, ids.length, reason: 'key ids are unique');
  });

  test('fromName resolves ids, bare names, Flutter labels and spelled-out names', () {
    const cases = {
      'V': LuminaKey.keyV,
      'KeyV': LuminaKey.keyV,
      'Key V': LuminaKey.keyV,
      'F5': LuminaKey.keyF5,
      '5': LuminaKey.key5,
      'Five': LuminaKey.key5,
      'Left Alt': LuminaKey.keyLeftAlt,
      'Alt Left': LuminaKey.keyLeftAlt,
      'LeftShift': LuminaKey.keyLeftShift,
      'Shift Right': LuminaKey.keyRightShift,
      'Left Ctrl': LuminaKey.keyLeftControl,
      'RightControl': LuminaKey.keyRightControl,
      'SpaceBar': LuminaKey.keySpace,
      'space': LuminaKey.keySpace,
      'Up': LuminaKey.keyArrowUp,
      'Arrow Left': LuminaKey.keyArrowLeft,
      'Page Up': LuminaKey.keyPageUp,
      'Enter': LuminaKey.keyEnter,
      'Escape': LuminaKey.keyEscape,
      'BackSpace': LuminaKey.keyBackspace,
      'NumPadOne': LuminaKey.keyNumpad1,
      'Numpad 1': LuminaKey.keyNumpad1,
      'Add': LuminaKey.keyNumpadAdd,
      'Hyphen': LuminaKey.keyMinus,
      'Tilde': LuminaKey.keyBackquote,
      'LeftMouseButton': LuminaKey.mouseLeft,
      'MiddleMouseButton': LuminaKey.mouseMiddle,
      'ThumbMouseButton': LuminaKey.mouseThumb1,
      'ThumbMouseButton2': LuminaKey.mouseThumb2,
      'Gamepad Right Thumbstick': LuminaKey.gamepadRightThumbstick,
    };
    for (final e in cases.entries) {
      expect(LuminaKey.fromName(e.key), e.value, reason: e.key);
    }
    // Unknown names still make a digital key of that id.
    expect(LuminaKey.fromName('MyCustomKey').id, 'MyCustomKey');
  });
}
