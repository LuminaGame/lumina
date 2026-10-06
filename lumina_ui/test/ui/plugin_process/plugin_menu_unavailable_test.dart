import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_supervisor_timings.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/views/menu_tree_builder.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'plugin_process_harness.dart';

/// The menu rows of an isolated plugin follow its process: while it is
/// not running every row (plain, with an icon, checkable) is disabled the
/// same way, with the reason on hover.
void main() {
  // No automatic restarts: the process stays stopped until Restart.
  const timings = PluginSupervisorTimings(
    pingInterval: Duration(milliseconds: 300),
    restartBackoff: [],
    startTimeout: Duration(seconds: 30),
    callTimeout: Duration(seconds: 5),
    shutdownTimeout: Duration(seconds: 2),
  );

  const plain = ['fake.do', 'fake.settings'];
  const checkable = 'fake.preview';
  const labels = ['Do Thing', 'Fake Settings', 'Fake Preview'];

  testWidgets('every menu row of a stopped plugin process renders disabled alike, with the reason', (tester) async {
    late PluginProcessHarness h;
    await tester.runAsync(() async {
      h = await PluginProcessHarness.create(timings: timings);
      h.mode = 'normal';
    });
    addTearDown(() => tester.runAsync(h.dispose));
    final s = h.supervisor;
    await tester.runAsync(() async {
      await s.start();
      await waitForStatus(s, PluginProcessStatus.running);
    });

    // The Plugins menu as the menu bar builds it, opened down to the
    // plugin's submenu (a menu builds its rows when it opens).
    var opened = 0;
    Future<void> openFakeMenu() async {
      opened++;
      await tester.pumpWidget(ShadcnApp(
        key: ValueKey('app_$opened'),
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: Builder(
            builder: (context) => Menubar(children: [
              MenuButton(
                subMenu: buildMenuTree(
                  [
                    for (final e in h.registry.menuEntriesUnder('Plugins'))
                      MenuTreeEntry(path: e.segments.sublist(1), command: e.command, options: e.options),
                  ],
                  commandContext: context,
                ),
                child: const Text('Plugins'),
              ),
            ]),
          ),
        ),
      ));
      await tester.tap(find.text('Plugins'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fake'));
      await tester.pumpAndSettle();
    }

    bool rowEnabled(String id) => tester.widget<MenuButton>(find.byKey(ValueKey('menu_item_$id'))).enabled;
    bool checkEnabled() => tester.widget<MenuCheckbox>(find.byKey(const ValueKey('menu_check_$checkable'))).enabled;
    Color? labelColor(String label) => tester.renderObject<RenderParagraph>(find.text(label)).text.style?.color;

    await openFakeMenu();
    for (final id in plain) {
      expect(rowEnabled(id), isTrue, reason: '$id while running');
    }
    expect(checkEnabled(), isTrue);
    final runningColor = labelColor('Do Thing');
    expect(find.byKey(const ValueKey('menu_unavailable_fake.do')), findsNothing);

    // The process dies and stays stopped.
    await tester.runAsync(() async {
      await s.call('exit', {'code': 3}).catchError((_) => null);
      await waitForStatus(s, PluginProcessStatus.stopped);
    });
    await openFakeMenu();
    for (final id in plain) {
      expect(rowEnabled(id), isFalse, reason: '$id while stopped');
      expect(tester.widget<MenuButton>(find.byKey(ValueKey('menu_item_$id'))).onPressed, isNull);
    }
    expect(checkEnabled(), isFalse);
    // One look for every row: the checkbox row's disabled grey.
    final colors = {for (final l in labels) labelColor(l)};
    expect(colors, hasLength(1), reason: 'labels of the stopped plugin: $colors');
    expect(colors.single, isNot(runningColor));
    for (final id in [...plain, checkable]) {
      final tip = tester.widget<Tooltip>(find.byKey(ValueKey('menu_unavailable_$id')));
      expect(tip, isNotNull);
    }
    expect(s.unavailableReason, startsWith('$kFakePluginName stopped: exited with code 3'));

    // Restarted: the rows are live again.
    await tester.runAsync(() async {
      await s.restart();
      await waitForStatus(s, PluginProcessStatus.running);
    });
    await openFakeMenu();
    for (final id in plain) {
      expect(rowEnabled(id), isTrue, reason: '$id after the restart');
    }
    expect(checkEnabled(), isTrue);
    expect(labelColor('Fake Settings'), runningColor);
  });
}
