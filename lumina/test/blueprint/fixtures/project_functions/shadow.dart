// Exposed-functions fixture: a project class named like vector_math's Vector3,
// which the scanner must not take for a Blueprint vector.
import 'package:lumina/lumina_runtime.dart';

/// Not vector_math's Vector3.
class Vector3 {
  final double x;
  const Vector3(this.x);
}

/// Reads the shadowing class.
@BlueprintPure()
double shadowLength(Vector3 v) => v.x;
