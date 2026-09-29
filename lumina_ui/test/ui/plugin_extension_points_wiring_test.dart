import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/output_log_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/toolbar_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/temp_project.dart';

/// A plugin's toolbar buttons, panels, importers and console
/// commands were stored by the registry and read by nothing. A real "probe"
/// plugin registered through the real registry, on a real temp project.
void main() {
  late Directory root;
  late String projectDir;
  late EditorViewModel vm;
  late List<String> said;
  late int clicks;
  late List<String> imported;

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumina_bugs101_');
    projectDir = '${root.path}/ProbeGame';
    Directory('$projectDir/contents/levels').createSync(recursive: true);
    const project = LuminaProject(projectName: 'ProbeGame', activeLevel: 'contents/levels/L_Main.lmas');
    File('$projectDir/ProbeGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    said = [];
    clicks = 0;
    imported = [];

    final r = vm.extensionRegistry;
    r.beginRegistration('probe');
    r.registerToolbarButton(EditorToolbarButton(
      id: 'probe.button',
      tooltip: 'Probe button',
      icon: LucideIcons.sparkles,
      group: 'probe',
      command: EditorCommand(id: 'probe.click', label: 'Probe click', canExecute: () => true, execute: (_) => clicks++),
    ));
    r.registerPanel(EditorPanelDescriptor(
      id: 'probe.panel',
      title: 'Probe Panel',
      icon: LucideIcons.box,
      defaultDock: PanelDefaultDock.right,
      builder: (_) => const Text('probe panel body', key: Key('probe_panel_body')),
    ));
    r.registerImporter(EditorImporter(
      extensions: const ['probe'],
      description: 'Probe files',
      import: (file, ctx) async {
        imported.add('${file.path} -> ${ctx.targetDirectory}');
        final out = File('${ctx.targetDirectory}/${file.uri.pathSegments.last}.imported')..writeAsStringSync('ok');
        return ImportResult.success(out.path);
      },
    ));
    r.registerImporter(EditorImporter(
      extensions: const ['badprobe'],
      description: 'Failing probe files',
      import: (file, ctx) async => const ImportResult.failure('probe refused it'),
    ));
    r.registerConsoleCommand('probe.say', 'Echo the arguments', (args) => said.add(args.join(' ')));
    r.endRegistration();
  });

  tearDown(() async {
    vm.dispose();
    await deleteTempProject(root);
  });

  group('importers', () {
    test('plugin extensions are importable, routed to the plugin, into the selected folder; failures are logged', () async {
      expect(vm.importExtensions, containsAll([...ImportFormats.extensions, 'probe', 'badprobe']));
      expect(vm.pluginImporterFor('/x/level.PROBE')?.description, 'Probe files', reason: 'extensions match case-insensitively');
      expect(vm.pluginImporterFor('/x/barrel.glb'), isNull, reason: 'the built-in pipeline keeps its formats');

      final source = File('${root.path}/data.probe')..writeAsStringSync('payload');
      final bad = File('${root.path}/data.badprobe')..writeAsStringSync('payload');
      vm.selectedFolder = 'contents/levels';
      final results = await vm.importWithPluginImporters([source.path, bad.path]);
      expect(results.map((r) => r.success), [true, false]);
      expect(imported.single, '${source.path} -> ${vm.projectDirPath}/contents/levels');
      expect(File('${vm.projectDirPath}/contents/levels/data.probe.imported').existsSync(), isTrue);
      final lines = vm.logger.logs.map((l) => l.message).toList();
      expect(lines.any((m) => m.contains('data.probe') && m.contains('Probe files')), isTrue, reason: lines.join('\n'));
      expect(lines.any((m) => m.contains('probe refused it')), isTrue);
    });
  });

  group('console commands', () {
    test('a registered command runs with its arguments; help lists commands; an unknown one is an error', () {
      vm.runConsoleCommand('probe.say hello  world');
      expect(said, ['hello world']);
      vm.runConsoleCommand('help');
      expect(vm.logger.logs.last.message, contains('probe.say'));
      expect(vm.logger.logs.last.message, contains('Echo the arguments'));
      vm.runConsoleCommand('nope.cmd 1');
      expect(vm.logger.logs.last.level, 'error');
      expect(vm.logger.logs.last.message, contains('nope.cmd'));
      vm.runConsoleCommand('   ');
      expect(said, ['hello world'], reason: 'an empty line does nothing');
    });

    testWidgets('the Output Log command line runs what is typed on Enter; Up recalls the last command', (tester) async {
      tester.view.physicalSize = const Size(1200, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: ListenableBuilder(listenable: vm, builder: (_, _) => OutputLogWidget(viewModel: vm))),
      ));
      await tester.pump();
      final field = find.byKey(const ValueKey('output_log_command'));
      expect(field, findsOneWidget);
      await tester.enterText(field, 'probe.say from the log');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(said, ['from the log']);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty, reason: 'the line clears after running');
      await tester.tap(field);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, 'probe.say from the log');
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('a plugin toolbar button renders in the level toolbar and runs its command', (tester) async {
    tester.view.physicalSize = const Size(2400, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: ToolbarWidget(viewModel: vm))));
    await tester.pump();
    final button = find.byKey(const ValueKey('slot_button_probe.probe.button'));
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pump();
    expect(clicks, 1);
    await tester.pumpWidget(const SizedBox());
  });

  // The probe panel asks for PanelDefaultDock.right, so it lives
  // in the right dock (closed by default) rather than the bottom panel.
  testWidgets('a right-docked plugin panel opens in the right dock from Window ▸ <title>', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const ValueKey('bottom_tab_plugin_probe.panel')), findsNothing);
    expect(find.byKey(const Key('probe_panel_body')), findsNothing, reason: 'closed by default');

    // Window ▸ Probe Panel toggles it in the right dock.
    vm.commands.execute('window.panel.probe.panel');
    await tester.pump(const Duration(milliseconds: 300));
    expect(vm.isPluginPanelShowing('probe.panel'), isTrue);
    expect(find.byKey(const ValueKey('right_dock')), findsOneWidget);
    expect(find.byKey(const Key('probe_panel_body')), findsOneWidget);

    vm.commands.execute('window.panel.probe.panel');
    await tester.pump(const Duration(milliseconds: 300));
    expect(vm.isPluginPanelShowing('probe.panel'), isFalse);
    expect(find.byKey(const Key('probe_panel_body')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
