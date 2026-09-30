part of '../blueprint_function_library.dart';

// --- Gameplay / Player -----------------------------------------------------

Object? _getPlayerController(LuminaActor self, [int playerIndex = 0]) {
  if (self is LuminaPawn && self.controller != null) {
    return self.controller;
  }
  if (self.world != null) {
    final pc = LuminaGameplayStatics.getPlayerController(
      self.world!,
      playerIndex: playerIndex,
    );
    if (pc != null) return pc;
  }
  return null;
}

Object? _getPlayerPawn(LuminaActor self, [int playerIndex = 0]) {
  if (self is LuminaPawn) return self;
  if (self.world != null) {
    return LuminaGameplayStatics.getPlayerPawn(
      self.world!,
      playerIndex: playerIndex,
    );
  }
  return null;
}

Object? _getPlayerCharacter(LuminaActor self, [int playerIndex = 0]) {
  if (self is LuminaCharacter) return self;
  final pawn = LuminaBlueprintFunctionLibrary.getPlayerPawn(self, playerIndex);
  return pawn is LuminaCharacter ? pawn : null;
}

/// The controller a Set Show Mouse Cursor / Set Input Mode node acts on: its
/// Target, or — when Target is unwired — player 0's controller (the
/// validator warns about the unwired pin).
LuminaPlayerController? _controllerTarget(LuminaActor self, Object? target) {
  final resolved = target ?? _getPlayerController(self);
  return resolved is LuminaPlayerController ? resolved : null;
}

void _setShowMouseCursor(
  LuminaActor self,
  Object? target, [
  bool showMouseCursor = true,
]) {
  _controllerTarget(self, target)?.setShowMouseCursor(showMouseCursor);
}

void _setInputModeGameAndUI(
  LuminaActor self,
  Object? target, [
  Object? inWidgetToFocus,
  bool lockMouseToViewport = false,
]) {
  _controllerTarget(self, target)?.setInputModeGameAndUI(
    widgetToFocus: inWidgetToFocus,
    lockMouseToViewport: lockMouseToViewport,
  );
}

void _setInputModeGameOnly(LuminaActor self, Object? target) {
  _controllerTarget(self, target)?.setInputModeGameOnly();
}

void _setInputModeUIOnly(
  LuminaActor self,
  Object? target, [
  Object? inWidgetToFocus,
  bool lockMouseToViewport = false,
]) {
  _controllerTarget(self, target)?.setInputModeUIOnly(
    widgetToFocus: inWidgetToFocus,
    lockMouseToViewport: lockMouseToViewport,
  );
}

// --- Structs ---------------------------------------------------------------

Vector2 _makeVector2D(double x, double y) => Vector2(x, y);

({double x, double y}) _breakVector2D(Vector2 inVec) =>
    (x: inVec.x, y: inVec.y);

Vector3 _makeVector(double x, double y, double z) => Vector3(x, y, z);

({double x, double y, double z}) _breakVector(Vector3 inVec) =>
    (x: inVec.x, y: inVec.y, z: inVec.z);

LuminaRotator _makeRotator(double x, double y, double z) =>
    LuminaRotator(x, y, z);

({double x, double y, double z}) _breakRotator(LuminaRotator inRot) =>
    (x: inRot.x, y: inRot.y, z: inRot.z);

Vector3 _getForwardVector(LuminaRotator inRot) {
  final e = LuminaBlueprintFunctionLibrary.toControlRotation(inRot);
  return LuminaBlueprintFunctionLibrary.toAuthoring(
    luminaPawnEulerToQuaternion(
      e.x,
      e.y,
      e.z,
    ).rotateVector(Vector3(0, 0, -1)),
  );
}

Vector3 _getRightVector(LuminaRotator inRot) {
  final e = LuminaBlueprintFunctionLibrary.toControlRotation(inRot);
  return LuminaBlueprintFunctionLibrary.toAuthoring(
    luminaPawnEulerToQuaternion(e.x, e.y, e.z).rotateVector(Vector3(1, 0, 0)),
  );
}

