import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_layout_state.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_drawer.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/output_log_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The Content Drawer while the bottom panel is unpinned: a 36 px bar along
/// the bottom of the viewport island (toggle, pin, breadcrumb, Output Log,
/// Ready · MCP), and a 322 px panel that slides up over the viewport; the pin
/// docks it into the layout; its open and pinned state persist.
void main() {
  Future<void> settle(WidgetTester tester, {int frames = 16}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  late Directory dir;

  Future<EditorViewModel> pumpEditor(WidgetTester tester, {bool pinned = false}) async {
    dir = Directory.systemTemp.createTempSync('lumina_drawer_');
    addTearDown(() => dir.deleteSync(recursive: true));
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'DrawerGame'),
      projectLocation: dir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(vm.dispose);
    vm.layoutState.bottomPinned = pinned;
    vm.layoutState.bottomVisible = false;
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await settle(tester);
    return vm;
  }

  testWidgets('closed: the bar sits along the bottom of the viewport island and no panel is built', (tester) async {
    await pumpEditor(tester);
    final bar = tester.getRect(find.byKey(const ValueKey('content_drawer_bar')));
    final island = tester.getRect(find.byKey(const ValueKey('island_viewport')));
    expect(bar.height, ContentDrawerBar.height);
    expect(island.bottom - bar.bottom, closeTo(1, 0.5), reason: 'inside the island border, at its bottom');
    expect(find.byType(ContentBrowserWidget), findsNothing, reason: 'closed, the drawer builds no panel');
    expect(find.text('Content Drawer'), findsOneWidget);
    expect(find.textContaining('Ready · MCP'), findsOneWidget);
    expect(find.text('Content'), findsOneWidget, reason: 'the breadcrumb of the contents folder');
  });

  testWidgets('the toggle slides a 322 px panel up over the viewport; again closes it', (tester) async {
    final vm = await pumpEditor(tester);
    final viewportBefore = tester.getRect(find.byKey(const ValueKey('island_viewport')));
    await tester.tap(find.byKey(const ValueKey('content_drawer_toggle')));
    await tester.pump();
    expect(vm.layoutState.bottomVisible, isTrue);
    expect(find.byType(ContentBrowserWidget), findsOneWidget, reason: 'open on the first frame');
    await settle(tester, frames: 20);
    final panel = tester.getRect(find.byKey(const ValueKey('content_drawer_panel')));
    final bar = tester.getRect(find.byKey(const ValueKey('content_drawer_bar')));
    expect(panel.height, ContentDrawer.height);
    expect(panel.bottom, closeTo(bar.top, 0.5), reason: 'the panel rests on the bar');
    expect(tester.getRect(find.byKey(const ValueKey('island_viewport'))), viewportBefore,
        reason: 'over the viewport: the viewport island keeps its size');

    await tester.tap(find.byKey(const ValueKey('content_drawer_toggle')));
    await settle(tester, frames: 20);
    expect(vm.layoutState.bottomVisible, isFalse);
    expect(find.byType(ContentBrowserWidget), findsNothing);
  });

  testWidgets('Output Log opens the drawer on the log; the toggle then brings the Content Browser forward', (tester) async {
    final vm = await pumpEditor(tester);
    await tester.tap(find.byKey(const ValueKey('content_drawer_output_log')));
    await settle(tester);
    expect(vm.layoutState.isOutputLogOpen, isTrue);
    expect(find.byType(OutputLogWidget), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('content_drawer_toggle')));
    await settle(tester);
    expect(vm.layoutState.bottomVisible, isTrue);
    expect(vm.layoutState.activeBottomTab, EditorLayoutState.contentBrowserTab);
  });

  testWidgets('the breadcrumb follows the selected folder', (tester) async {
    final vm = await pumpEditor(tester);
    Directory('${vm.projectDirPath}/contents/Props/Barrels').createSync(recursive: true);
    vm.selectedFolder = 'contents/Props/Barrels';
    await settle(tester);
    expect(find.text('Content / Props / Barrels'), findsOneWidget);
    expect(ContentDrawerBar.breadcrumb(null), 'Content');
  });

  testWidgets('pin docks the panel into the layout and the choice persists', (tester) async {
    final vm = await pumpEditor(tester);
    await tester.tap(find.byKey(const ValueKey('content_drawer_pin')));
    await settle(tester);
    expect(vm.layoutState.bottomPinned, isTrue);
    expect(find.byKey(const ValueKey('content_drawer_bar')), findsNothing, reason: 'pinned, there is no drawer');
    vm.toggleContentDrawer();
    await settle(tester);
    expect(find.byKey(const ValueKey('island_bottom_panel')), findsOneWidget);
    final layout = File('${vm.projectDirPath}/.lumina/editor_layout.json');
    expect(layout.existsSync(), isTrue, reason: 'the layout is saved');
    expect((jsonDecode(layout.readAsStringSync()) as Map)['bottomPinned'], isTrue);
    // Unpin from the docked panel: back to a closed drawer.
    await tester.tap(find.byKey(const ValueKey('bottom_panel_pin')));
    await settle(tester);
    expect(vm.layoutState.bottomPinned, isFalse);
    expect(find.byKey(const ValueKey('content_drawer_bar')), findsOneWidget);
  });
}
