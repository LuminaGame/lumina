part of '../blueprint_function_library.dart';

// --- String / Conversion -----------------------------------------------------------

String _floatToString(double inFloat, [int decimals = 2]) =>
    inFloat.isFinite ? inFloat.toStringAsFixed(decimals < 0 ? 0 : (decimals > 20 ? 20 : decimals)) : '$inFloat';

String _intToString(int inInt) => '$inInt';

String _boolToString(bool inBool) => inBool ? 'true' : 'false';

String _vectorToString(Vector3 inVec) => 'X=${LuminaBlueprintFunctionLibrary.floatToString(inVec.x, 3)} Y=${LuminaBlueprintFunctionLibrary.floatToString(inVec.y, 3)} Z=${LuminaBlueprintFunctionLibrary.floatToString(inVec.z, 3)}';

String _rotatorToString(LuminaRotator inRot) => 'P=${LuminaBlueprintFunctionLibrary.floatToString(inRot.pitch, 3)} Y=${LuminaBlueprintFunctionLibrary.floatToString(inRot.yaw, 3)} R=${LuminaBlueprintFunctionLibrary.floatToString(inRot.roll, 3)}';

double _stringToFloat(String inString) => double.tryParse(inString.trim()) ?? 0.0;

int _stringToInt(String inString) => int.tryParse(inString.trim()) ?? (double.tryParse(inString.trim())?.truncate() ?? 0);

String _append(String a, String b) => a + b;

String _append3(String a, String b, String c) => a + b + c;

String _formatString(String format, [String arg0 = '', String arg1 = '', String arg2 = '', String arg3 = '']) {
  var out = format;
  final args = [arg0, arg1, arg2, arg3];
  for (var i = 0; i < args.length; i++) {
    if (args[i].isNotEmpty) out = out.replaceAll('{$i}', args[i]);
  }
  return out;
}

int _stringLength(String s) => s.length;

bool _stringEqual(String a, String b, [bool caseSensitive = true]) =>
    caseSensitive ? a == b : a.toLowerCase() == b.toLowerCase();

bool _stringContains(String searchIn, String substring, [bool useCase = true]) =>
    useCase ? searchIn.contains(substring) : searchIn.toLowerCase().contains(substring.toLowerCase());

String _stringReplace(String sourceString, String from, String to) => from.isEmpty ? sourceString : sourceString.replaceAll(from, to);

String _stringToUpper(String s) => s.toUpperCase();

String _stringToLower(String s) => s.toLowerCase();

String _stringSubstring(String s, int startIndex, int length) {
  final start = startIndex.clamp(0, s.length);
  final end = (start + (length < 0 ? 0 : length)).clamp(start, s.length);
  return s.substring(start, end);
}

List<Object?> _stringSplit(String s, [String separator = ' ']) =>
    s.isEmpty ? <Object?>[] : (separator.isEmpty ? s.split('') : s.split(separator)).cast<Object?>();

bool _stringIsEmpty(String s) => s.isEmpty;

String _stringTrim(String s) => s.trim();

String _selectString(String a, String b, bool pickA) => pickA ? a : b;

bool _selectBool(bool a, bool b, bool pickA) => pickA ? a : b;

Object? _selectObject(Object? a, Object? b, bool pickA) => pickA ? a : b;

// --- Array -----------------------------------------------------------

bool _sameItem(Object? a, Object? b) {
  if (identical(a, b) || a == b) return true;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!LuminaBlueprintFunctionLibrary.sameItem(a[i], b[i])) return false;
    }
    return true;
  }
  return false;
}

List<Object?> _list(Object? v) => v is List<Object?> ? v : (v is List ? List<Object?>.from(v) : <Object?>[]);

List<Object?> _arrayItems(Object? v) => v is List ? List<Object?>.from(v) : <Object?>[];

int _arrayLength(Object? targetArray) => _list(targetArray).length;

int _arrayLastIndex(Object? targetArray) => _list(targetArray).length - 1;

bool _arrayIsEmpty(Object? targetArray) => _list(targetArray).isEmpty;

final Set<String> _outOfRangeLogged = {};

Object? _arrayGet(Object? targetArray, int index) {
  final list = _list(targetArray);
  if (index >= 0 && index < list.length) return list[index];
  if (_outOfRangeLogged.add('$index/${list.length}')) {
    developer.log('Get (Array): index $index is out of range for an array of ${list.length}; null returned.',
        name: 'Blueprint', level: 900);
  }
  return null;
}

