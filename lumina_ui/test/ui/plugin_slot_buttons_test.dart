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

/// Plugin buttons in four named slots of the level toolbar and
/// the status bar, each following its own live state. A real "slots" plugin
/// registered through the real registry, on a real temp project.
class _SlotsPlugin extends LuminaEditorPlugin {
  final Map<EditorSlot, ValueNotifier<EditorButtonState>> states = {
    for (final slot in EditorSlot.values)
      slot: ValueNotifier(EditorButtonState(icon: LucideIcons.sparkles, tooltip: 'Slot ${slot.name}')),
  };
  final Map<EditorSlot, int> clicks = {for (final slot in EditorSlot.values) slot: 0};
  final List<String> menuRuns = [];

  @override
  String get pluginName => 'slots';

  @override
  void register(LuminaEditorContext context) {
    for (final slot in EditorSlot.values) {
      context.registerSlotButton(EditorSlotButton(
        id: slot.name,
        slot: slot,
        state: states[slot]!,
        command: EditorCommand(id: 'slots.${slot.name}', label: slot.name, canExecute: () => true, execute: (_) => clicks[slot] = clicks[slot]! + 1),
      ));
    }
    context.registerSlotButton(EditorSlotButton(
      id: 'menu',
      slot: EditorSlot.levelToolbarEnd,
      order: 5,
      state: ValueNotifier(const EditorButtonState(icon: LucideIcons.list, tooltip: 'Menu', label: 'More')),
      command: EditorCommand(id: 'slots.menu', label: 'Menu', canExecute: () => true, execute: (_) => menuRuns.add('command')),
      menu: [
        EditorCommand(id: 'slots.menu.a', label: 'Run A', canExecute: () => true, execute: (_) => menuRuns.add('a')),
        EditorCommand(id: 'slots.menu.b', label: 'Run B', canExecute: () => false, execute: (_) => menuRuns.add('b')),
      ],
    ));
  }

  @override
  void unregister(LuminaEditorContext context) {}
}

