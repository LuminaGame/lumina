import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bp_graph_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Blueprint Graph Document & ViewModel Tests', () {
    test('addNode spawns node from registry with correct pins and position', () {
      final vm = BlueprintEditorViewModel(
        assetPath: '${tempDir.path}/BP_Graph.lmas',
        initialAsset: LuminaAsset(assetId: 'BP_Graph', name: 'BP_Graph', type: AssetType.actor),
      );

      final branch = vm.addGraphNode('branch', const Offset(200, 150));
      expect(branch, isNotNull);
      expect(branch!.title, equals('Branch'));
      expect(Offset(branch.x, branch.y), equals(const Offset(200, 150)));
      expect(branch.inputs.any((p) => p.id == 'condition' && p.type == LuminaPinType.boolean), isTrue);
      expect(branch.outputs.any((p) => p.id == 'true_out' && p.type == LuminaPinType.exec), isTrue);
    });

    test('addWire validates pin compatibility, enforces single-connection rules', () {
      final vm = BlueprintEditorViewModel(
        assetPath: '${tempDir.path}/BP_Graph.lmas',
        initialAsset: LuminaAsset(assetId: 'BP_Graph', name: 'BP_Graph', type: AssetType.actor),
      );

      final beginPlay = vm.addGraphNode('event_beginplay', const Offset(50, 50))!;
      final print1 = vm.addGraphNode('print_string', const Offset(300, 50))!;
      final print2 = vm.addGraphNode('print_string', const Offset(300, 200))!;

      // 1. Valid exec connection
      final wire1 = vm.addGraphWire(
        fromNodeId: beginPlay.id,
        fromPinId: 'exec_out',
        toNodeId: print1.id,
        toPinId: 'exec_in',
      );
      expect(wire1, isNotNull);
      expect(vm.graphWires.length, equals(1));

      // 2. Incompatible connection (Exec -> Data in_string) rejected
      final invalidWire = vm.addGraphWire(
        fromNodeId: beginPlay.id,
        fromPinId: 'exec_out',
        toNodeId: print1.id,
        toPinId: 'in_string',
      );
      expect(invalidWire, isNull);
      expect(vm.graphWires.length, equals(1));

      // 3. Single-connection rule for exec_out: connecting to print2 replaces wire1
      final wire2 = vm.addGraphWire(
        fromNodeId: beginPlay.id,
        fromPinId: 'exec_out',
        toNodeId: print2.id,
        toPinId: 'exec_in',
      );
      expect(wire2, isNotNull);
      expect(vm.graphWires.length, equals(1));
      expect(vm.graphWires.first.toNodeId, equals(print2.id));
    });

    test('Data typing: Float connects to Float but rejected by Vector3', () {
      final vm = BlueprintEditorViewModel(
        assetPath: '${tempDir.path}/BP_Graph.lmas',
        initialAsset: LuminaAsset(assetId: 'BP_Graph', name: 'BP_Graph', type: AssetType.actor),
      );

      final tick = vm.addGraphNode('event_tick', const Offset(50, 50))!;
      final move = vm.addGraphNode('add_movement_input', const Offset(300, 50))!;

      // Float (delta_seconds) -> Float (scale_val) succeeds
      final floatWire = vm.addGraphWire(
        fromNodeId: tick.id,
        fromPinId: 'delta_seconds',
        toNodeId: move.id,
        toPinId: 'scale_val',
      );
      expect(floatWire, isNotNull);

      // Float (delta_seconds) -> Vector3 (world_dir) fails
      final vecWire = vm.addGraphWire(
        fromNodeId: tick.id,
        fromPinId: 'delta_seconds',
        toNodeId: move.id,
        toPinId: 'world_dir',
      );
      expect(vecWire, isNull);
    });

    test('setPinLiteral stores and persists inline pin literal values', () async {
      final file = File('${tempDir.path}/BP_Literals.lmas');
      final asset = LuminaAsset(assetId: 'BP_Literals', name: 'BP_Literals', type: AssetType.actor);
      await file.writeAsBytes(asset.toProtoBufferBytes());

      final vm = BlueprintEditorViewModel(assetPath: file.path, initialAsset: asset);
      final move = vm.addGraphNode('add_movement_input', const Offset(200, 100))!;

      vm.setPinLiteral(move.id, 'world_dir', [0.0, 0.0, 1.0]);
      expect(vm.getGraphNode(move.id)!.literals['world_dir'], equals([0.0, 0.0, 1.0]));

      await vm.save();

      // Read back from disk
      final loadedBytes = await file.readAsBytes();
      final loadedAsset = LuminaAsset.fromBytes(loadedBytes);
      final loadedDoc = LuminaBlueprintDocument.fromJson(jsonDecode(utf8.decode(loadedAsset.rawPayload!)));

      final loadedMove = loadedDoc.eventGraph.node(move.id)!;
      expect(loadedMove.literals['world_dir'], equals([0.0, 0.0, 1.0]));
    });

    test('Serialization round-trip: 5 nodes and wires survive save/reload', () async {
      final file = File('${tempDir.path}/BP_Complex.lmas');
      final asset = LuminaAsset(assetId: 'BP_Complex', name: 'BP_Complex', type: AssetType.actor);
      await file.writeAsBytes(asset.toProtoBufferBytes());

      final vm1 = BlueprintEditorViewModel(assetPath: file.path, initialAsset: asset);
      final n1 = vm1.addGraphNode('event_beginplay', const Offset(10, 10))!;
      final n2 = vm1.addGraphNode('branch', const Offset(150, 10))!;
      final n3 = vm1.addGraphNode('print_string', const Offset(300, 10))!;
      final n4 = vm1.addGraphNode('event_tick', const Offset(10, 200))!;
      final n5 = vm1.addGraphNode('add_movement_input', const Offset(250, 200))!;

      vm1.addGraphWire(fromNodeId: n1.id, fromPinId: 'exec_out', toNodeId: n2.id, toPinId: 'exec_in');
      vm1.addGraphWire(fromNodeId: n2.id, fromPinId: 'true_out', toNodeId: n3.id, toPinId: 'exec_in');
      vm1.addGraphWire(fromNodeId: n4.id, fromPinId: 'exec_tick_out', toNodeId: n5.id, toPinId: 'exec_move_in');
      vm1.addGraphWire(fromNodeId: n4.id, fromPinId: 'delta_seconds', toNodeId: n5.id, toPinId: 'scale_val');

      await vm1.save();

      // Reload into new VM instance
      final vm2 = BlueprintEditorViewModel(assetPath: file.path);
      await vm2.load();

      expect(vm2.graphNodes.length, equals(5));
      expect(vm2.graphWires.length, equals(4));
      expect(vm2.getGraphNode(n2.id)?.title, equals('Branch'));
    });
  });
}