double _calculateDirection(
  Vector3 velocity,
  LuminaRotator baseRotation,
) {
  final v = LuminaBlueprintFunctionLibrary.toRuntime(velocity);
  if (v.x * v.x + v.z * v.z < 1e-12) return 0.0;
  final e = LuminaBlueprintFunctionLibrary.toControlRotation(baseRotation);
  final f = luminaPawnEulerToQuaternion(
    e.x,
    e.y,
    e.z,
  ).rotateVector(Vector3(0, 0, -1));
  var fx = f.x;
  var fz = f.z;
  final length = math.sqrt(fx * fx + fz * fz);
  if (length < 1e-9) {
    fx = 0.0;
    fz = -1.0;
  } else {
    fx /= length;
    fz /= length;
  }
  final ahead = v.x * fx + v.z * fz;
  final aside = v.x * -fz + v.z * fx;
  return math.atan2(aside, ahead) * 180.0 / math.pi;
}

// --- Math ------------------------------------------------------------------

double _vectorLength(Vector3 inVec) => inVec.length;

double _vectorLengthXY(Vector3 inVec) =>
    math.sqrt(inVec.x * inVec.x + inVec.y * inVec.y);

Vector3 _vectorScale(Vector3 a, double b) => a * b;

Vector3 _vectorAdd(Vector3 a, Vector3 b) => a + b;

double _floatAdd(double a, double b) => a + b;

double _floatSubtract(double a, double b) => a - b;

double _floatMultiply(double a, double b) => a * b;

double _floatDivide(double a, double b) => b == 0.0 ? 0.0 : a / b;

double _floatClamp(double value, double min, double max) =>
    value < min ? min : (value > max ? max : value);

bool _floatGreater(double a, double b) => a > b;

bool _floatLess(double a, double b) => a < b;

bool _floatEqual(double a, double b) => a == b;

bool _boolAnd(bool a, bool b) => a && b;

bool _boolOr(bool a, bool b) => a || b;

bool _boolNot(bool a) => !a;

// --- Math | Float ----------------------------------------------

double _floatAbs(double a) => a.abs();

double _floatMin(double a, double b) => math.min(a, b);

double _floatMax(double a, double b) => math.max(a, b);

double _floatLerp(double a, double b, double alpha) => a + (b - a) * alpha;

double _floatInterpTo(double current, double target, double deltaTime, double interpSpeed) {
  if (interpSpeed <= 0.0) return target;
  final dist = target - current;
  if (dist * dist < 1e-8) return target;
  final step = dist * (deltaTime * interpSpeed).clamp(0.0, 1.0);
  return current + step;
}

double _floatSqrt(double a) => a <= 0.0 ? 0.0 : math.sqrt(a);

double _floatPower(double base, double exp) => math.pow(base, exp).toDouble();

double _floatModulo(double a, double b) => b == 0.0 ? 0.0 : a - b * (a / b).truncateToDouble();

double _floatSign(double a) => a > 0.0 ? 1.0 : (a < 0.0 ? -1.0 : 0.0);

double _floatMapRangeClamped(double value, double inRangeA, double inRangeB, double outRangeA, double outRangeB) {
  final span = inRangeB - inRangeA;
  final t = span == 0.0 ? 0.0 : ((value - inRangeA) / span).clamp(0.0, 1.0);
  return outRangeA + (outRangeB - outRangeA) * t;
}

bool _floatNearlyEqual(double a, double b, [double errorTolerance = 1e-6]) => (a - b).abs() <= errorTolerance;

double _floatSin(double a) => math.sin(a * math.pi / 180.0);

double _floatCos(double a) => math.cos(a * math.pi / 180.0);

double _floatTan(double a) => math.tan(a * math.pi / 180.0);

double _floatAsin(double a) => math.asin(a.clamp(-1.0, 1.0)) * 180.0 / math.pi;

double _floatAcos(double a) => math.acos(a.clamp(-1.0, 1.0)) * 180.0 / math.pi;

double _floatAtan(double a) => math.atan(a) * 180.0 / math.pi;

double _floatAtan2(double y, double x) => math.atan2(y, x) * 180.0 / math.pi;

double _degreesToRadians(double a) => a * math.pi / 180.0;

double _radiansToDegrees(double a) => a * 180.0 / math.pi;

bool _floatGreaterEqual(double a, double b) => a >= b;

bool _floatLessEqual(double a, double b) => a <= b;

bool _floatNotEqual(double a, double b) => a != b;

double _randomFloatInRange(double min, double max) => min + LuminaBlueprintFunctionLibrary.random.nextDouble() * (max - min);

bool _randomBoolWithWeight(double weight) => LuminaBlueprintFunctionLibrary.random.nextDouble() < weight;

double _selectFloat(double a, double b, bool pickA) => pickA ? a : b;

int _round(double a) => a.isFinite ? a.round() : 0;

