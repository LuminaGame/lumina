/// Represents a physical or virtual input hardware key / axis.
///
/// The whole keyboard (letters, digits, F1–F12, arrows, the
/// editing keys, both sides' Shift / Ctrl / Alt / Meta, the locks, the numpad
/// and punctuation), the mouse buttons and axes and the gamepad keys the
/// templates bind. A keyboard key's [keyId] is Flutter's
/// `LogicalKeyboardKey.keyId` — what the Project Settings key picker stores
/// in the `.lmproject` manifest — and the mouse / gamepad keys carry the
/// manifest's negative sentinels, so [fromKeyId] is the one table PIE, the
/// project input binder and the generated game all read.
class LuminaKey {
  final String id;
  final bool isAnalog;

  /// Flutter's `LogicalKeyboardKey.keyId` for a keyboard key, a negative
  /// manifest sentinel for a mouse / gamepad key, null for a key no manifest
  /// can name (touch drag, a Blueprint's own key).
  final int? keyId;

  const LuminaKey._(this.id, {this.isAnalog = false, this.keyId});

  static const keyA = LuminaKey._('KeyA', keyId: 0x00000061);
  static const keyB = LuminaKey._('KeyB', keyId: 0x00000062);
  static const keyC = LuminaKey._('KeyC', keyId: 0x00000063);
  static const keyD = LuminaKey._('KeyD', keyId: 0x00000064);
  static const keyE = LuminaKey._('KeyE', keyId: 0x00000065);
  static const keyF = LuminaKey._('KeyF', keyId: 0x00000066);
  static const keyG = LuminaKey._('KeyG', keyId: 0x00000067);
  static const keyH = LuminaKey._('KeyH', keyId: 0x00000068);
  static const keyI = LuminaKey._('KeyI', keyId: 0x00000069);
  static const keyJ = LuminaKey._('KeyJ', keyId: 0x0000006a);
  static const keyK = LuminaKey._('KeyK', keyId: 0x0000006b);
  static const keyL = LuminaKey._('KeyL', keyId: 0x0000006c);
  static const keyM = LuminaKey._('KeyM', keyId: 0x0000006d);
  static const keyN = LuminaKey._('KeyN', keyId: 0x0000006e);
  static const keyO = LuminaKey._('KeyO', keyId: 0x0000006f);
  static const keyP = LuminaKey._('KeyP', keyId: 0x00000070);
  static const keyQ = LuminaKey._('KeyQ', keyId: 0x00000071);
  static const keyR = LuminaKey._('KeyR', keyId: 0x00000072);
  static const keyS = LuminaKey._('KeyS', keyId: 0x00000073);
  static const keyT = LuminaKey._('KeyT', keyId: 0x00000074);
  static const keyU = LuminaKey._('KeyU', keyId: 0x00000075);
  static const keyV = LuminaKey._('KeyV', keyId: 0x00000076);
  static const keyW = LuminaKey._('KeyW', keyId: 0x00000077);
  static const keyX = LuminaKey._('KeyX', keyId: 0x00000078);
  static const keyY = LuminaKey._('KeyY', keyId: 0x00000079);
  static const keyZ = LuminaKey._('KeyZ', keyId: 0x0000007a);
  static const key0 = LuminaKey._('Key0', keyId: 0x00000030);
  static const key1 = LuminaKey._('Key1', keyId: 0x00000031);
  static const key2 = LuminaKey._('Key2', keyId: 0x00000032);
  static const key3 = LuminaKey._('Key3', keyId: 0x00000033);
  static const key4 = LuminaKey._('Key4', keyId: 0x00000034);
  static const key5 = LuminaKey._('Key5', keyId: 0x00000035);
  static const key6 = LuminaKey._('Key6', keyId: 0x00000036);
  static const key7 = LuminaKey._('Key7', keyId: 0x00000037);
  static const key8 = LuminaKey._('Key8', keyId: 0x00000038);
  static const key9 = LuminaKey._('Key9', keyId: 0x00000039);
  static const keyF1 = LuminaKey._('KeyF1', keyId: 0x100000801);
  static const keyF2 = LuminaKey._('KeyF2', keyId: 0x100000802);
  static const keyF3 = LuminaKey._('KeyF3', keyId: 0x100000803);
  static const keyF4 = LuminaKey._('KeyF4', keyId: 0x100000804);
  static const keyF5 = LuminaKey._('KeyF5', keyId: 0x100000805);
  static const keyF6 = LuminaKey._('KeyF6', keyId: 0x100000806);
  static const keyF7 = LuminaKey._('KeyF7', keyId: 0x100000807);
  static const keyF8 = LuminaKey._('KeyF8', keyId: 0x100000808);
  static const keyF9 = LuminaKey._('KeyF9', keyId: 0x100000809);
  static const keyF10 = LuminaKey._('KeyF10', keyId: 0x10000080a);
  static const keyF11 = LuminaKey._('KeyF11', keyId: 0x10000080b);
  static const keyF12 = LuminaKey._('KeyF12', keyId: 0x10000080c);
  static const keyArrowUp = LuminaKey._('KeyArrowUp', keyId: 0x100000304);
  static const keyArrowDown = LuminaKey._('KeyArrowDown', keyId: 0x100000301);
  static const keyArrowLeft = LuminaKey._('KeyArrowLeft', keyId: 0x100000302);
  static const keyArrowRight = LuminaKey._('KeyArrowRight', keyId: 0x100000303);
  static const keySpace = LuminaKey._('KeySpace', keyId: 0x00000020);
  static const keyTab = LuminaKey._('KeyTab', keyId: 0x100000009);
  static const keyEnter = LuminaKey._('KeyEnter', keyId: 0x10000000d);
  static const keyEscape = LuminaKey._('KeyEscape', keyId: 0x10000001b);
  static const keyBackspace = LuminaKey._('KeyBackspace', keyId: 0x100000008);
  static const keyDelete = LuminaKey._('KeyDelete', keyId: 0x10000007f);
  static const keyInsert = LuminaKey._('KeyInsert', keyId: 0x100000407);
  static const keyHome = LuminaKey._('KeyHome', keyId: 0x100000306);
  static const keyEnd = LuminaKey._('KeyEnd', keyId: 0x100000305);
  static const keyPageUp = LuminaKey._('KeyPageUp', keyId: 0x100000308);
  static const keyPageDown = LuminaKey._('KeyPageDown', keyId: 0x100000307);
  static const keyLeftShift = LuminaKey._('KeyLeftShift', keyId: 0x200000102);
  static const keyRightShift = LuminaKey._('KeyRightShift', keyId: 0x200000103);
  static const keyLeftControl = LuminaKey._('KeyLeftControl', keyId: 0x200000100);
  static const keyRightControl = LuminaKey._('KeyRightControl', keyId: 0x200000101);
  static const keyLeftAlt = LuminaKey._('KeyLeftAlt', keyId: 0x200000104);
  static const keyRightAlt = LuminaKey._('KeyRightAlt', keyId: 0x200000105);
  static const keyLeftMeta = LuminaKey._('KeyLeftMeta', keyId: 0x200000106);
  static const keyRightMeta = LuminaKey._('KeyRightMeta', keyId: 0x200000107);
  static const keyCapsLock = LuminaKey._('KeyCapsLock', keyId: 0x100000104);
  static const keyNumLock = LuminaKey._('KeyNumLock', keyId: 0x10000010a);
  static const keyScrollLock = LuminaKey._('KeyScrollLock', keyId: 0x10000010c);
  static const keyPrintScreen = LuminaKey._('KeyPrintScreen', keyId: 0x100000608);
  static const keyPause = LuminaKey._('KeyPause', keyId: 0x100000509);
  static const keyContextMenu = LuminaKey._('KeyContextMenu', keyId: 0x100000505);
  static const keyNumpad0 = LuminaKey._('KeyNumpad0', keyId: 0x200000230);
  static const keyNumpad1 = LuminaKey._('KeyNumpad1', keyId: 0x200000231);
  static const keyNumpad2 = LuminaKey._('KeyNumpad2', keyId: 0x200000232);
  static const keyNumpad3 = LuminaKey._('KeyNumpad3', keyId: 0x200000233);
  static const keyNumpad4 = LuminaKey._('KeyNumpad4', keyId: 0x200000234);
  static const keyNumpad5 = LuminaKey._('KeyNumpad5', keyId: 0x200000235);
  static const keyNumpad6 = LuminaKey._('KeyNumpad6', keyId: 0x200000236);
  static const keyNumpad7 = LuminaKey._('KeyNumpad7', keyId: 0x200000237);
  static const keyNumpad8 = LuminaKey._('KeyNumpad8', keyId: 0x200000238);
  static const keyNumpad9 = LuminaKey._('KeyNumpad9', keyId: 0x200000239);
  static const keyNumpadAdd = LuminaKey._('KeyNumpadAdd', keyId: 0x20000022b);
  static const keyNumpadSubtract = LuminaKey._('KeyNumpadSubtract', keyId: 0x20000022d);
  static const keyNumpadMultiply = LuminaKey._('KeyNumpadMultiply', keyId: 0x20000022a);
  static const keyNumpadDivide = LuminaKey._('KeyNumpadDivide', keyId: 0x20000022f);
  static const keyNumpadDecimal = LuminaKey._('KeyNumpadDecimal', keyId: 0x20000022e);
  static const keyNumpadEnter = LuminaKey._('KeyNumpadEnter', keyId: 0x20000020d);
  static const keyNumpadEqual = LuminaKey._('KeyNumpadEqual', keyId: 0x20000023d);
  static const keyNumpadComma = LuminaKey._('KeyNumpadComma', keyId: 0x20000022c);
  static const keyMinus = LuminaKey._('KeyMinus', keyId: 0x0000002d);
  static const keyEqual = LuminaKey._('KeyEqual', keyId: 0x0000003d);
  static const keyBracketLeft = LuminaKey._('KeyBracketLeft', keyId: 0x0000005b);
  static const keyBracketRight = LuminaKey._('KeyBracketRight', keyId: 0x0000005d);
  static const keyBackslash = LuminaKey._('KeyBackslash', keyId: 0x0000005c);
  static const keySemicolon = LuminaKey._('KeySemicolon', keyId: 0x0000003b);
  static const keyQuote = LuminaKey._('KeyQuote', keyId: 0x00000022);
  static const keyBackquote = LuminaKey._('KeyBackquote', keyId: 0x00000060);
  static const keyComma = LuminaKey._('KeyComma', keyId: 0x0000002c);
  static const keyPeriod = LuminaKey._('KeyPeriod', keyId: 0x0000002e);
  static const keySlash = LuminaKey._('KeySlash', keyId: 0x0000002f);
  static const keyIntlBackslash = LuminaKey._('KeyIntlBackslash', keyId: 0x200000020);
  static const mouseX = LuminaKey._('MouseX', keyId: -1, isAnalog: true);
  static const mouseY = LuminaKey._('MouseY', keyId: -2, isAnalog: true);
  static const mouseLeft = LuminaKey._('MouseLeft', keyId: -6);
  static const mouseRight = LuminaKey._('MouseRight', keyId: -7);
  static const mouseMiddle = LuminaKey._('MouseMiddle', keyId: -8);
  static const mouseThumb1 = LuminaKey._('MouseThumb1', keyId: -9);
  static const mouseThumb2 = LuminaKey._('MouseThumb2', keyId: -10);
  static const gamepadLeftStickX = LuminaKey._('GamepadLeftStickX', keyId: -12, isAnalog: true);
  static const gamepadLeftStickY = LuminaKey._('GamepadLeftStickY', keyId: -13, isAnalog: true);
  static const gamepadFaceButtonBottom = LuminaKey._('GamepadFaceButtonBottom', keyId: -11);
  static const gamepadFaceButtonRight = LuminaKey._('GamepadFaceButtonRight', keyId: -3);
  static const gamepadLeftThumbstick = LuminaKey._('GamepadLeftThumbstick', keyId: -4);
  static const gamepadRightThumbstick = LuminaKey._('GamepadRightThumbstick', keyId: -5);
  static const touchDrag = LuminaKey._('TouchDrag', isAnalog: true);

