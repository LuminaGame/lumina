import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// On the Third Person template's 60 m level, the actor labels and
/// icons sat on a shrunken copy of the level around the view centre: the
/// overlay projected through the view model's camera distance while the
/// Filament camera clamped it to 5000 cm.
void main() {
  testWidgets('actor labels sit on their actors when the camera frames a 60 m level', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('lumina_viewport_overlay_projection_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final template = GameTemplateCatalog.byId(kThirdPersonTemplateId);
    final vm = EditorViewModel(
      initialProject: LuminaProject(projectName: 'OverlayProjection', template: kThirdPersonTemplateId, input: template.input),
      projectLocation: tempDir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    // The level exactly as the launcher scaffolds it (walls at ±30 m).
    vm.restoreSnapshot(template.levelActors.map(EditorActorNode.fromMap).toList());
    vm.frameLevelBounds();
    expect(vm.cameraDistance, greaterThan(5000.0), reason: 'a 60 m level is framed from further than 50 m');

    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: ViewportWidget(viewModel: vm)));
    dynamic viewport() => tester.state(find.byType(ViewportWidget));
    final size = tester.getSize(find.byType(ViewportWidget));
    Offset? drawnAt(List<double> p) => viewport().nativeProjectForTest(p[0], p[1], p[2], size) as Offset?;
    Offset? labelAt(List<double> p) => viewport().overlayProjectForTest(p[0], p[1], p[2], size) as Offset?;

    for (var i = 0; i < 30 && drawnAt([0.0, 0.0, 0.0]) == null; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(drawnAt([0.0, 0.0, 0.0]), isNotNull, reason: 'the viewport needs its native Filament camera for this test');

    for (final name in ['Pillar_01', 'Pillar_06', 'Wall_North', 'Wall_East', 'Marker_Sphere', 'PlayerStart']) {
      final actor = vm.actors.firstWhere((a) => a.name == name);
      final rendered = drawnAt(actor.location);
      final label = labelAt(actor.location);
      expect(rendered, isNotNull, reason: '$name is in front of the Filament camera');
      expect(label, isNotNull, reason: '$name is in front of the overlay camera');
      expect((label! - rendered!).distance, lessThan(1.0),
          reason: "$name's label is painted at $label but Filament draws the actor at $rendered");
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 16));
    vm.dispose();
  });
}
