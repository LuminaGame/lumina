import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/details/models/editor_component_node.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A plugin's `registerDetailsCustomization` section really
/// renders in the Details panel for its actor type, sees the actor as a
/// snapshot, and writes back through undoable view-model paths.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late EditorViewModel vm;

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumina_plugin_details_');
    vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'DetailsApi'),
      projectLocation: root.path,
      enableTimers: false,
      autoInitAssets: false,
    );
  });
  tearDown(() {
    vm.dispose();
    root.deleteSync(recursive: true);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: DetailsWidget(viewModel: vm))));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('the section shows for its type only, with the snapshot; setProperty edits component, name and transform undoably', (tester) async {
    EditorActorSnapshot? seen;
    vm.extensionRegistry.beginRegistration('pcg');
    vm.extensionRegistry.registerDetailsCustomization(DetailsCustomization(
      targetTypeId: 'PcgVolume',
      // Not 'PCG': a project editor with lumina_plugin_pcg compiled in
      // contributes a 'PCG' section for PcgVolume, and this test's section
      // must be told apart from it.
      sectionTitle: 'PCG Test',
      builder: (context, target) {
        seen = target.target as EditorActorSnapshot;
        return Column(children: [
          Text('seed ${seen!.componentOfType('LuminaPcgComponent')?.properties['seed']}', key: const Key('plugin_seed')),
          PrimaryButton(key: const Key('plugin_bump'), onPressed: () => target.setProperty('LuminaPcgComponent.seed', 99), child: const Text('Bump')),
          PrimaryButton(key: const Key('plugin_rename'), onPressed: () => target.setProperty('name', 'Renamed'), child: const Text('Rename')),
          PrimaryButton(key: const Key('plugin_move'), onPressed: () => target.setProperty('location', [10.0, 20.0, 30.0]), child: const Text('Move')),
          PrimaryButton(key: const Key('plugin_bogus'), onPressed: () => target.setProperty('nope', 1), child: const Text('Bogus')),
        ]);
      },
    ));
    vm.extensionRegistry.endRegistration();

    vm.addActorNodeForTest(EditorActorNode(
      id: 'vol',
      name: 'Volume',
      type: 'PcgVolume',
      location: [0.0, 0.0, 0.0],
      components: [EditorComponentNode(id: 'vol_c0', type: 'LuminaPcgComponent', name: 'PCG Component', properties: {'seed': 7})],
    ));
    vm.addActorNodeForTest(EditorActorNode(id: 'mesh', name: 'Barrel', type: 'StaticMesh', location: [0.0, 0.0, 0.0]));

    vm.selectActorById('mesh');
    await pump(tester);
    expect(find.text('PCG Test'), findsNothing, reason: 'a StaticMesh has no PCG section');

    vm.selectActorById('vol');
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('PCG Test'), findsOneWidget, reason: 'the section header carries the plugin title');
    expect(find.byKey(const ValueKey('details_plugin_section_PcgVolume_PCG Test')), findsOneWidget);
    expect(find.text('seed 7'), findsOneWidget);
    expect(seen!.id, 'vol');
    expect(seen!.type, 'PcgVolume');

    await tester.tap(find.byKey(const Key('plugin_bump')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(vm.actors.firstWhere((a) => a.id == 'vol').components.single.properties['seed'], 99);
    expect(find.text('seed 99'), findsOneWidget, reason: 'the section rebuilds from the new snapshot');
    expect(vm.transactions.undoLabel, 'Undo Set seed');
    vm.transactions.undo();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('seed 7'), findsOneWidget);

    await tester.tap(find.byKey(const Key('plugin_rename')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(vm.actors.firstWhere((a) => a.id == 'vol').name, 'Renamed');
    expect(vm.transactions.canUndo, isTrue);

    await tester.tap(find.byKey(const Key('plugin_move')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(vm.actors.firstWhere((a) => a.id == 'vol').location, [10.0, 20.0, 30.0]);

    await tester.tap(find.byKey(const Key('plugin_bogus')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(vm.logger.logs.last.message, contains('"nope"'));
    await tester.pumpWidget(const SizedBox());
  });
}