  /// Every key the engine names.
  static const List<LuminaKey> values = [
    keyA,
    keyB,
    keyC,
    keyD,
    keyE,
    keyF,
    keyG,
    keyH,
    keyI,
    keyJ,
    keyK,
    keyL,
    keyM,
    keyN,
    keyO,
    keyP,
    keyQ,
    keyR,
    keyS,
    keyT,
    keyU,
    keyV,
    keyW,
    keyX,
    keyY,
    keyZ,
    key0,
    key1,
    key2,
    key3,
    key4,
    key5,
    key6,
    key7,
    key8,
    key9,
    keyF1,
    keyF2,
    keyF3,
    keyF4,
    keyF5,
    keyF6,
    keyF7,
    keyF8,
    keyF9,
    keyF10,
    keyF11,
    keyF12,
    keyArrowUp,
    keyArrowDown,
    keyArrowLeft,
    keyArrowRight,
    keySpace,
    keyTab,
    keyEnter,
    keyEscape,
    keyBackspace,
    keyDelete,
    keyInsert,
    keyHome,
    keyEnd,
    keyPageUp,
    keyPageDown,
    keyLeftShift,
    keyRightShift,
    keyLeftControl,
    keyRightControl,
    keyLeftAlt,
    keyRightAlt,
    keyLeftMeta,
    keyRightMeta,
    keyCapsLock,
    keyNumLock,
    keyScrollLock,
    keyPrintScreen,
    keyPause,
    keyContextMenu,
    keyNumpad0,
    keyNumpad1,
    keyNumpad2,
    keyNumpad3,
    keyNumpad4,
    keyNumpad5,
    keyNumpad6,
    keyNumpad7,
    keyNumpad8,
    keyNumpad9,
    keyNumpadAdd,
    keyNumpadSubtract,
    keyNumpadMultiply,
    keyNumpadDivide,
    keyNumpadDecimal,
    keyNumpadEnter,
    keyNumpadEqual,
    keyNumpadComma,
    keyMinus,
    keyEqual,
    keyBracketLeft,
    keyBracketRight,
    keyBackslash,
    keySemicolon,
    keyQuote,
    keyBackquote,
    keyComma,
    keyPeriod,
    keySlash,
    keyIntlBackslash,
    mouseX,
    mouseY,
    mouseLeft,
    mouseRight,
    mouseMiddle,
    mouseThumb1,
    mouseThumb2,
    gamepadLeftStickX,
    gamepadLeftStickY,
    gamepadFaceButtonBottom,
    gamepadFaceButtonRight,
    gamepadLeftThumbstick,
    gamepadRightThumbstick,
    touchDrag,
  ];

