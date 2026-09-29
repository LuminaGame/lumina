import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/toolbar_widget.dart';
import 'package:lumina/lumina.dart';
import 'dart:io';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  testWidgets('Toolbar exposes working translate/rotate/scale snap toggles', (tester) async {
    // An editor-sized window; at the default 800 px test surface
    // the snap group sits in the toolbar's scrolled-away part.
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final tempProjectsDir = Directory.systemTemp.createTempSync('snap_toolbar_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeProject');
    pDir.createSync(recursive: true);
    final p = LuminaProject(projectName: 'SmokeProject');
    final vm = EditorViewModel(initialProject: p, projectLocation: pDir.path);
    
    
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: ToolbarWidget(viewModel: vm)),
    ));
    await tester.pumpAndSettle();
    
    // We expect 4 toggle buttons for snaps: Magnet (Translate), Rotate Snap, Scale Snap, Grid Eye
    expect(find.descendant(of: find.byKey(const Key('toggle_translate_snap')), matching: find.byType(GhostButton)), findsOneWidget); // Translate
    expect(find.descendant(of: find.byKey(const Key('toggle_rotate_snap')), matching: find.byType(GhostButton)), findsOneWidget); // Rotate
    expect(find.descendant(of: find.byKey(const Key('toggle_scale_snap')), matching: find.byType(GhostButton)), findsOneWidget); // Scale
    expect(find.descendant(of: find.byKey(const Key('toggle_grid_snap')), matching: find.byType(GhostButton)), findsOneWidget); // Grid
    
    // Test toggle Translate Snap
    expect(vm.translateSnapEnabled, isTrue); // default
    await tester.tap(find.descendant(of: find.byKey(const Key('toggle_translate_snap')), matching: find.byType(GhostButton)));
    await tester.pumpAndSettle();
    expect(vm.translateSnapEnabled, isFalse);
    
    // Test toggle Rotate Snap
    expect(vm.rotateSnapEnabled, isTrue); // default
    await tester.tap(find.descendant(of: find.byKey(const Key('toggle_rotate_snap')), matching: find.byType(GhostButton)));
    await tester.pumpAndSettle();
    expect(vm.rotateSnapEnabled, isFalse);
    
    // Test toggle Scale Snap
    expect(vm.scaleSnapEnabled, isTrue); // default
    await tester.tap(find.descendant(of: find.byKey(const Key('toggle_scale_snap')), matching: find.byType(GhostButton)));
    await tester.pumpAndSettle();
    expect(vm.scaleSnapEnabled, isFalse);
    
    // Test toggle Grid
    expect(vm.gridVisible, isTrue); // default
    await tester.tap(find.descendant(of: find.byKey(const Key('toggle_grid_snap')), matching: find.byType(GhostButton)));
    await tester.pumpAndSettle();
    expect(vm.gridVisible, isFalse);
    vm.dispose();
  });
  testWidgets('Toolbar can change snap increments via dropdown', (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('snap_toolbar2_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeProject');
    pDir.createSync(recursive: true);
    final p = LuminaProject(projectName: 'SmokeProject');
    final vm = EditorViewModel(initialProject: p, projectLocation: pDir.path);
    
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: ToolbarWidget(viewModel: vm)),
    ));
    await tester.pumpAndSettle();
    
    // Default translate step is 10
    expect(vm.translateSnapStep, 10.0);
    
    // Tap the value display to open the menu; steps read with their unit.
    await tester.tap(find.text('10 cm').first);
    await tester.pumpAndSettle();
    
    // Tap the 50 cm option; 5 m is listed as metres.
    expect(find.text('5 m'), findsOneWidget);
    await tester.tap(find.text('50 cm').last);
    await tester.pumpAndSettle();
    
    expect(vm.translateSnapStep, 50.0);
    
    vm.dispose();
  });

}