import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/temp_project.dart';

/// A notes body that counts its own taps: its state must survive a tab switch.
class _NotesBody extends StatefulWidget {
  const _NotesBody();
  @override
  State<_NotesBody> createState() => _NotesBodyState();
}

class _NotesBodyState extends State<_NotesBody> {
  int taps = 0;
  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const Key('notes_body'),
        onTap: () => setState(() => taps++),
        child: Text('notes $taps'),
      );
}

/// A real "probe" plugin: two right-dock panels, one bottom panel, and a
/// slot button whose `active` follows the chat panel.
class _ProbePlugin extends LuminaEditorPlugin {
  late EditorPanels panels;
  final button = ValueNotifier(const EditorButtonState(icon: LucideIcons.messageSquare, tooltip: 'Chat'));

  @override
  String get pluginName => 'probe';

  @override
  void register(LuminaEditorContext context) {
    panels = context.panels;
    context.registerPanel(EditorPanelDescriptor(
      id: 'probe.chat',
      title: 'Chat',
      icon: LucideIcons.messageSquare,
      defaultDock: PanelDefaultDock.right,
      builder: (_) => const Text('chat body', key: Key('chat_body')),
    ));
    context.registerPanel(EditorPanelDescriptor(
      id: 'probe.notes',
      title: 'Notes',
      icon: LucideIcons.notebook,
      defaultDock: PanelDefaultDock.right,
      builder: (_) => const _NotesBody(),
    ));
    context.registerPanel(EditorPanelDescriptor(
      id: 'probe.log',
      title: 'Probe Log',
      icon: LucideIcons.list,
      defaultDock: PanelDefaultDock.bottom,
      builder: (_) => const Text('log body', key: Key('log_body')),
    ));
    final chat = panels.visibility('probe.chat');
    chat.addListener(() => button.value = button.value.copyWith(active: chat.value));
    context.registerSlotButton(EditorSlotButton(
      id: 'chat',
      slot: EditorSlot.levelToolbarAfterBlueprints,
      state: button,
      command: EditorCommand(id: 'probe.toggleChat', label: 'Chat', canExecute: () => true, execute: (_) => panels.toggle('probe.chat')),
    ));
  }

  @override
  void unregister(LuminaEditorContext context) {}
}