int _truncate(double a) => a.isFinite ? a.truncate() : 0;

int _ceil(double a) => a.isFinite ? a.ceil() : 0;

int _floor(double a) => a.isFinite ? a.floor() : 0;

double _intToFloat(int a) => a.toDouble();

// --- Math | Int ----------------------------------------------------------------

int _intAdd(int a, int b) => a + b;

int _intSubtract(int a, int b) => a - b;

int _intMultiply(int a, int b) => a * b;

int _intDivide(int a, int b) => b == 0 ? 0 : a ~/ b;

int _intModulo(int a, int b) => b == 0 ? 0 : a.remainder(b);

int _intClamp(int value, int min, int max) => value < min ? min : (value > max ? max : value);

int _intAbs(int a) => a.abs();

int _intMin(int a, int b) => math.min(a, b);

int _intMax(int a, int b) => math.max(a, b);

bool _intGreater(int a, int b) => a > b;

bool _intLess(int a, int b) => a < b;

bool _intEqual(int a, int b) => a == b;

bool _intNotEqual(int a, int b) => a != b;

bool _intGreaterEqual(int a, int b) => a >= b;

bool _intLessEqual(int a, int b) => a <= b;

int _randomIntegerInRange(int min, int max) => max < min ? min : min + LuminaBlueprintFunctionLibrary.random.nextInt(max - min + 1);

int _intIncrement(int a) => a + 1;

int _selectInt(int a, int b, bool pickA) => pickA ? a : b;

// --- Math | Vector ---------------------------------------------------------------

Vector3 _vectorNormalize(Vector3 a) => a.length2 < 1e-16 ? Vector3.zero() : a.normalized();

double _vectorDot(Vector3 a, Vector3 b) => a.dot(b);

Vector3 _vectorCross(Vector3 a, Vector3 b) => a.cross(b);

double _vectorDistance(Vector3 a, Vector3 b) => (a - b).length;

double _vectorDistance2D(Vector3 a, Vector3 b) {
  final dx = a.x - b.x, dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
}

Vector3 _vectorLerp(Vector3 a, Vector3 b, double alpha) => a + (b - a) * alpha;

Vector3 _vectorInterpTo(Vector3 current, Vector3 target, double deltaTime, double interpSpeed) {
  if (interpSpeed <= 0.0) return target.clone();
  final dist = target - current;
  if (dist.length2 < 1e-8) return target.clone();
  return current + dist * (deltaTime * interpSpeed).clamp(0.0, 1.0);
}

Vector3 _vectorSubtract(Vector3 a, Vector3 b) => a - b;

Vector3 _vectorDivideFloat(Vector3 a, double b) => b == 0.0 ? Vector3.zero() : a / b;

Vector3 _vectorNegate(Vector3 a) => -a;

bool _vectorEqual(Vector3 a, Vector3 b, [double errorTolerance = 1e-4]) =>
    (a.x - b.x).abs() <= errorTolerance && (a.y - b.y).abs() <= errorTolerance && (a.z - b.z).abs() <= errorTolerance;

Vector3 _vectorProjectOnTo(Vector3 a, Vector3 b) {
  final l2 = b.length2;
  return l2 < 1e-16 ? Vector3.zero() : b * (a.dot(b) / l2);
}

Vector3 _rotateVectorAroundAxis(Vector3 inVect, double angleDeg, Vector3 axis) {
  final k = LuminaBlueprintFunctionLibrary.vectorNormalize(axis);
  if (k.length2 == 0.0) return inVect.clone();
  final r = angleDeg * math.pi / 180.0;
  final c = math.cos(r), sn = math.sin(r);
  return inVect * c + k.cross(inVect) * sn + k * (k.dot(inVect) * (1.0 - c));
}

Vector3 _getUpVector(LuminaRotator inRot) {
  final e = LuminaBlueprintFunctionLibrary.toControlRotation(inRot);
  return LuminaBlueprintFunctionLibrary.toAuthoring(luminaPawnEulerToQuaternion(e.x, e.y, e.z).rotateVector(Vector3(0, 1, 0)));
}

Vector3 _randomUnitVector() {
  final z = LuminaBlueprintFunctionLibrary.random.nextDouble() * 2.0 - 1.0;
  final t = LuminaBlueprintFunctionLibrary.random.nextDouble() * 2.0 * math.pi;
  final r = math.sqrt(1.0 - z * z);
  return Vector3(r * math.cos(t), r * math.sin(t), z);
}

