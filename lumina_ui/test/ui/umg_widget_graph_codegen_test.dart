import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/umg_widget_codegen.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/widget_graph_fixture.dart';
import 'generated/wbp_clicker.g.dart';

/// A widget's graph compiles into its generated file
/// (lumina's widget script class, embedded) and runs the same there as in
/// the VM. The whole generated `wbp_clicker.dart` is committed as
/// `generated/wbp_clicker.g.dart` and used in-process: its widget is pumped
/// and its button tapped. `UPDATE_GOLDENS=1 flutter test
/// test/ui/umg_widget_graph_codegen_test.dart` rewrites it.
const String _golden = 'test/ui/generated/wbp_clicker.g.dart';

void main() {
  tearDown(() {
    LuminaUserWidgets.clear();
    LuminaWidgetBuilderRegistry.clear();
    LuminaWidgetClassRegistry.clear();
  });

  test('the generated WBP_Clicker embeds WbpClickerGraph and its handler fires the graph (golden)', () {
    final warnings = <String>[];
    final src = UmgWidgetCodegen.generateWidgetDart(clickerDocument(), assetName: 'WBP_Clicker', warnings: warnings);
    expect(warnings, isEmpty);
    expect(src, contains('class WbpClickerGraph extends LuminaUserWidget with LuminaBlueprintRuntime {'));
    expect(src, contains("LuminaUserWidgets.fire(widget.instance, 'StartButton', 'OnClicked');"));
    expect(src, contains('// BEGIN USER CODE: on_clicked_startButton'));
    expect(src, contains("import 'package:lumina/lumina_runtime.dart';"));
    final golden = File(_golden);
    if (Platform.environment['UPDATE_GOLDENS'] == '1') golden.writeAsStringSync(src);
    expect(src, golden.readAsStringSync(), reason: '$_golden changed; UPDATE_GOLDENS=1 regenerates it');
    // Deterministic.
    expect(UmgWidgetCodegen.generateWidgetDart(clickerDocument(), assetName: 'WBP_Clicker'), src);
    // A graph bound only in the graph still gets its handler.
    final graphOnly = clickerDocument();
    graphOnly.findNode('n_button')!.events.clear();
    expect(UmgWidgetCodegen.generateWidgetDart(graphOnly, assetName: 'WBP_Clicker'), contains('void _onClickedStartButton() {'));
    // Without a graph the file is what it was before graphs existed.
    final plain = clickerDocument()..blueprint = null;
    expect(UmgWidgetCodegen.generateWidgetDart(plain, assetName: 'WBP_Clicker'), isNot(contains('LuminaUserWidgets')));
  });

  testWidgets('the generated widget and graph and the VM agree: Construct shows Title, a click sets "Clicked!"', (tester) async {
    Future<List<String>> run(LuminaUserWidget Function() script) async {
      LuminaWidgetBuilderRegistry.register('WBP_Clicker', UmgWidgetCodegen.widgetClassFor(clickerDocument(), 'WBP_Clicker'),
          (context, instance) => WbpClicker(instance: instance));
      LuminaUserWidgets.register('WBP_Clicker', script);
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.beginPlay();
      final owner = world.spawnActorImmediately(LuminaActor());
      final widget = LuminaBlueprintFunctionLibrary.createWidget(owner, 'WBP_Clicker') as Map<String, Object?>;
      final title = (widget['elements']! as Map)['Title'] as Map<String, Object?>;
      title['visibility'] = 'Collapsed';
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: SizedBox(width: 800, height: 600, child: LuminaWidgetLayer(world: world))),
      ));
      final steps = <String>[];
      LuminaBlueprintFunctionLibrary.addToViewport(owner, widget, 0);
      await tester.pump();
      steps.add('${title['visibility']} ${find.text('Waiting').evaluate().length}');
      await tester.tap(find.text('Start'));
      await tester.pump();
      steps.add('${title['text']} ${find.text('Clicked!').evaluate().length}');
      LuminaUserWidgets.clear();
      LuminaWidgetBuilderRegistry.clear();
      return steps;
    }

    final graph = UmgWidgetCodegen.widgetGraphOf(clickerDocument(), 'WBP_Clicker')!;
    final vm = await run(LuminaBlueprintClass.forWidget(graph).instantiateUserWidget);
    final generated = await run(WbpClickerGraph.new);
    expect(generated, vm);
    expect(vm, ['Visible 1', 'Clicked! 1']);
  });

  test('migration: hand-written USER CODE of a legacy handler survives, run after the graph\'s event', () async {
    final root = Directory.systemTemp.createTempSync('umg_graph_migration_');
    addTearDown(() => root.deleteSync(recursive: true));
    final projectDir = '${root.path}/Legacy';
    Directory('$projectDir/lib/widgets').createSync(recursive: true);
    Directory('$projectDir/contents/widgets').createSync(recursive: true);
    File('$projectDir/pubspec.yaml').writeAsStringSync('name: legacy\n');
    final legacy = clickerDocument()..blueprint = null;
    final lmas = '$projectDir/contents/widgets/WBP_Clicker.lmas';
    File(lmas).writeAsBytesSync(LuminaAsset(
      assetId: 'wbp_clicker',
      name: 'WBP_Clicker',
      type: AssetType.widget,
      rawPayload: Uint8List.fromList(utf8.encode(legacy.toFormattedJson())),
    ).toProtoBufferBytes());
    // The widget as the designer generated it before graphs, with hand-written code.
    final before = UmgWidgetCodegen.generateWidgetDart(legacy, assetName: 'WBP_Clicker').replaceFirst(
        '// BEGIN USER CODE: on_clicked_startButton\n', "// BEGIN USER CODE: on_clicked_startButton\n    debugPrint('hi');\n");
    expect(before, contains("debugPrint('hi');"));
    File('$projectDir/lib/widgets/wbp_clicker.dart').writeAsStringSync(before);

    final vm = UmgEditorViewModel(assetPath: lmas);
    await vm.load();
    expect(vm.graphEditor.boundEventNode('StartButton', 'OnClicked'), isNotNull, reason: 'the recorded event appears as its bound node');
    expect(vm.hasHandWrittenCode('n_button', 'OnClicked'), isTrue);
    await vm.compile();
    expect(vm.compileError, isNull);
    final after = File('$projectDir/lib/widgets/wbp_clicker.dart').readAsStringSync();
    final handler = RegExp(r"void _onClickedStartButton\(\) \{\n    LuminaUserWidgets\.fire\(widget\.instance, 'StartButton', 'OnClicked'\);\n"
        r"    // BEGIN USER CODE: on_clicked_startButton\n    debugPrint\('hi'\);\n");
    expect(handler.hasMatch(after), isTrue, reason: after);
    expect(after, isNot(contains('ORPHANED USER CODE')));
    vm.dispose();
  });
}
