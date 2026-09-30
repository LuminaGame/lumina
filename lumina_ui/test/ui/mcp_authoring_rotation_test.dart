import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/play_testing_tools.dart';

/// The play-testing tools report an actor's rotation in the Details panel's
/// authoring degrees: the exact inverse of `LuminaAxes.rotation`.
void main() {
  test('mcpAuthoringRotation inverts LuminaAxes.rotation', () {
    for (final authored in [
      [0.0, 0.0, 0.0],
      [0.0, 0.0, 90.0],
      [0.0, 0.0, -135.0],
      [25.0, 0.0, 0.0],
      [-40.0, 0.0, 60.0],
      [15.0, 10.0, 170.0],
      [0.0, -30.0, 45.0],
    ]) {
      final back = mcpAuthoringRotation(LuminaAxes.rotation(authored));
      for (var i = 0; i < 3; i++) {
        expect(back[i], closeTo(authored[i], 1e-3), reason: '$authored → $back (axis $i)');
      }
    }
  });
}
