import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  tearDown(() {
    PluginDialogManager.instance.clear();
  });

  test('PluginDialogController manages state and notifies listeners', () {
    final controller = PluginDialogController(
      pluginId: 'test_plugin',
      pluginName: 'Test Plugin',
      pluginIcon: LucideIcons.sparkles,
      title: 'Model Weights',
      minimizedTitle: 'Weights',
      builder: (ctx, ctrl) => const SizedBox(),
    );

    expect(controller.pluginId, 'test_plugin');
    expect(controller.pluginName, 'Test Plugin');
    expect(controller.title, 'Model Weights');
    expect(controller.minimizedTitle, 'Weights');
    expect(controller.barrierDismissible, isFalse);
    expect(controller.isMinimized, isFalse);
    expect(controller.isClosed, isFalse);

    var notified = 0;
    controller.addListener(() => notified++);

    controller.updateStatus(text: 'Downloading 50%', progress: 0.5);
    expect(controller.statusText, 'Downloading 50%');
    expect(controller.progress, 0.5);
    expect(notified, 1);
  });

  test('PluginDialogManager registers and tracks minimized dialogs', () {
    final manager = PluginDialogManager.instance;
    expect(manager.activeDialogs, isEmpty);
    expect(manager.minimizedDialogs, isEmpty);

    final c1 = PluginDialogController(
      id: 'd1',
      pluginId: 'p1',
      pluginName: 'Plugin 1',
      title: 'Dialog 1',
      builder: (ctx, ctrl) => const SizedBox(),
    );
    final c2 = PluginDialogController(
      id: 'd2',
      pluginId: 'p2',
      pluginName: 'Plugin 2',
      title: 'Dialog 2',
      builder: (ctx, ctrl) => const SizedBox(),
    );

    manager.register(c1);
    manager.register(c2);

    expect(manager.activeDialogs.length, 2);
    expect(manager.minimizedDialogs, isEmpty);

    c1.isMinimized = true;
    manager.notify();
    expect(manager.minimizedDialogs.length, 1);
    expect(manager.minimizedDialogs.first.id, 'd1');

    c1.close();
    expect(manager.activeDialogs.length, 1);
    expect(manager.minimizedDialogs, isEmpty);
  });

  testWidgets('PluginDialogFrame renders header, close, minimize, and bottom plugin status bar', (tester) async {
    var minimized = false;
    var closed = false;

    final controller = PluginDialogController(
      pluginId: 'kimodo',
      pluginName: 'Kimodo Animation',
      pluginIcon: LucideIcons.sparkles,
      title: 'Kimodo Animation Model Weights',
      statusText: 'Ready to download',
      progress: 0.25,
      builder: (ctx, ctrl) => const SizedBox(),
    );

    controller.attachOverlayHandlers(
      onMinimize: () => minimized = true,
      onClose: () => closed = true,
      onRestore: (_) {},
    );

    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: PluginDialogFrame(
            controller: controller,
            child: const Text('Dialog Content Body'),
          ),
        ),
      ),
    );

    expect(find.text('Kimodo Animation Model Weights'), findsOneWidget);
    expect(find.text('Dialog Content Body'), findsOneWidget);
    expect(find.text('Plugin: Kimodo Animation'), findsOneWidget);
    expect(find.text('Ready to download'), findsOneWidget);
    expect(find.text('25.0%'), findsOneWidget);

    // Minimize button
    final minButton = find.byIcon(LucideIcons.minus);
    expect(minButton, findsOneWidget);
    await tester.tap(minButton);
    await tester.pump();
    expect(minimized, isTrue);

    // Close button
    final closeButton = find.byIcon(LucideIcons.x);
    expect(closeButton, findsOneWidget);
    await tester.tap(closeButton);
    await tester.pump();
    expect(closed, isTrue);
  });

  testWidgets('MinimizedPluginDialogsBar displays docked chip and restores on tap', (tester) async {
    var restored = false;

    final controller = PluginDialogController(
      id: 'kimodo_dlg',
      pluginId: 'kimodo',
      pluginName: 'Kimodo Animation',
      pluginIcon: LucideIcons.sparkles,
      title: 'Kimodo Animation Model Weights',
      minimizedTitle: 'Kimodo Weights',
      progress: 0.42,
      isMinimized: true,
      builder: (ctx, ctrl) => const SizedBox(),
    );

    controller.attachOverlayHandlers(
      onMinimize: () {},
      onClose: () {},
      onRestore: (_) => restored = true,
    );

    PluginDialogManager.instance.register(controller);

    await tester.pumpWidget(
      const ShadcnApp(
        home: Scaffold(
          child: MinimizedPluginDialogsBar(),
        ),
      ),
    );

    expect(find.text('Kimodo Weights'), findsOneWidget);
    expect(find.byIcon(LucideIcons.sparkles), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);

    await tester.tap(find.text('Kimodo Weights'));
    await tester.pump();
    expect(restored, isTrue);
  });
}
