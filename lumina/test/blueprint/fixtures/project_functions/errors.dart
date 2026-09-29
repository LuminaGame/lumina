// Exposed-functions fixture: functions the scanner must refuse, each with a
// diagnostic naming the function and the parameter.
import 'package:lumina/lumina_runtime.dart';

/// Async: a node runs to completion.
@BlueprintCallable()
Future<void> loadLater(LuminaActor self) async {}

/// `Object` is no pin type.
@BlueprintPure()
String describeObject(Object value) => '$value';

/// Generic.
@BlueprintPure()
T pick<T>(T value) => value;

/// Instance methods need the editor to construct the class.
class Turret {
  var shots = 0;

  @BlueprintCallable()
  void fire() => shots++;
}
