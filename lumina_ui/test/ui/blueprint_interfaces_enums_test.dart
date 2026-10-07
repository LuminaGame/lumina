import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show Offset, Size, ValueKey;
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_palette.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_asset_catalog.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_enum_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_interface_view_model.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint_enum/enum_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint_interface/interface_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show ShadcnApp, Scaffold;

import '../helpers/blueprint_test_project.dart';

/// Enumeration and Blueprint Interface assets on a real
/// project, and what they add to a Blueprint's palette.
void main() {
  late BlueprintTestProject project;

  setUpAll(() => project = BlueprintTestProject.create());
  tearDownAll(() => project.dispose());
  tearDown(() {
    LuminaBlueprintEnums.clear();
    LuminaBlueprintInterfaces.clear();
  });

  test('New Enumeration E_DoorState saves contents/enums/E_DoorState.lmas; Switch on E_DoorState shows its cases; reorder keeps wires by name', () async {
    final rel = BlueprintAssetCatalog.writeEnum(project.dir, const LuminaBlueprintEnumDocument(name: 'E_DoorState'));
    expect(rel, 'contents/enums/E_DoorState.lmas');
    final path = '${project.dir}/$rel';
    expect(BlueprintAssetCatalog.isEnumLmas(path), isTrue);
    expect(LuminaAsset.fromBytes(File(path).readAsBytesSync()).type, AssetType.actor, reason: 'the payload kind tells enums apart');

    final enumVm = BlueprintEnumViewModel(assetPath: path);
    await enumVm.load();
    expect(enumVm.name, 'E_DoorState');
    enumVm.addValue('Closed');
    enumVm.addValue('Opening');
    enumVm.addValue('Open');
    expect(enumVm.values, ['Closed', 'Opening', 'Open']);
    expect(enumVm.renameValue(2, 'Closed'), isFalse, reason: 'names are unique');
    expect(await enumVm.save(), isTrue);
    expect(BlueprintAssetCatalog.readEnum(path)!.values, ['Closed', 'Opening', 'Open']);

    // A Blueprint sees the enum: Switch on E_DoorState with three exec outs.
    final vm = BlueprintEditorViewModel(assetPath: project.createBlueprint('BP_Door', parentClass: 'LuminaActor'));
    await vm.load();
    expect(vm.projectEnums.map((e) => e.name), ['E_DoorState']);
    final row = vm.eventGraph.paletteEntries().singleWhere((e) => e.key == 'switch_on_enum_E_DoorState');
    expect(row.title, 'Switch on E_DoorState');
    final sw = vm.eventGraph.placeEntry(row, Offset.zero)!;
    expect(vm.eventGraph.pinsOf(sw).outputs.map((p) => p.name), ['Closed', 'Opening', 'Open']);
    final literal = vm.eventGraph.placeEntry(vm.eventGraph.paletteEntries().singleWhere((e) => e.key == 'enum_literal_E_DoorState'), Offset.zero)!;
    expect(vm.eventGraph.pinOptions(literal, vm.eventGraph.pinsOf(literal).outputs.single), ['Closed', 'Opening', 'Open']);
    expect(vm.eventGraph.pinOptions(sw, vm.eventGraph.pinsOf(sw).inputs.last), ['Closed', 'Opening', 'Open'], reason: 'an enum literal shows its values');
    expect(vm.eventGraph.whyNotConnect(literal.id, 'return_value', sw.id, 'selection'), isNull);
    final a = vm.addGraphNode('print_string', const Offset(300, 0), literals: {'in_string': 'closed'})!;
    final b = vm.addGraphNode('print_string', const Offset(300, 200), literals: {'in_string': 'open'})!;
    vm.addGraphWire(fromNodeId: sw.id, fromPinId: 'case_0', toNodeId: a.id, toPinId: 'exec_in');
    vm.addGraphWire(fromNodeId: sw.id, fromPinId: 'case_2', toNodeId: b.id, toPinId: 'exec_in');
    expect(await vm.save(), isTrue);
    vm.dispose();

    // Reorder Open to the front: the saved Blueprint's wires follow the names.
    expect(enumVm.moveValue(2, 0), isTrue);
    expect(enumVm.values, ['Open', 'Closed', 'Opening']);
    expect(await enumVm.save(), isTrue);
    final doc = readBlueprint('${project.dir}/contents/blueprints/BP_Door.lmas');
    String? caseInto(String nodeId) => doc.eventGraph.wires.where((w) => w.toNodeId == nodeId).single.fromPinId;
    expect(caseInto(a.id), 'case_1', reason: 'Closed is now second');
    expect(caseInto(b.id), 'case_0', reason: 'Open is now first');
    expect(doc.eventGraph.node(sw.id)!.outputs.map((p) => p.name), ['Open', 'Closed', 'Opening']);
  });

  test('New Blueprint Interface BPI_Interactable with Interact(); implementing it lists Event Interact; a Message node fits any object pin', () async {
    final rel = BlueprintAssetCatalog.writeInterface(project.dir, const LuminaBlueprintInterfaceDocument(name: 'BPI_Interactable'));
    expect(rel, 'contents/interfaces/BPI_Interactable.lmas');
    final path = '${project.dir}/$rel';
    expect(BlueprintAssetCatalog.isInterfaceLmas(path), isTrue);
    final ifaceVm = BlueprintInterfaceViewModel(assetPath: path);
    await ifaceVm.load();
    expect(ifaceVm.addFunction('Interact'), 'Interact');
    expect(ifaceVm.addParameter('Interact', output: false, parameter: 'Instigator', type: 'Actor:LuminaActor'), 'Instigator');
    expect(ifaceVm.isDirty, isTrue);
    expect(await ifaceVm.save(), isTrue);
    expect(BlueprintAssetCatalog.readInterface(path)!.function('Interact')!.inputs.single.name, 'Instigator');

    final vm = BlueprintEditorViewModel(assetPath: project.createBlueprint('BP_Chest', parentClass: 'LuminaActor'));
    await vm.load();
    expect(vm.projectInterfaces.map((i) => i.name), ['BPI_Interactable']);
    List<String> keys() => vm.eventGraph.paletteEntries().map((e) => e.key).toList();
    expect(keys(), contains('interface_message_BPI_Interactable_Interact'), reason: 'the Message node is always offered');
    expect(keys(), isNot(contains('event_interface_function_BPI_Interactable_Interact')), reason: 'not implemented yet');
    expect(vm.addInterface('BPI_Interactable'), isTrue);
    expect(vm.document.interfaces, ['BPI_Interactable']);
    expect(keys(), contains('event_interface_function_BPI_Interactable_Interact'));
    final event = vm.eventGraph.placeEntry(
        vm.eventGraph.paletteEntries().singleWhere((e) => e.key == 'event_interface_function_BPI_Interactable_Interact'), Offset.zero)!;
    expect(vm.eventGraph.pinsOf(event).outputs.map((p) => p.id), ['exec_out', 'Instigator']);

    // The Message node connects from any object pin.
    final pawn = vm.addGraphNode('get_player_pawn', const Offset(0, 300))!;
    final out = vm.eventGraph.pin(pawn.id, 'return_value', output: true)!;
    final fromPawn = vm.eventGraph.paletteEntriesFor(
        BlueprintPinRef.of(pawn.id, out, isOutput: true));
    expect(fromPawn.map((e) => e.key), contains('interface_message_BPI_Interactable_Interact'));
    final message = vm.eventGraph.placeEntry(fromPawn.singleWhere((e) => e.key == 'interface_message_BPI_Interactable_Interact'), const Offset(300, 300),
        from: BlueprintPinRef.of(pawn.id, out, isOutput: true))!;
    expect(vm.graphWires.any((w) => w.fromNodeId == pawn.id && w.toNodeId == message.id && w.toPinId == 'target'), isTrue);
    expect(await vm.compile(), isTrue, reason: '${vm.diagnostics}');
    expect(vm.removeInterface('BPI_Interactable'), isTrue);
    expect(vm.getGraphNode(event.id), isNull, reason: 'its events go with it');
    expect(vm.getGraphNode(message.id), isNotNull);
    vm.dispose();
  });

  testWidgets('the Enumeration and Blueprint Interface editors add, reorder and save from their buttons', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final enumPath = '${project.dir}/${BlueprintAssetCatalog.writeEnum(project.dir, const LuminaBlueprintEnumDocument(name: 'E_Weather'))}';
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: BlueprintEnumSubEditor(assetName: 'E_Weather', assetPath: enumPath)),
    ));
    await tester.pump();
    final enumState = tester.state<BlueprintEnumSubEditorState>(find.byType(BlueprintEnumSubEditor));
    await tester.tap(find.byKey(const ValueKey('enum_add_value')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('enum_add_value')));
    await tester.pump();
    expect(enumState.viewModel.values, ['NewEnumerator0', 'NewEnumerator1']);
    await tester.tap(find.byKey(const ValueKey('enum_up_NewEnumerator1')));
    await tester.pump();
    expect(enumState.viewModel.values, ['NewEnumerator1', 'NewEnumerator0']);
    await tester.tap(find.byKey(const ValueKey('enum_save')));
    await tester.pump();
    expect(BlueprintAssetCatalog.readEnum(enumPath)!.values, ['NewEnumerator1', 'NewEnumerator0']);

    final ifacePath = '${project.dir}/${BlueprintAssetCatalog.writeInterface(project.dir, const LuminaBlueprintInterfaceDocument(name: 'BPI_Damageable'))}';
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: BlueprintInterfaceSubEditor(assetName: 'BPI_Damageable', assetPath: ifacePath)),
    ));
    await tester.pump();
    final ifaceState = tester.state<BlueprintInterfaceSubEditorState>(find.byType(BlueprintInterfaceSubEditor));
    await tester.tap(find.byKey(const ValueKey('iface_add_function')));
    await tester.pump();
    expect(find.byKey(const ValueKey('iface_signature_NewFunction')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('iface_input_add')));
    await tester.pump();
    expect(ifaceState.viewModel.function('NewFunction')!.inputs.single.name, 'NewParam');
    await tester.tap(find.byKey(const ValueKey('iface_save')));
    await tester.pump();
    expect(BlueprintAssetCatalog.readInterface(ifacePath)!.function('NewFunction')!.inputs.single.name, 'NewParam');
  });

  test('a play_sound_2d sound pin lists the project sounds; is_input_key_down offers the engine key list', () async {
    final audio = LuminaAsset(assetId: 'snd_click', name: 'S_Click', type: AssetType.audio);
    final file = File('${project.dir}/contents/audio/S_Click.lmas')..parent.createSync(recursive: true);
    file.writeAsBytesSync(audio.toProtoBufferBytes());
    final vm = BlueprintEditorViewModel(assetPath: project.createBlueprint('BP_Sounds', parentClass: 'LuminaActor'));
    await vm.load();
    expect(vm.assetCatalog!.assetPaths(BlueprintAssetKind.sound), contains('contents/audio/S_Click.lmas'));
    final sound = vm.addGraphNode('play_sound_2d', Offset.zero)!;
    final soundPin = vm.eventGraph.pinsOf(sound).inputs.firstWhere((p) => p.id == 'sound');
    expect(vm.eventGraph.pinOptions(sound, soundPin), contains('contents/audio/S_Click.lmas'));
    vm.setPinLiteral(sound.id, 'sound', 'contents/audio/S_Click.lmas');
    expect(vm.getGraphNode(sound.id)!.literals['sound'], 'contents/audio/S_Click.lmas');
    final key = vm.addGraphNode('is_input_key_down', Offset.zero)!;
    final keyPin = vm.eventGraph.pinsOf(key).inputs.firstWhere((p) => p.id == 'key');
    expect(vm.eventGraph.pinOptions(key, keyPin), containsAll(['KeyW', 'KeySpace', 'MouseLeft', 'GamepadFaceButtonBottom']));
    final print = vm.addGraphNode('print_string', Offset.zero)!;
    final printKey = vm.eventGraph.pinsOf(print).inputs.firstWhere((p) => p.id == 'key');
    expect(vm.eventGraph.pinOptions(print, printKey), isNull, reason: 'Print String\'s key is a free name');
    vm.dispose();
  });
}
