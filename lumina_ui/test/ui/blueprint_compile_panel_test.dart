import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  late Directory tempProject;

  setUp(() {
    tempProject = Directory.systemTemp.createTempSync('compile_panel_test_');
    Directory('${tempProject.path}/lib/actors').createSync(recursive: true);
    File('${tempProject.path}/my_project.lmproject').writeAsStringSync('{}');
  });

  tearDown(() {
    if (tempProject.existsSync()) {
      tempProject.deleteSync(recursive: true);
    }
  });

  testWidgets('BlueprintSubEditor renders live generated Dart code and compile action', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final assetFile = File('${tempProject.path}/contents/blueprints/BP_Hero.lmas');
    assetFile.parent.createSync(recursive: true);

    final vm = BlueprintEditorViewModel(
      assetPath: assetFile.path,
      initialAsset: LuminaAsset(assetId: 'BP_Hero', name: 'BP_Hero', type: AssetType.actor),
    );

    vm.addComponent('LuminaCapsuleComponent')!;
    final beginPlay = vm.addGraphNode('event_beginplay', const Offset(40, 40))!;
    final printString = vm.addGraphNode('print_string', const Offset(260, 40))!;
    vm.addGraphWire(fromNodeId: beginPlay.id, fromPinId: 'exec_out', toNodeId: printString.id, toPinId: 'exec_in');

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: BlueprintSubEditor(
            assetName: 'BP_Hero',
            assetPath: assetFile.path,
            viewModel: vm,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('BLUEPRINT ACTOR'), findsOneWidget);
    expect(find.text('Compile'), findsOneWidget);

    // Live code preview contains real class name
    expect(find.textContaining('class BpHero extends LuminaActor'), findsOneWidget);

    // Execute compile via tester.runAsync for real filesystem I/O
    await tester.runAsync(() async {
      await vm.compile();
    });
    await tester.pump(const Duration(milliseconds: 100));

    final generatedFile = File('${tempProject.path}/lib/actors/bp_hero.dart');
    expect(generatedFile.existsSync(), isTrue);
    expect(generatedFile.readAsStringSync(), contains('class BpHero extends LuminaActor'));
    expect(generatedFile.readAsStringSync(), contains('void onBeginPlay()'));
  });
}
