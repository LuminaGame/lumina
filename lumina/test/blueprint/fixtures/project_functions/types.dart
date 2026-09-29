// Exposed-functions fixture: every pin type, defaults, a static function and an
// optional positional parameter.
import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';

/// Joins every kind of value a Blueprint pin carries.
@BlueprintPure(category: 'Fixture|Types', keywords: ['all'], tooltip: 'Every pin type at once.')
String describeTypes(
  int count,
  String label,
  Vector2 size,
  Vector3 at,
  LuminaRotator facing,
  LuminaPawn pawn, {
  double scale = 1.5,
  LuminaRotator turn = const LuminaRotator(0.0, 0.0, 90.0),
  LuminaActor? other,
}) =>
    '$label x$count ${size.x}x${size.y} at ${at.z} facing ${facing.yaw} scale $scale turn ${turn.yaw} '
    '${pawn.runtimeType} ${other == null ? 'alone' : 'with company'}';

final Expando<int> _calls = Expando<int>('calls');

/// Counts the actor's calls, [times] at a time, and returns the total.
@BlueprintCallable(category: 'Fixture|Types')
int countCalls(LuminaActor self, [int times = 1]) => _calls[self] = (_calls[self] ?? 0) + times;

/// Static helpers.
abstract final class FixtureMath {
  /// Twice [value].
  @BlueprintPure(category: 'Fixture|Math')
  static int twice(int value) => value * 2;
}
