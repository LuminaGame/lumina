import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/main_editor/services/snap_service.dart';

void main() {
  test('snapValue quantizes correctly', () {
    expect(SnapService.snapValue(42.4, 10.0), 40.0);
    expect(SnapService.snapValue(45.0, 10.0), 50.0);
    expect(SnapService.snapValue(-7.5, 10.0), -10.0);
    expect(SnapService.snapValue(123.4, 0.0), 123.4);
    expect(SnapService.snapValue(123.4, -1.0), 123.4);
  });
  
  test('snapVector quantizes all components', () {
    final v = SnapService.snapVector([42.4, -7.5, 45.0], 10.0);
    expect(v, [40.0, -10.0, 50.0]);
  });
}
