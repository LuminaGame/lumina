/// The names generated Dart code gives what the user named in the editor.
///
/// Assets keep their prefixed names (`L_Main`, `BP_Door`,
/// `WBP_PlayerHUD`); the code generated from them follows Dart's naming
/// rules. One rule, used by every generator:
///
/// * The name is split into parts on `_` and on every other character that is
///   not an ASCII letter or digit.
/// * **Types** (classes, enums, mixins — [dartTypeName]) are UpperCamelCase:
///   a part without lower-case letters is a word or an acronym, so its first
///   letter is upper-cased and the rest lower-cased (`BP` → `Bp`, `HUD` →
///   `Hud`, `L` → `L`); a part with lower-case letters keeps its own casing
///   with the first letter upper-cased (`ThirdPersonCharacter`, `door` →
///   `Door`). `L_Main` → `LMain`, `BP_Door` → `BpDoor`,
///   `BP_ThirdPersonCharacter` → `BpThirdPersonCharacter`, `WBP_Hud` →
///   `WbpHud`.
/// * **Files** ([dartFileName]) are snake_case: every part is split at its
///   camel-case boundaries, lower-cased and joined with `_` (`L_Main` →
///   `l_main.dart`, `BP_ThirdPersonCharacter` →
///   `bp_third_person_character.dart`, `WBP_PlayerHUD` → `wbp_player_hud.dart`).
/// * **Members** (fields, variables, functions — [dartMemberName]) are
///   lowerCamelCase: the first part is lower-cased (a leading acronym as a
///   whole: `HPMax` → `hpMax`), the others follow the type rule
///   (`Max_HP` → `maxHp`).
/// * A name starting with a digit gets an `N` / `n` prefix (`3D_Level` →
///   `N3dLevel`, `n3d_level.dart`); a member that is a Dart keyword (or in a
///   caller's reserved set) gets a trailing `_` (`class_`); a type that would
///   shadow a `dart:core` type or `Function` gets an `Asset` suffix
///   (`StringAsset`); a name with no letters or digits gets the fallback.
library;

final RegExp _separators = RegExp(r'[^A-Za-z0-9]+');

List<String> _parts(String name) => name.split(_separators).where((p) => p.isNotEmpty).toList();

bool _isUpper(String c) => c.toUpperCase() == c && c.toLowerCase() != c;
bool _isLower(String c) => c.toLowerCase() == c && c.toUpperCase() != c;
bool _isDigit(String c) => c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39;
bool _hasLower(String p) => p.split('').any(_isLower);

/// One part of a type name: an all-caps part is a word (`BP` → `Bp`).
String _typePart(String p) {
  if (!_hasLower(p)) return p[0].toUpperCase() + p.substring(1).toLowerCase();
  return p[0].toUpperCase() + p.substring(1);
}

/// The first part of a member name: lower-cased, a leading acronym as a
/// whole (`HPMax` → `hpMax`, `MaxHP` → `maxHP`).
String _firstMemberPart(String p) {
  if (!_hasLower(p)) return p.toLowerCase();
  var run = 0;
  while (run < p.length && _isUpper(p[run])) {
    run++;
  }
  if (run <= 1) return p[0].toLowerCase() + p.substring(1);
  // The last capital of the run starts the next word when a lower-case letter follows it.
  final keep = run < p.length && _isLower(p[run]) ? run - 1 : run;
  return p.substring(0, keep).toLowerCase() + p.substring(keep);
}

/// One part split at its camel-case boundaries, lower-cased and joined with
/// `_` (`ThirdPersonCharacter` → `third_person_character`, `PlayerHUD` →
/// `player_hud`, `HUDMode` → `hud_mode`).
String _snakePart(String p) {
  if (!_hasLower(p)) return p.toLowerCase();
  final b = StringBuffer();
  for (var i = 0; i < p.length; i++) {
    final c = p[i];
    if (i > 0 && _isUpper(c)) {
      final prev = p[i - 1];
      final nextLower = i + 1 < p.length && _isLower(p[i + 1]);
      if (_isLower(prev) || _isDigit(prev) || (_isUpper(prev) && nextLower)) b.write('_');
    }
    b.write(c.toLowerCase());
  }
  return b.toString();
}

