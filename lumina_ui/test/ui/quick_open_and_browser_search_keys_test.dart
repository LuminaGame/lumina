import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Ctrl+P is Open Asset (the quick-open palette) from
/// anywhere in the editor, and the Content Browser's search is Ctrl+F while
/// the browser has focus. The browser used to take focus at start-up and keep
/// Ctrl+P for its own search box.
void main() {
  // The editor viewport's tickers never let pumpAndSettle settle.
  Future<void> settle(WidgetTester tester, {int frames = 10}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> pumpEditor(WidgetTester tester) async {
    final dir = Directory.systemTemp.createTempSync('lumina_quick_open_keys_');
    addTearDown(() => dir.deleteSync(recursive: true));
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'QuickOpenGame'),
      projectLocation: dir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await settle(tester);
  }

  Future<void> chord(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
  }

  final browserSearch = find.byWidgetPredicate((w) =>
      w is TextField && w.placeholder is Text && ((w.placeholder as Text).data ?? '').startsWith('Search Assets'));
  bool browserSearchFocused(WidgetTester tester) =>
      tester.widget<EditableText>(find.descendant(of: browserSearch, matching: find.byType(EditableText))).focusNode.hasFocus;
  const palette = 'Search assets...';

  Future<void> clickIntoBrowser(WidgetTester tester) async {
    await tester.tap(find.text('SMART VIEWS'));
    await settle(tester, frames: 3);
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<ContentBrowserWidget>(), isNotNull,
        reason: 'a click in the Content Browser gives it the keyboard');
  }

  testWidgets('Ctrl+P right after the editor opens opens Quick Open', (tester) async {
    await pumpEditor(tester);
    await chord(tester, LogicalKeyboardKey.keyP);
    expect(find.text(palette), findsOneWidget, reason: 'Ctrl+P is Open Asset from anywhere');
    expect(browserSearchFocused(tester), isFalse);
  });

  testWidgets('Ctrl+F in the focused Content Browser focuses its search', (tester) async {
    await pumpEditor(tester);
    expect(find.text('Search Assets (Ctrl+F)...'), findsOneWidget);
    await clickIntoBrowser(tester);
    await chord(tester, LogicalKeyboardKey.keyF);
    expect(browserSearchFocused(tester), isTrue, reason: 'Ctrl+F is the browser search');
    expect(find.text(palette), findsNothing);
  });

  testWidgets('Ctrl+P in the Content Browser still opens Quick Open', (tester) async {
    await pumpEditor(tester);
    await clickIntoBrowser(tester);
    await chord(tester, LogicalKeyboardKey.keyP);
    expect(find.text(palette), findsOneWidget);
    expect(browserSearchFocused(tester), isFalse, reason: 'the browser no longer keeps Ctrl+P for its search');
  });
}