  static final Map<int, LuminaKey> _byKeyId = {
    for (final k in values)
      if (k.keyId != null) k.keyId!: k,
    // An apostrophe delivered as its own code point is Flutter's `quote` key.
    0x27: keyQuote,
  };

  /// The key a manifest mapping / a Flutter `LogicalKeyboardKey.keyId`
  /// names, or null for a key the engine does not know.
  static LuminaKey? fromKeyId(int keyId) => _byKeyId[keyId];

  /// Other names for keys: long-form names, Flutter's `keyLabel`s where they differ
  /// from the id, and the printable characters.
  static const Map<String, LuminaKey> _aliases = {
    'Zero': key0,
    'Digit0': key0,
    'One': key1,
    'Digit1': key1,
    'Two': key2,
    'Digit2': key2,
    'Three': key3,
    'Digit3': key3,
    'Four': key4,
    'Digit4': key4,
    'Five': key5,
    'Digit5': key5,
    'Six': key6,
    'Digit6': key6,
    'Seven': key7,
    'Digit7': key7,
    'Eight': key8,
    'Digit8': key8,
    'Nine': key9,
    'Digit9': key9,
    'Up': keyArrowUp,
    'UpArrow': keyArrowUp,
    'Down': keyArrowDown,
    'DownArrow': keyArrowDown,
    'Left': keyArrowLeft,
    'LeftArrow': keyArrowLeft,
    'Right': keyArrowRight,
    'RightArrow': keyArrowRight,
    'SpaceBar': keySpace,
    'Return': keyEnter,
    'Esc': keyEscape,
    'Del': keyDelete,
    'ShiftLeft': keyLeftShift,
    'ShiftRight': keyRightShift,
    'ControlLeft': keyLeftControl,
    'LeftCtrl': keyLeftControl,
    'CtrlLeft': keyLeftControl,
    'ControlRight': keyRightControl,
    'RightCtrl': keyRightControl,
    'CtrlRight': keyRightControl,
    'AltLeft': keyLeftAlt,
    'AltRight': keyRightAlt,
    'AltGr': keyRightAlt,
    'MetaLeft': keyLeftMeta,
    'LeftCommand': keyLeftMeta,
    'LeftSuper': keyLeftMeta,
    'LeftWindows': keyLeftMeta,
    'MetaRight': keyRightMeta,
    'RightCommand': keyRightMeta,
    'RightSuper': keyRightMeta,
    'RightWindows': keyRightMeta,
    'NumPadZero': keyNumpad0,
    'NumPadOne': keyNumpad1,
    'NumPadTwo': keyNumpad2,
    'NumPadThree': keyNumpad3,
    'NumPadFour': keyNumpad4,
    'NumPadFive': keyNumpad5,
    'NumPadSix': keyNumpad6,
    'NumPadSeven': keyNumpad7,
    'NumPadEight': keyNumpad8,
    'NumPadNine': keyNumpad9,
    'Add': keyNumpadAdd,
    'Subtract': keyNumpadSubtract,
    'Multiply': keyNumpadMultiply,
    'Divide': keyNumpadDivide,
    'Decimal': keyNumpadDecimal,
    'Hyphen': keyMinus,
    '-': keyMinus,
    'Equals': keyEqual,
    '=': keyEqual,
    'LeftBracket': keyBracketLeft,
    '[': keyBracketLeft,
    'RightBracket': keyBracketRight,
    ']': keyBracketRight,
    '\\': keyBackslash,
    ';': keySemicolon,
    'Apostrophe': keyQuote,
    '\'': keyQuote,
    '"': keyQuote,
    'Tilde': keyBackquote,
    'Backtick': keyBackquote,
    '`': keyBackquote,
    ',': keyComma,
    '.': keyPeriod,
    '/': keySlash,
    'LeftMouseButton': mouseLeft,
    'RightMouseButton': mouseRight,
    'MiddleMouseButton': mouseMiddle,
    'ThumbMouseButton': mouseThumb1,
    'ThumbMouseButton2': mouseThumb2,
    'Gamepad_LeftX': gamepadLeftStickX,
    'Gamepad_LeftY': gamepadLeftStickY,
  };