void main() {
  late Directory root;
  late EditorViewModel vm;
  late _SlotsPlugin plugin;

  Key key(EditorSlot slot) => ValueKey('slot_button_slots.${slot.name}');

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumina_plugins10_');
    final projectDir = '${root.path}/SlotGame';
    Directory('$projectDir/contents/levels').createSync(recursive: true);
    const project = LuminaProject(projectName: 'SlotGame', activeLevel: 'contents/levels/L_Main.lmas');
    File('$projectDir/SlotGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    plugin = _SlotsPlugin();
  });

  tearDown(() async {
    vm.dispose();
    await deleteTempProject(root);
  });

  Future<void> pumpToolbar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: ToolbarWidget(viewModel: vm))));
    await tester.pump();
  }

  testWidgets('toolbar slots: right of Blueprints, and left of Quality', (tester) async {
    vm.extensionRegistry.registerPlugin(plugin);
    await pumpToolbar(tester);
    final blueprints = tester.getRect(find.byKey(const ValueKey('toolbar_blueprints')));
    final after = tester.getRect(find.byKey(key(EditorSlot.levelToolbarAfterBlueprints)));
    expect(after.left, greaterThanOrEqualTo(blueprints.right));
    expect(after.left - blueprints.right, lessThan(16), reason: 'immediately right of Blueprints');

    final end = tester.getRect(find.byKey(key(EditorSlot.levelToolbarEnd)));
    final quality = tester.getRect(find.textContaining('Quality: '));
    final menu = tester.getRect(find.byKey(const ValueKey('slot_button_slots.menu')));
    expect(end.right, lessThanOrEqualTo(menu.left), reason: 'order 0 before order 5');
    expect(menu.right, lessThanOrEqualTo(quality.left));
    expect(quality.left - menu.right, lessThan(48), reason: 'the slot ends beside Quality');
    expect(find.byKey(key(EditorSlot.statusBarLeft)), findsNothing, reason: 'status-bar slots are not in the toolbar');
    await tester.pumpWidget(const SizedBox());
  });

  // At the integration-test window width the right block (stats,
  // end-slot buttons, Quality) stays inside the view; the left groups scroll.
  testWidgets('at 1264 px the Quality button and the end-slot buttons are inside the view and tappable', (tester) async {
    vm.extensionRegistry.registerPlugin(plugin);
    tester.view.physicalSize = const Size(1264, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: ToolbarWidget(viewModel: vm))));
    await tester.pump();
    for (final finder in [find.textContaining('Quality: '), find.byKey(key(EditorSlot.levelToolbarEnd)), find.byKey(const ValueKey('toolbar_frame_stats'))]) {
      final r = tester.getRect(finder);
      expect(r.right, lessThanOrEqualTo(1264), reason: '$finder ends at ${r.right}');
    }
    await tester.tap(find.byKey(key(EditorSlot.levelToolbarEnd)));
    await tester.pump();
    expect(plugin.clicks[EditorSlot.levelToolbarEnd], 1);
    // The left groups are still all reachable: they scroll.
    final blueprints = find.byKey(const ValueKey('toolbar_blueprints'));
    await tester.ensureVisible(blueprints);
    await tester.pump();
    expect(tester.getRect(blueprints).right, lessThanOrEqualTo(1264));
    expect(tester.takeException(), isNull, reason: 'no overflow');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('status bar slots: after the actor counts, and before the RHI text', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    vm.extensionRegistry.registerPlugin(plugin);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await tester.pump(const Duration(milliseconds: 500));

    final counts = tester.getRect(find.byKey(const ValueKey('status_actor_counts')));
    final left = tester.getRect(find.byKey(key(EditorSlot.statusBarLeft)));
    final right = tester.getRect(find.byKey(key(EditorSlot.statusBarRight)));
    final rhi = tester.getRect(find.byKey(const ValueKey('status_bar_rhi')));
    expect(left.left, greaterThanOrEqualTo(counts.right));
    expect(right.right, lessThanOrEqualTo(rhi.left));
    for (final r in [left, right]) {
      expect(r.center.dy, closeTo(counts.center.dy, 4), reason: 'on the status bar line');
      expect(r.height, lessThanOrEqualTo(20));
    }
    expect(tester.takeException(), isNull, reason: 'no overflow in the 20 px status bar');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a button follows its live state: label, badge, busy, active, tone, enabled', (tester) async {
    vm.extensionRegistry.registerPlugin(plugin);
    await pumpToolbar(tester);
    const slot = EditorSlot.levelToolbarAfterBlueprints;
    final state = plugin.states[slot]!;
    final button = find.byKey(key(slot));

    state.value = state.value.copyWith(label: 'AI', badge: '3');
    await tester.pump();
    expect(find.descendant(of: button, matching: find.text('AI')), findsOneWidget);
    expect(find.descendant(of: button, matching: find.text('3')), findsOneWidget);

    state.value = state.value.copyWith(busy: true);
    await tester.pump();
    expect(find.descendant(of: button, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
    expect(find.descendant(of: button, matching: find.byIcon(LucideIcons.sparkles)), findsNothing, reason: 'the spinner replaces the icon');

    state.value = state.value.copyWith(busy: false, active: true, tone: EditorTone.primary);
    await tester.pump();
    final frame = tester.widget<Container>(find.byKey(const ValueKey('slot_button_frame_slots.levelToolbarAfterBlueprints')));
    final border = (frame.decoration! as BoxDecoration).border! as Border;
    expect(border.top.color, EditorColors.primary);

    state.value = state.value.copyWith(active: false, tone: EditorTone.warning);
    await tester.pump();
    final icon = tester.widget<Icon>(find.descendant(of: button, matching: find.byIcon(LucideIcons.sparkles)));
    expect(icon.color, EditorColors.logWarning);

    state.value = state.value.copyWith(enabled: false);
    await tester.pump();
    await tester.tap(button, warnIfMissed: false);
    await tester.pump();
    expect(plugin.clicks[slot], 0, reason: 'disabled');
    state.value = state.value.copyWith(enabled: true);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    expect(plugin.clicks[slot], 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a state change repaints only its own button', (tester) async {
    vm.extensionRegistry.registerPlugin(plugin);
    await pumpToolbar(tester);
    final a = find.byKey(key(EditorSlot.levelToolbarAfterBlueprints));
    final b = find.byKey(key(EditorSlot.levelToolbarEnd));
    final aBefore = tester.widget(a);
    final bBefore = tester.widget(b);
    plugin.states[EditorSlot.levelToolbarAfterBlueprints]!.value = plugin.states[EditorSlot.levelToolbarAfterBlueprints]!.value.copyWith(badge: '1');
    await tester.pump();
    expect(identical(tester.widget(a), aBefore), isFalse, reason: 'A rebuilt');
    expect(identical(tester.widget(b), bBefore), isTrue, reason: 'B was not rebuilt');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a button with a menu opens a dropdown of its commands; a disabled one does not run', (tester) async {
    vm.extensionRegistry.registerPlugin(plugin);
    await pumpToolbar(tester);
    await tester.tap(find.byKey(const ValueKey('slot_button_slots.menu')));
    await tester.pumpAndSettle();
    expect(plugin.menuRuns, isEmpty, reason: 'the click opens the menu, not the command');
    expect(find.byKey(const ValueKey('slot_menu_slots.menu.a')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('slot_menu_slots.menu.b')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(plugin.menuRuns, isEmpty, reason: 'Run B cannot execute');
    if (find.byKey(const ValueKey('slot_menu_slots.menu.a')).evaluate().isEmpty) {
      await tester.tap(find.byKey(const ValueKey('slot_button_slots.menu')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('slot_menu_slots.menu.a')));
    await tester.pumpAndSettle();
    expect(plugin.menuRuns, ['a']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an EditorToolbarButton renders at the toolbar end and runs its command', (tester) async {
    var ran = 0;
    vm.extensionRegistry
      ..beginRegistration('legacy')
      ..registerToolbarButton(EditorToolbarButton(
        id: 'go',
        tooltip: 'Go',
        icon: LucideIcons.play,
        group: 'whatever',
        command: EditorCommand(id: 'legacy.go', label: 'Go', canExecute: () => true, execute: (_) => ran++),
      ))
      ..endRegistration();
    await pumpToolbar(tester);
    final button = find.byKey(const ValueKey('slot_button_legacy.go'));
    final quality = tester.getRect(find.textContaining('Quality: '));
    expect(tester.getRect(button).right, lessThanOrEqualTo(quality.left));
    await tester.tap(button);
    await tester.pump();
    expect(ran, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no plugin buttons: no slot buttons anywhere', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await tester.pump(const Duration(milliseconds: 500));
    final slotKeys = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('slot_button_'));
    expect(slotKeys, findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