/// Dart's reserved words and built-in identifiers, plus `async` / `await` /
/// `yield` (reserved inside asynchronous and generator bodies).
const Set<String> dartKeywords = {
  'abstract', 'as', 'assert', 'async', 'await', 'break', 'case', 'catch', 'class', 'const', 'continue',
  'covariant', 'default', 'deferred', 'do', 'dynamic', 'else', 'enum', 'export', 'extends', 'extension',
  'external', 'factory', 'false', 'final', 'finally', 'for', 'Function', 'get', 'if', 'implements', 'import',
  'in', 'interface', 'is', 'late', 'library', 'mixin', 'new', 'null', 'operator', 'part', 'required', 'rethrow',
  'return', 'set', 'static', 'super', 'switch', 'this', 'throw', 'true', 'try', 'typedef', 'var', 'void', 'while',
  'with', 'yield',
};

/// Whether [name] is in [dartKeywords].
bool isDartKeyword(String name) => dartKeywords.contains(name);

/// Type names a generated class must not take: `Function` (a built-in
/// identifier) and the `dart:core` types generated code itself uses.
const Set<String> _reservedTypeNames = {
  'Function', 'Object', 'String', 'List', 'Map', 'Set', 'Type', 'Null', 'Never', 'Record', 'Enum', 'Future',
  'Stream', 'Iterable', 'Iterator', 'Symbol', 'Duration', 'DateTime', 'Error', 'Exception', 'Comparable',
  'Pattern', 'RegExp', 'Uri', 'BigInt', 'StackTrace', 'Sink', 'StringBuffer',
};

/// The UpperCamelCase Dart type name generated for the user name [name]
/// (`L_Main` → `LMain`, `BP_Door` → `BpDoor`); [fallback] when [name] has no
/// letters or digits.
String dartTypeName(String name, {String fallback = 'Generated'}) {
  final joined = _parts(name).map(_typePart).join();
  if (joined.isEmpty) return fallback;
  if (_isDigit(joined[0])) return 'N$joined';
  return _reservedTypeNames.contains(joined) ? '${joined}Asset' : joined;
}

/// The snake_case file name (without `.dart`) generated for [name]
/// (`BP_ThirdPersonCharacter` → `bp_third_person_character`); [fallback]
/// when [name] has no letters or digits.
String dartFileStem(String name, {String fallback = 'generated'}) {
  final joined = _parts(name).map(_snakePart).join('_');
  if (joined.isEmpty) return fallback;
  return _isDigit(joined[0]) ? 'n$joined' : joined;
}

/// [dartFileStem] with the `.dart` extension (`L_Main` → `l_main.dart`).
String dartFileName(String name, {String fallback = 'generated'}) => '${dartFileStem(name, fallback: fallback)}.dart';

/// [name] in lowerCamelCase without escaping keywords or leading digits
/// (`HealthBar Progress` → `healthBarProgress`); '' when nothing is left.
String dartLowerCamelCase(String name) {
  final parts = _parts(name);
  if (parts.isEmpty) return '';
  return _firstMemberPart(parts.first) + parts.skip(1).map(_typePart).join();
}

/// The lowerCamelCase Dart member name generated for the user name [name]
/// (`Max Health` → `maxHealth`): a leading digit gets an `n` prefix, a Dart
/// keyword or a name in [reserved] a trailing `_`, and a name with no letters
/// or digits is [fallback].
String dartMemberName(String name, {Set<String> reserved = const {}, String fallback = 'value'}) {
  var id = dartLowerCamelCase(name);
  if (id.isEmpty) id = fallback;
  if (_isDigit(id[0])) id = 'n$id';
  return isDartKeyword(id) || reserved.contains(id) ? '${id}_' : id;
}

/// The class name generators used before [dartTypeName] (`BP_Door` →
/// `BPDoor`): what files generated by earlier versions declare, so they can
/// be migrated.
String legacyDartClassName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
  return [for (final p in cleaned.split('_')) if (p.isNotEmpty) p[0].toUpperCase() + p.substring(1)].join();
}