void main() {
  late Directory root;
  late LuminaProject project;
  late EditorViewModel vm;
  late _ProbePlugin plugin;

  EditorViewModel open() {
    final v = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    plugin = _ProbePlugin();
    v.extensionRegistry.registerPlugin(plugin);
    return v;
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumina_plugins12_');
    Directory('${root.path}/DockGame/contents/levels').createSync(recursive: true);
    project = const LuminaProject(projectName: 'DockGame', activeLevel: 'contents/levels/L_Main.lmas');
    File('${root.path}/DockGame/DockGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    vm = open();
  });

  tearDown(() async {
    vm.dispose();
    await deleteTempProject(root);
  });

  Future<void> pumpEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await tester.pump(const Duration(milliseconds: 500));
  }

  final dock = find.byKey(const ValueKey('right_dock'));
  final chatBody = find.byKey(const Key('chat_body'));

  testWidgets('right panels are closed by default and not bottom tabs; show opens the dock right of the viewport', (tester) async {
    await pumpEditor(tester);
    expect(dock, findsNothing);
    expect(chatBody, findsNothing);
    expect(find.byKey(const ValueKey('bottom_tab_plugin_probe.chat')), findsNothing, reason: 'right panels are not bottom tabs');
    expect(find.byKey(const ValueKey('bottom_tab_plugin_probe.log')), findsOneWidget, reason: 'a bottom panel still is');

    plugin.panels.show('probe.chat');
    await tester.pump(const Duration(milliseconds: 300));
    expect(dock, findsOneWidget);
    expect(chatBody, findsOneWidget);
    final viewport = tester.getRect(find.byKey(vm.mcpServer.viewportBoundaryKey));
    expect(tester.getRect(dock).left, greaterThanOrEqualTo(viewport.right - 1));
    expect(plugin.button.value.active, isTrue, reason: 'the slot button follows the panel');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('two open panels get tabs; switching keeps state; close hides one; toggle closes the dock', (tester) async {
    await pumpEditor(tester);
    final notesVisibility = <bool>[];
    plugin.panels.visibility('probe.notes').addListener(() => notesVisibility.add(plugin.panels.visibility('probe.notes').value));
    plugin.panels.show('probe.chat');
    plugin.panels.show('probe.notes');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('right_dock_tab_probe.chat')), findsOneWidget);
    expect(find.byKey(const ValueKey('right_dock_tab_probe.notes')), findsOneWidget);
    expect(find.text('notes 0'), findsOneWidget, reason: 'notes was shown last, so it is active');
    await tester.tap(find.byKey(const Key('notes_body')));
    await tester.pump();
    expect(find.text('notes 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('right_dock_tab_probe.chat')));
    await tester.pump();
    expect(chatBody, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('right_dock_tab_probe.notes')));
    await tester.pump();
    expect(find.text('notes 1'), findsOneWidget, reason: 'the notes panel kept its state');

    await tester.tap(find.byKey(const ValueKey('right_dock_close_probe.notes')));
    await tester.pump();
    expect(plugin.panels.isVisible('probe.notes'), isFalse);
    expect(notesVisibility, [true, false]);
    expect(chatBody, findsOneWidget, reason: 'chat becomes active');
    expect(find.byKey(const ValueKey('right_dock_tab_probe.chat')), findsNothing, reason: 'no tab strip for one panel');

    plugin.panels.toggle('probe.chat');
    await tester.pump(const Duration(milliseconds: 300));
    expect(plugin.panels.isVisible('probe.chat'), isFalse);
    expect(dock, findsNothing);
    expect(plugin.button.value.active, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the Window menu checks open plugin panels', (tester) async {
    await pumpEditor(tester);
    Future<void> settle() async {
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    Future<MenuCheckbox> row(String id) async {
      await tester.tap(find.descendant(of: find.byType(Menubar), matching: find.text('Window')));
      await settle();
      return tester.widget<MenuCheckbox>(find.byKey(ValueKey('menu_check_window.panel.$id')));
    }

    expect((await row('probe.chat')).value, isFalse);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('menu_check_window.panel.probe.chat')), matching: find.text('Chat')));
    await settle();
    expect(chatBody, findsOneWidget, reason: 'the menu opened the dock');
    expect((await row('probe.chat')).value, isTrue);
    expect(tester.widget<MenuCheckbox>(find.byKey(const ValueKey('menu_check_window.panel.probe.log'))).value, isFalse, reason: 'the bottom panel shows the Content Browser');
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('menu_check_window.panel.probe.log')), matching: find.text('Probe Log')));
    await settle();
    expect(plugin.panels.isVisible('probe.log'), isTrue);
    expect((await row('probe.log')).value, isTrue);
    await tester.tapAt(const Offset(5, 990));
    await settle();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the open panel and the dock width persist; Reset Layout closes the dock', (tester) async {
    plugin.panels.show('probe.chat');
    vm.setPaneSize(rightWidth: 420);
    vm.dispose();
    vm = open();
    await pumpEditor(tester);
    expect(plugin.panels.isVisible('probe.chat'), isTrue);
    expect(chatBody, findsOneWidget);
    expect(tester.getSize(dock).width, closeTo(420, 2));

    final closed = <bool>[];
    plugin.panels.visibility('probe.chat').addListener(() => closed.add(plugin.panels.visibility('probe.chat').value));
    vm.commands.execute('window.resetLayout');
    await tester.pump(const Duration(milliseconds: 300));
    expect(dock, findsNothing);
    expect(closed, [false]);
    await tester.pumpWidget(const SizedBox());
  });
}
