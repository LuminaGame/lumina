import 'dart:math' as math;

import 'package:flutter_filament/flutter_filament.dart' show FilamentWidget;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Regression coverage: the Material Editor preview frames its
/// primitive for the pane it is in, narrow or wide.
void main() {
  /// Whether a bounding sphere of [radius] at the origin fits the view of a
  /// camera [distance] away with a 45° vertical field of view.
  bool fits(double radius, double distance, double aspect) {
    const vHalf = 22.5 * math.pi / 180;
    final hHalf = math.atan(math.tan(vHalf) * aspect);
    return distance * math.sin(math.min(vHalf, hHalf)) >= radius;
  }

  testWidgets('the preview sphere fits a narrow pane, and a wide one', (tester) async {
    const source = '''material {
    name : "M_Frame",
    shadingModel : lit
}
fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = vec4(0.8, 0.2, 0.1, 1.0);
    }
}''';
    final vm = MaterialEditorViewModel(
      assetPath: 'contents/materials/M_Frame.lmas',
      initialAsset: LuminaAsset(assetId: 'M_Frame', name: 'M_Frame', type: AssetType.filamat, rawMatSource: source),
    );
    expect(await tester.runAsync(vm.compile), isTrue);

    final size = ValueNotifier(const Size(270, 900));
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: Align(
          alignment: Alignment.topLeft,
          child: ValueListenableBuilder<Size>(
            valueListenable: size,
            builder: (context, s, _) => SizedBox(
              width: s.width,
              height: s.height,
              child: SubEditor3DViewport(
                title: 'Material 3D Preview Viewport',
                initialShape: PreviewShape.sphere,
                previewMaterialBytes: vm.compiledBytes,
                previewMaterialParams: vm.parameters,
              ),
            ),
          ),
        ),
      ),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(find.byType(FilamentWidget), findsOneWidget);
    dynamic state() => tester.state(find.byType(SubEditor3DViewport));

    final narrowAspect = (state().viewportAspectForTest as double);
    final narrow = state().cameraDistanceForTest as double;
    expect(narrowAspect, lessThan(0.5), reason: 'the pane is tall and narrow');
    expect(fits(1.0, narrow, narrowAspect), isTrue,
        reason: 'sphere radius 1 at distance $narrow must fit a ${narrowAspect.toStringAsFixed(2)} aspect');

    size.value = const Size(900, 500);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    final wideAspect = state().viewportAspectForTest as double;
    final wide = state().cameraDistanceForTest as double;
    expect(wideAspect, greaterThan(1.2));
    expect(fits(1.0, wide, wideAspect), isTrue);
    expect(wide, lessThan(narrow), reason: 'a wide pane frames the sphere closer, not at the narrow distance');
  });
}
