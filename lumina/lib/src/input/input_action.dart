import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';

/// Value type carried by an input action.
enum InputValueType { digitalBool, axis1D, axis2D, axis3D }

/// Trigger state for input actions and bindings.
enum TriggerState { started, ongoing, canceled, triggered, completed }

/// Typed input action value supporting implicit type conversions.
class LuminaInputActionValue {
  final InputValueType type;
  final double _x;
  final double _y;
  final double _z;

  const LuminaInputActionValue.bool(bool v)
      : type = InputValueType.digitalBool,
        _x = v ? 1.0 : 0.0,
        _y = 0.0,
        _z = 0.0;

  const LuminaInputActionValue.axis1D(double v)
      : type = InputValueType.axis1D,
        _x = v,
        _y = 0.0,
        _z = 0.0;

  LuminaInputActionValue.axis2D(Vector2 v)
      : type = InputValueType.axis2D,
        _x = v.x,
        _y = v.y,
        _z = 0.0;

  LuminaInputActionValue.axis3D(Vector3 v)
      : type = InputValueType.axis3D,
        _x = v.x,
        _y = v.y,
        _z = v.z;

  const LuminaInputActionValue.raw(this.type, this._x, this._y, this._z);

  bool get asBool => _x != 0.0 || _y != 0.0 || _z != 0.0;
  double get asAxis1D => _x;
  Vector2 get asAxis2D => Vector2(_x, _y);
  Vector3 get asAxis3D => Vector3(_x, _y, _z);
  double get magnitude => math.sqrt(_x * _x + _y * _y + _z * _z);

  @override
  String toString() => 'LuminaInputActionValue($type, x: $_x, y: $_y, z: $_z)';
}

/// Represents an abstract Input Action.
class LuminaInputAction {
  final String name;
  final InputValueType valueType;

  const LuminaInputAction(this.name, {this.valueType = InputValueType.digitalBool});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LuminaInputAction && other.name == name && other.valueType == valueType);

  @override
  int get hashCode => Object.hash(name, valueType);

  @override
  String toString() => 'LuminaInputAction($name, $valueType)';
}