bool _vectorIsZero(Vector3 a) => a.x == 0.0 && a.y == 0.0 && a.z == 0.0;

Vector3 _selectVector(Vector3 a, Vector3 b, bool pickA) => pickA ? a : b;

// --- Math | Rotator --------------------------------------------------------------

double _normalizeAxis(double angle) {
  var a = angle % 360.0;
  if (a > 180.0) a -= 360.0;
  if (a <= -180.0) a += 360.0;
  return a;
}

double _clampAngle(double angleDegrees, double minAngle, double maxAngle) =>
    LuminaBlueprintFunctionLibrary.normalizeAxis(angleDegrees).clamp(minAngle, maxAngle).toDouble();

LuminaRotator _normalized(LuminaRotator r) => LuminaRotator(LuminaBlueprintFunctionLibrary.normalizeAxis(r.x), LuminaBlueprintFunctionLibrary.normalizeAxis(r.y), LuminaBlueprintFunctionLibrary.normalizeAxis(r.z));

LuminaRotator _combineRotators(LuminaRotator a, LuminaRotator b) => _normalized(_rotator((_quat(b) * _quat(a))..normalize()));

LuminaRotator _deltaRotator(LuminaRotator a, LuminaRotator b) => LuminaRotator(LuminaBlueprintFunctionLibrary.normalizeAxis(a.x - b.x), LuminaBlueprintFunctionLibrary.normalizeAxis(a.y - b.y), LuminaBlueprintFunctionLibrary.normalizeAxis(a.z - b.z));

LuminaRotator _rotatorLerp(LuminaRotator a, LuminaRotator b, double alpha) {
  final d = LuminaBlueprintFunctionLibrary.deltaRotator(b, a);
  return _normalized(LuminaRotator(a.x + d.x * alpha, a.y + d.y * alpha, a.z + d.z * alpha));
}

LuminaRotator _rotatorInterpTo(LuminaRotator current, LuminaRotator target, double deltaTime, double interpSpeed) {
  if (interpSpeed <= 0.0) return target;
  final d = LuminaBlueprintFunctionLibrary.deltaRotator(target, current);
  if (d.x.abs() < 1e-6 && d.y.abs() < 1e-6 && d.z.abs() < 1e-6) return target;
  final t = (deltaTime * interpSpeed).clamp(0.0, 1.0);
  return _normalized(LuminaRotator(current.x + d.x * t, current.y + d.y * t, current.z + d.z * t));
}

LuminaRotator _findLookAtRotation(Vector3 start, Vector3 target) => LuminaBlueprintFunctionLibrary.makeRotFromX(target - start);

LuminaRotator _makeRotFromX(Vector3 x) {
  if (x.length2 < 1e-16) return const LuminaRotator.zero();
  final d = x.normalized();
  final h = math.sqrt(d.x * d.x + d.y * d.y);
  const r2d = 180.0 / math.pi;
  // Straight up or down: any yaw faces it; keep 0.
  if (h < 1e-12) return LuminaRotator(d.z >= 0 ? 90.0 : -90.0, 0.0, 0.0);
  return LuminaRotator(math.atan2(d.z, h) * r2d, 0.0, math.atan2(d.x, d.y) * r2d);
}

bool _rotatorEqual(LuminaRotator a, LuminaRotator b, [double errorTolerance = 1e-4]) {
  final d = LuminaBlueprintFunctionLibrary.deltaRotator(a, b);
  return d.x.abs() <= errorTolerance && d.y.abs() <= errorTolerance && d.z.abs() <= errorTolerance;
}

Vector3 _rotatorToVector(LuminaRotator inRot) => LuminaBlueprintFunctionLibrary.getForwardVector(inRot);

// --- Math | Transform / Color -----------------------------------------------------

List<double> _list3(Vector3 v) => [v.x, v.y, v.z];

Vector3 _vec3(Object? v, [Vector3? fallback]) {
  if (v is Vector3) return v.clone();
  if (v is List) {
    final n = v.whereType<num>().toList();
    if (n.length >= 3) return Vector3(n[0].toDouble(), n[1].toDouble(), n[2].toDouble());
  }
  return fallback ?? Vector3.zero();
}

LuminaRotator _rot3(Object? v) {
  if (v is LuminaRotator) return v;
  if (v is List) return LuminaRotator.fromList(v.whereType<num>().toList());
  return const LuminaRotator.zero();
}