  static String _normalize(String name) => name.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');

  static final Map<String, LuminaKey> _byName = () {
    final map = <String, LuminaKey>{};
    void add(String name, LuminaKey key) {
      final t = name.trim();
      final n = t.length == 1 ? t.toLowerCase() : _normalize(t);
      if (n.isNotEmpty) map.putIfAbsent(n, () => key);
    }

    for (final k in values) {
      add(k.id, k);
      if (k.id.startsWith('Key')) {
        final bare = k.id.substring(3);
        add(bare, k);
        // Flutter's labels put the side last: "Shift Left", "Alt Left".
        final side = RegExp(r'^(Left|Right)(.+)$').firstMatch(bare);
        if (side != null) add('${side.group(2)}${side.group(1)}', k);
      }
    }
    _aliases.forEach(add);
    return map;
  }();

  /// The key a Blueprint or a manifest label names:
  /// the id (`KeyV`), the bare name (`V`, `F5`, `Space`), Flutter's label
  /// (`Alt Left`, `Arrow Up`, `Numpad 1`) or the long-form name
  /// (`LeftMouseButton`, `SpaceBar`, `NumPadOne`); case, spaces and
  /// underscores do not matter. An unknown name makes a new digital key of
  /// that id so a project's own keys still work.
  static LuminaKey fromName(String name) {
    final trimmed = name.trim();
    final exact = trimmed.length == 1 ? _byName[trimmed.toLowerCase()] : null;
    if (exact != null) return exact;
    final n = _normalize(trimmed);
    final found = _byName[n];
    if (found != null) return found;
    // "Key V" / "Digit 5": Flutter's debug names.
    for (final prefix in const ['key', 'digit']) {
      if (n.startsWith(prefix) && n.length > prefix.length) {
        final rest = _byName[n.substring(prefix.length)];
        if (rest != null) return rest;
      }
    }
    return LuminaKey._(trimmed);
  }

  @override
  bool operator ==(Object other) => identical(this, other) || (other is LuminaKey && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'LuminaKey($id)';
}
