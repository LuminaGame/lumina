import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/property_editors/asset_ref_field.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

Widget _buildApp(Widget child) {
  return ShadcnApp(
    theme: luminaEditorTheme(),
    home: child,
  );
}

void main() {
  group('AssetRefField', () {
    late Directory tempDir;
    late EditorViewModel viewModel;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('asset_ref_test');
      final contentsDir = Directory('${tempDir.path}/contents')..createSync();
      File('${contentsDir.path}/test_texture.filamat').writeAsStringSync('dummy');

      viewModel = EditorViewModel(
        projectLocation: tempDir.path,
        enableTimers: false,
        autoInitAssets: false,
      );
    });

    tearDown(() {
      viewModel.dispose();
      tempDir.deleteSync(recursive: true);
    });

    testWidgets('Drag and drop updates value correctly', (tester) async {
      Map<String, dynamic>? committedValue;

      await tester.pumpWidget(_buildApp(
        AssetRefField(
          value: null,
          slotName: 'Albedo',
          assetType: 'LuminaMaterial',
          viewModel: viewModel,
          onCommit: (val) {
            committedValue = val;
          },
        ),
      ));

      expect(find.text('None'), findsOneWidget);
    });
    
    testWidgets('Displays current value and reset button', (tester) async {
      await tester.pumpWidget(_buildApp(
        AssetRefField(
          value: const {'asset_path': 'contents/materials/M_Brick.filamat'},
          slotName: 'Albedo',
          assetType: 'LuminaMaterial',
          viewModel: viewModel,
          onCommit: (_) {},
        ),
      ));

      expect(find.text('M_Brick.filamat'), findsOneWidget);
      expect(find.byIcon(LucideIcons.x), findsOneWidget);
    });
  });
}