bool _arrayContains(Object? targetArray, Object? itemToFind) => LuminaBlueprintFunctionLibrary.arrayFind(targetArray, itemToFind) >= 0;

int _arrayFind(Object? targetArray, Object? itemToFind) {
  final list = _list(targetArray);
  for (var i = 0; i < list.length; i++) {
    if (LuminaBlueprintFunctionLibrary.sameItem(list[i], itemToFind)) return i;
  }
  return -1;
}

Object? _arrayFirst(Object? targetArray) => _list(targetArray).firstOrNull;

Object? _arrayLast(Object? targetArray) => _list(targetArray).lastOrNull;

List<Object?> _makeArray(List<Object?> items) => List<Object?>.from(items);

int _arrayAdd(Object? targetArray, Object? newItem) {
  if (targetArray is! List) return -1;
  (targetArray as List<Object?>).add(newItem);
  return targetArray.length - 1;
}

void _arrayRemoveIndex(Object? targetArray, int index) {
  if (targetArray is List && index >= 0 && index < targetArray.length) targetArray.removeAt(index);
}

void _arrayClear(Object? targetArray) {
  if (targetArray is List) targetArray.clear();
}

void _arraySet(Object? targetArray, int index, Object? item, [bool sizeToFit = false]) {
  if (targetArray is! List || index < 0) return;
  final list = targetArray as List<Object?>;
  if (index >= list.length) {
    if (!sizeToFit) return;
    while (list.length <= index) {
      list.add(null);
    }
  }
  list[index] = item;
}

List<Object?> _arrayFilterByClass(Object? targetArray, String cls) =>
    [for (final o in _list(targetArray)) if (LuminaBlueprintFunctionLibrary.isA(o, cls)) o];

void _arrayShuffle(Object? targetArray) {
  if (targetArray is List) targetArray.shuffle(LuminaBlueprintFunctionLibrary.random);
}

// --- Flow-control helpers shared by the VM and generated code -------------------------

({int index, List<int>? used}) _multiGateNext(List<int>? used, int count, bool isRandom, bool loop, int startIndex) {
  var taken = used ?? const <int>[];
  if (count <= 0) return (index: -1, used: taken);
  if (taken.length >= count) {
    if (!loop) return (index: -1, used: taken);
    taken = const <int>[];
  }
  final free = [for (var i = 0; i < count; i++) if (!taken.contains(i)) i];
  final int index;
  if (taken.isEmpty && startIndex >= 0 && startIndex < count) {
    index = startIndex;
  } else if (isRandom) {
    index = free[LuminaBlueprintFunctionLibrary.random.nextInt(free.length)];
  } else {
    index = free.first;
  }
  return (index: index, used: [...taken, index]);
}

void _whileLoopCapped(String owner, String node) => developer.log(
    'WhileLoop $node in $owner ran ${LuminaBlueprintNodeLibrary.whileLoopCap} iterations and was stopped.',
    name: 'Blueprint',
    level: 900);

// --- Structs: hit result -----------------------------------------------------------

Map<String, Object?> _makeHitResult(bool blockingHit, Vector3 location, Vector3 impactPoint, Vector3 impactNormal,
        double distance, [Object? hitActor, Object? hitComponent]) =>
    <String, Object?>{
      'blockingHit': blockingHit,
      'location': _list3(location),
      'impactPoint': _list3(impactPoint),
      'impactNormal': _list3(impactNormal),
      'distance': distance,
      'hitActor': hitActor,
      'hitComponent': hitComponent,
    };

({bool blockingHit, Vector3 location, Vector3 impactPoint, Vector3 impactNormal, double distance, Object? hitActor, Object? hitComponent})
    _breakHitResult(Object? hit) {
  final h = hit is Map ? hit : const {};
  return (
    blockingHit: h['blockingHit'] == true,
    location: _vec3(h['location']),
    impactPoint: _vec3(h['impactPoint']),
    impactNormal: _vec3(h['impactNormal']),
    distance: (h['distance'] as num?)?.toDouble() ?? 0.0,
    hitActor: h['hitActor'],
    hitComponent: h['hitComponent'],
  );
}
