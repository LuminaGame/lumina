import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Sub-editor previews open with the camera above the scene looking down,
/// the same pose "Reset camera" gives — not from under the floor.
void main() {
  testWidgets('a sub-editor viewport starts above its target, like Reset camera', (tester) async {
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: const Scaffold(child: SubEditor3DViewport(title: 'Camera Test')),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    final state = tester.state(find.byType(SubEditor3DViewport)) as dynamic;
    expect(state.cameraPitchForTest as double, greaterThan(0), reason: 'positive elevation puts the eye above the target');
    expect(state.cameraPitchForTest as double, 25.0, reason: 'the Reset camera pose');
  });
}