Map<String, Object?> _makeTransform(Vector3 location, LuminaRotator rotation, Vector3 scale) => <String, Object?>{
      'location': _list3(location),
      'rotation': rotation.toList(),
      'scale': _list3(scale),
    };

({Vector3 location, LuminaRotator rotation, Vector3 scale}) _breakTransform(Object? inTransform) {
  final t = inTransform is Map ? inTransform : const {};
  return (location: _vec3(t['location']), rotation: _rot3(t['rotation']), scale: _vec3(t['scale'], Vector3(1, 1, 1)));
}

/// Rotates an authoring-space vector by an authoring rotator.
Vector3 _rotate(LuminaRotator r, Vector3 v) => LuminaBlueprintFunctionLibrary.toAuthoring(_quat(r).rotateVector(LuminaBlueprintFunctionLibrary.toRuntime(v)));

Vector3 _unrotate(LuminaRotator r, Vector3 v) => LuminaBlueprintFunctionLibrary.toAuthoring(_quat(r).inverted().rotateVector(LuminaBlueprintFunctionLibrary.toRuntime(v)));

Vector3 _transformLocation(Object? t, Vector3 location) {
  final x = LuminaBlueprintFunctionLibrary.breakTransform(t);
  final scaled = Vector3(location.x * x.scale.x, location.y * x.scale.y, location.z * x.scale.z);
  return _rotate(x.rotation, scaled) + x.location;
}

Vector3 _inverseTransformLocation(Object? t, Vector3 location) {
  final x = LuminaBlueprintFunctionLibrary.breakTransform(t);
  final local = _unrotate(x.rotation, location - x.location);
  double div(double v, double s) => s == 0.0 ? 0.0 : v / s;
  return Vector3(div(local.x, x.scale.x), div(local.y, x.scale.y), div(local.z, x.scale.z));
}

Vector3 _transformDirection(Object? t, Vector3 direction) => _rotate(LuminaBlueprintFunctionLibrary.breakTransform(t).rotation, direction);

Map<String, Object?> _composeTransforms(Object? a, Object? b) {
  final x = LuminaBlueprintFunctionLibrary.breakTransform(a), y = LuminaBlueprintFunctionLibrary.breakTransform(b);
  return LuminaBlueprintFunctionLibrary.makeTransform(
    LuminaBlueprintFunctionLibrary.transformLocation(b, x.location),
    LuminaBlueprintFunctionLibrary.combineRotators(x.rotation, y.rotation),
    Vector3(x.scale.x * y.scale.x, x.scale.y * y.scale.y, x.scale.z * y.scale.z),
  );
}

List<double> _makeColor(double r, double g, double b, [double a = 1.0]) => [r, g, b, a];

({double r, double g, double b, double a}) _breakColor(List<double> inColor) => (
      r: inColor.isNotEmpty ? inColor[0] : 0.0,
      g: inColor.length > 1 ? inColor[1] : 0.0,
      b: inColor.length > 2 ? inColor[2] : 0.0,
      a: inColor.length > 3 ? inColor[3] : 1.0,
    );

List<double> _colorLerp(List<double> a, List<double> b, double alpha) =>
    [for (var i = 0; i < 4; i++) _at(a, i) + (_at(b, i) - _at(a, i)) * alpha];

double _at(List<double> c, int i) => i < c.length ? c[i] : (i == 3 ? 1.0 : 0.0);

List<double> _hexToColor(String hex) {
  final h = hex.trim().replaceFirst('#', '');
  if (h.length != 6 && h.length != 8) return [1.0, 1.0, 1.0, 1.0];
  final v = int.tryParse(h, radix: 16);
  if (v == null) return [1.0, 1.0, 1.0, 1.0];
  if (h.length == 6) return [((v >> 16) & 0xFF) / 255.0, ((v >> 8) & 0xFF) / 255.0, (v & 0xFF) / 255.0, 1.0];
  return [((v >> 24) & 0xFF) / 255.0, ((v >> 16) & 0xFF) / 255.0, ((v >> 8) & 0xFF) / 255.0, (v & 0xFF) / 255.0];
}

String _colorToHex(List<double> inColor) {
  String h(double v) => (v.clamp(0.0, 1.0) * 255.0).round().toRadixString(16).padLeft(2, '0').toUpperCase();
  return '#${h(_at(inColor, 0))}${h(_at(inColor, 1))}${h(_at(inColor, 2))}${h(_at(inColor, 3))}';
}
