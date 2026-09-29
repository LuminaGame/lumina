import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_modal.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sub-Editors Modular Tests', () {
    testWidgets('MaterialSubEditor renders interactive GLSL code editor and status badge', (WidgetTester tester) async {
      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: MaterialSubEditor(
              assetName: 'M_Test_Material.lmas',
            ),
          ),
        ),
      );
      // The editor compiles the material on open, which mounts a live Filament
      // preview — a tree with a running 3D preview never settles, so pump
      // frames instead of waiting for quiet.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(find.text('M_Test_Material.lmas'), findsOneWidget);
      // The badge reports the compile now, not just the Dart-side syntax check.
      expect(find.textContaining('Compile OK'), findsOneWidget);
      expect(find.textContaining('shadingModel : lit'), findsOneWidget);
    });

    testWidgets('SubEditorWorkspaceWidget dispatches correct sub-editor types', (WidgetTester tester) async {
      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: SubEditorWorkspaceWidget(
              assetType: 'Blueprint',
              assetName: 'BP_HeroPlayer.lmas',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BLUEPRINT ACTOR'), findsOneWidget);
      expect(find.text('BP_HeroPlayer.lmas'), findsOneWidget);
    });
  });
}
