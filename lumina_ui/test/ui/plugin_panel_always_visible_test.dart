import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/toolbar_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/temp_project.dart';

/// A chat body that counts its own taps: the same state object must follow
/// the user from tab to tab.
class _ChatBody extends StatefulWidget {
  const _ChatBody();
  @override
  State<_ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends State<_ChatBody> {
  int taps = 0;
  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const Key('chat_body'),
        onTap: () => setState(() => taps++),
        child: Text('chat $taps'),
      );
}

/// A real plugin with two right-dock panels (chat, notes) and, optionally,
/// a third that asks to be shown in every editor.
class _AlwaysProbePlugin extends LuminaEditorPlugin {
  late EditorPanels panels;

  @override
  String get pluginName => 'always_probe';

  @override
  void register(LuminaEditorContext context) {
    panels = context.panels;
    context.registerPanel(EditorPanelDescriptor(
      id: 'probe.chat',
      title: 'Chat',
      icon: LucideIcons.messageSquare,
      defaultDock: PanelDefaultDock.right,
      builder: (_) => const _ChatBody(),
    ));
    context.registerPanel(EditorPanelDescriptor(
      id: 'probe.notes',
      title: 'Notes',
      icon: LucideIcons.notebook,
      defaultDock: PanelDefaultDock.right,
      builder: (_) => const Text('notes body', key: Key('notes_body')),
    ));
    context.registerPanel(EditorPanelDescriptor(
      id: 'probe.console',
      title: 'Console',
      icon: LucideIcons.terminal,
      defaultDock: PanelDefaultDock.right,
      defaultAlwaysVisible: true,
      builder: (_) => const Text('console body', key: Key('console_body')),
    ));
  }

  @override
  void unregister(LuminaEditorContext context) {}
}

