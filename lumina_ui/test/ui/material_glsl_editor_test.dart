import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/material_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/glsl_editor_widget.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

class MockTestCompilerRunner implements FilamatCompilerRunner {
  bool shouldSucceed;
  Uint8List? returnBytes;

  MockTestCompilerRunner({
    this.shouldSucceed = true,
    this.returnBytes,
  });

  @override
  Future<MaterialCompileResult> compile({
    required String name,
    required String source,
    String? includeDirectory,
  }) async {
    if (!shouldSucceed) return const MaterialCompileResult(bytes: null);
    return MaterialCompileResult(bytes: returnBytes ?? Uint8List.fromList([0x46, 0x49, 0x4C, 0x41, 0x01, 0x02, 0x03]));
  }
}

void main() {
  testWidgets('MaterialGlslEditorWidget renders line numbers', (tester) async {
    final vm = MaterialEditorViewModel(
      assetPath: 'test.lmas',
      compilerRunner: MockTestCompilerRunner(),
    );
    final controller = TextEditingController(text: 'line1\nline2\nline3');
    final focusNode = FocusNode();

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: MaterialGlslEditorWidget(
            viewModel: vm,
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      ),
    );

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('MaterialSubEditor renders toolbar badges and action buttons', (tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: MaterialSubEditor(
            assetName: 'M_Gold',
          ),
        ),
      ),
    );

    expect(find.text('FILAMAT'), findsOneWidget);
    expect(find.text('M_Gold'), findsOneWidget);
    expect(find.text('Compile'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('GLSL Source (.mat)'), findsOneWidget);
  });

  testWidgets('MaterialSubEditor with custom ViewModel compiles and hot-applies', (tester) async {
    final runner = MockTestCompilerRunner(
      shouldSucceed: true,
      returnBytes: Uint8List.fromList([1, 2, 3, 4]),
    );
    final asset = LuminaAsset(
      assetId: 'M_Wood',
      name: 'M_Wood',
      type: AssetType.filamat,
      rawMatSource: '''material {
    name : "M_Wood",
    shadingModel : lit,
    blending : opaque,
}
fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = vec4(0.5, 0.3, 0.1, 1.0);
    }
}''',
    );
    final vm = MaterialEditorViewModel(
      assetPath: 'contents/materials/M_Wood.lmas',
      initialAsset: asset,
      compilerRunner: runner,
    );

    Uint8List? applied;
    vm.onHotApply = (b) => applied = b;

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: MaterialSubEditor(
            assetName: 'M_Wood',
            assetPath: 'contents/materials/M_Wood.lmas',
            viewModel: vm,
          ),
        ),
      ),
    );

    // Tap compile
    await tester.tap(find.text('Compile'));
    await tester.pump();

    expect(applied, isNotNull);
    expect(applied!.length, equals(4));
    expect(find.textContaining('Compile OK'), findsWidgets);
  });

  testWidgets("MaterialSubEditor lists the compiler's errors in the compiler log", (tester) async {
    final asset = LuminaAsset(
      assetId: 'M_Error',
      name: 'M_Error',
      type: AssetType.filamat,
      rawMatSource: '''material {
    name : "M_Error"
}
fragment {
    void material(inout MaterialInputs material) {
        material.baseColor = vec4(1.0);
    }
}''',
    );
    final vm = MaterialEditorViewModel(
      assetPath: 'contents/materials/M_Error.lmas',
      initialAsset: asset,
    );

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: MaterialSubEditor(
            assetName: 'M_Error',
            assetPath: 'contents/materials/M_Error.lmas',
            viewModel: vm,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Compile'));
    await tester.pump();

    expect(find.textContaining('prepareMaterial() is not called'), findsWidgets);
    expect(find.text('ERROR'), findsWidgets);
  });
}
