import 'package:lumina/lumina.dart' show LuminaUnits;

class SnapService {
  static const List<double> translateSteps = [1.0, 5.0, 10.0, 50.0, 100.0, 500.0, 1000.0, 5000.0, 10000.0];
  static const List<double> rotateSteps = [2.8125, 5.625, 11.25, 15.0, 30.0, 45.0, 90.0, 120.0];
  static const List<double> scaleSteps = [0.03125, 0.0625, 0.125, 0.25, 0.5, 1.0, 5.0, 10.0];
  static const List<double> gridSteps = [1.0, 5.0, 10.0, 50.0, 100.0, 500.0, 1000.0, 5000.0, 10000.0];
  
  /// A world length for menus: world units are centimetres, so
  /// `10` reads `10 cm` and `500` reads `5 m`.
  static String formatLength(double cm) {
    String trim(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    const m = LuminaUnits.unitsPerMetre;
    return cm.abs() >= m ? '${trim(cm / m)} m' : '${trim(cm)} cm';
  }

  static double snapValue(double value, double step) {
    if (step <= 0.0) return value;
    return (value / step).roundToDouble() * step;
  }
  
  static List<double> snapVector(List<double> vector, double step) {
    if (step <= 0.0) return vector;
    return [
      snapValue(vector[0], step),
      snapValue(vector[1], step),
      snapValue(vector[2], step),
    ];
  }
  
  static double snapAngle(double angle, double step) {
    if (step <= 0.0) return angle;
    return (angle / step).roundToDouble() * step;
  }
}