void main() {
  late Directory root;
  late LuminaProject project;
  late EditorViewModel vm;
  late _AlwaysProbePlugin plugin;

  EditorViewModel open() {
    final v = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    plugin = _AlwaysProbePlugin();
    v.extensionRegistry.registerPlugin(plugin);
    return v;
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumina_always_');
    Directory('${root.path}/AlwaysGame/contents/levels').createSync(recursive: true);
    project = const LuminaProject(projectName: 'AlwaysGame', activeLevel: 'contents/levels/L_Main.lmas');
    File('${root.path}/AlwaysGame/AlwaysGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    vm = open();
  });

  tearDown(() async {
    vm.dispose();
    await deleteTempProject(root);
  });

  Future<void> frames(WidgetTester tester, [int count = 20]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> pumpEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> openNavigation(WidgetTester tester) async {
    vm.openSubEditorTab('navmesh', title: 'Navigation');
    await frames(tester);
    expect(vm.currentTab.category, 'navmesh');
    expect(find.text('AGENT & GRID'), findsOneWidget, reason: 'the Navigation editor with its own right panel');
  }

  Future<void> levelTab(WidgetTester tester) async {
    vm.selectTab(0);
    await frames(tester);
  }

  final dock = find.byKey(const ValueKey('right_dock'));
  final chatBody = find.byKey(const Key('chat_body'));
  _ChatBodyState chatState(WidgetTester tester) => tester.state<_ChatBodyState>(find.byType(_ChatBody, skipOffstage: false));

  testWidgets('without "Always" a panel stays in the level editor and keeps its state while away', (tester) async {
    await pumpEditor(tester);
    plugin.panels.show('probe.chat');
    await frames(tester);
    await tester.tap(chatBody);
    await tester.pump();
    final state = chatState(tester);
    expect(state.taps, 1);

    await openNavigation(tester);
    expect(dock, findsNothing, reason: 'the chat is not an "Always" panel');
    expect(chatBody, findsNothing);
    expect(find.byType(ToolbarWidget), findsNothing, reason: 'the level toolbar stays on the level tab');

    await levelTab(tester);
    expect(chatBody, findsOneWidget);
    expect(identical(chatState(tester), state), isTrue, reason: 'parked, not rebuilt');
    expect(find.text('chat 1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with "Always" on the same panel follows into sub-editor tabs, right of their own panels', (tester) async {
    await pumpEditor(tester);
    plugin.panels.show('probe.chat');
    await frames(tester);
    await tester.tap(chatBody);
    await tester.pump();
    final state = chatState(tester);

    final pin = find.byKey(const ValueKey('right_dock_always_probe.chat'));
    expect(pin, findsOneWidget);
    await tester.tap(pin);
    await frames(tester);
    expect(vm.panelsController.isAlwaysVisible('probe.chat'), isTrue);

    await openNavigation(tester);
    expect(dock, findsOneWidget);
    expect(chatBody, findsOneWidget);
    expect(identical(chatState(tester), state), isTrue, reason: 'one panel instance for every tab');
    expect(find.text('chat 1'), findsOneWidget);
    final agentPanel = tester.getRect(find.text('AGENT & GRID'));
    expect(tester.getRect(dock).left, greaterThanOrEqualTo(agentPanel.right), reason: 'the dock sits right of the sub-editor');
    expect(find.byType(ToolbarWidget), findsNothing, reason: 'the level toolbar stays on the level tab');
    await tester.tap(chatBody);
    await tester.pump();

    vm.openSubEditorTab('material', title: 'Material Editor');
    await frames(tester);
    expect(vm.currentTab.category, 'material');
    expect(chatBody, findsOneWidget, reason: 'every sub-editor shows it');
    expect(find.text('chat 2'), findsOneWidget);

    await levelTab(tester);
    expect(identical(chatState(tester), state), isTrue);
    expect(find.text('chat 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('outside the level editor only the "Always" panels show; a plugin can make that the default', (tester) async {
    await pumpEditor(tester);
    plugin.panels.show('probe.notes');
    plugin.panels.show('probe.chat');
    vm.panelsController.setAlwaysVisible('probe.chat', true);
    await frames(tester);
    expect(find.byKey(const ValueKey('right_dock_tab_probe.notes')), findsOneWidget);
    expect(find.byKey(const ValueKey('right_dock_tab_probe.chat')), findsOneWidget);

    await openNavigation(tester);
    expect(chatBody, findsOneWidget);
    expect(find.byKey(const ValueKey('right_dock_tab_probe.notes')), findsNothing, reason: 'notes is level-only');
    expect(find.byKey(const ValueKey('right_dock_tab_probe.chat')), findsNothing, reason: 'one shown panel, no tab strip');

    plugin.panels.show('probe.console');
    await frames(tester);
    expect(vm.panelsController.isAlwaysVisible('probe.console'), isTrue, reason: 'the plugin default');
    expect(find.byKey(const Key('console_body')), findsOneWidget);
    expect(find.byKey(const ValueKey('right_dock_tab_probe.chat')), findsOneWidget);
    expect(find.byKey(const ValueKey('right_dock_tab_probe.notes')), findsNothing);

    await levelTab(tester);
    expect(find.byKey(const ValueKey('right_dock_tab_probe.notes')), findsOneWidget, reason: 'the level tab shows all three');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('closing a panel on a sub-editor tab closes it everywhere', (tester) async {
    await pumpEditor(tester);
    plugin.panels.show('probe.chat');
    vm.panelsController.setAlwaysVisible('probe.chat', true);
    await openNavigation(tester);
    expect(chatBody, findsOneWidget);
    final closed = <bool>[];
    plugin.panels.visibility('probe.chat').addListener(() => closed.add(plugin.panels.visibility('probe.chat').value));

    await tester.tap(find.byKey(const ValueKey('right_dock_close_probe.chat')));
    await frames(tester);
    expect(dock, findsNothing);
    expect(closed, [false]);
    await levelTab(tester);
    expect(dock, findsNothing);
    expect(chatBody, findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the Window menu shows and toggles "Always" per right-dock panel', (tester) async {
    await pumpEditor(tester);
    plugin.panels.show('probe.chat');
    vm.panelsController.setAlwaysVisible('probe.chat', true);
    await openNavigation(tester);
    expect(chatBody, findsOneWidget);

    Future<MenuCheckbox> row(String id) async {
      await tester.tap(find.descendant(of: find.byType(Menubar), matching: find.text('Window')));
      await frames(tester);
      return tester.widget<MenuCheckbox>(find.byKey(ValueKey('menu_check_$id')));
    }

    expect((await row('window.panelAlways.probe.chat')).value, isTrue);
    expect(find.byKey(const ValueKey('menu_check_window.panel.probe.chat')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('menu_check_window.panelAlways.probe.chat')));
    await frames(tester);
    expect(vm.panelsController.isAlwaysVisible('probe.chat'), isFalse);
    expect(dock, findsNothing, reason: 'level-only again, so it leaves the Navigation tab');
    expect(plugin.panels.isVisible('probe.chat'), isTrue, reason: 'still open in the level editor');
    await tester.tapAt(const Offset(5, 990));
    await frames(tester);

    // The Window-menu toggle of the panel itself works on this tab too.
    vm.panelsController.setAlwaysVisible('probe.chat', true);
    await frames(tester);
    expect(chatBody, findsOneWidget);
    vm.commands.execute('window.panel.probe.chat');
    await frames(tester);
    expect(dock, findsNothing);
    expect(plugin.panels.isVisible('probe.chat'), isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('"Always" persists in editor_layout.json; Reset Layout restores the plugin defaults', (tester) async {
    plugin.panels.show('probe.chat');
    vm.panelsController.setAlwaysVisible('probe.chat', true);
    vm.panelsController.setAlwaysVisible('probe.console', false);
    final saved = jsonDecode(File('${root.path}/AlwaysGame/.lumina/editor_layout.json').readAsStringSync()) as Map<String, dynamic>;
    expect(saved['pluginPanelAlways'], {'probe.chat': true, 'probe.console': false});

    vm.dispose();
    vm = open();
    expect(vm.panelsController.isAlwaysVisible('probe.chat'), isTrue);
    expect(vm.panelsController.isAlwaysVisible('probe.console'), isFalse);
    await pumpEditor(tester);
    await openNavigation(tester);
    expect(chatBody, findsOneWidget, reason: 'restored after a restart');

    vm.commands.execute('window.resetLayout');
    await frames(tester);
    expect(vm.panelsController.isAlwaysVisible('probe.chat'), isFalse);
    expect(vm.panelsController.isAlwaysVisible('probe.console'), isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
