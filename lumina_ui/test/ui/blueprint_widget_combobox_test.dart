import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/event_graph.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/pin_literal_editor.dart';

void main() {
  group('Blueprint Create Widget Class Combobox', () {
    test('BlueprintEditorViewModel discovers widget classes and provides them to pinOptions', () {
      final tempDir = Directory.systemTemp.createTempSync('lumina_widget_cb_test_');
      try {
        final widgetsDir = Directory('${tempDir.path}/contents/widgets')..createSync(recursive: true);
        File('${widgetsDir.path}/WGT_HUD.lmas').writeAsStringSync('{}');
        File('${widgetsDir.path}/WBP_HealthBar.lmas').writeAsStringSync('{}');

        final vm = BlueprintEditorViewModel(
          assetPath: '${tempDir.path}/contents/blueprints/BP_Hero.lmas',
          initialAsset: LuminaAsset(assetId: 'BP_Hero', name: 'BP_Hero', type: AssetType.actor),
        );

        expect(vm.availableWidgetClasses, containsAll(['WGT_HUD', 'WBP_HealthBar']));

        final node = vm.addGraphNode('create_widget', const Offset(100, 100))!;
        final pin = vm.eventGraph.pinsOf(node).inputs.firstWhere((p) => p.id == 'class');

        final options = vm.eventGraph.pinOptions(node, pin);
        expect(options, isNotNull);
        expect(options, containsAll(['WGT_HUD', 'WBP_HealthBar']));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    testWidgets('BlueprintPinLiteralEditor renders Select when options are provided', (tester) async {
      String? committed;
      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: BlueprintPinLiteralEditor(
              keyPrefix: 'test_pin',
              type: LuminaPinType.string,
              value: 'WGT_HUD',
              options: const ['WGT_HUD', 'WBP_HUD', 'WBP_Inventory'],
              onCommit: (v) => committed = v as String?,
            ),
          ),
        ),
      );

      // Verify Select is present with WGT_HUD selected
      expect(find.byType(Select<String>), findsOneWidget);
      expect(find.text('WGT_HUD'), findsOneWidget);

      // Tap select to open popup
      await tester.tap(find.byType(Select<String>));
      await tester.pumpAndSettle();

      // Verify options are in popup
      expect(find.text('WBP_HUD'), findsOneWidget);
      expect(find.text('WBP_Inventory'), findsOneWidget);

      // Select WBP_Inventory
      await tester.tap(find.text('WBP_Inventory').last);
      await tester.pumpAndSettle();

      expect(committed, 'WBP_Inventory');
    });

    testWidgets('EventGraph renders Create Widget with combobox for Class pin', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('lumina_widget_cb_test2_');
      try {
        final widgetsDir = Directory('${tempDir.path}/contents/widgets')..createSync(recursive: true);
        File('${widgetsDir.path}/WGT_HUD.lmas').writeAsStringSync('{}');

        final vm = BlueprintEditorViewModel(
          assetPath: '${tempDir.path}/contents/blueprints/BP_Hero.lmas',
          initialAsset: LuminaAsset(assetId: 'BP_Hero', name: 'BP_Hero', type: AssetType.actor),
        );

        final node = vm.addGraphNode('create_widget', const Offset(100, 100))!;
        vm.eventGraph.setLiteral(node.id, 'class', 'WGT_HUD');

        await tester.pumpWidget(
          ShadcnApp(
            theme: luminaEditorTheme(),
            home: Scaffold(
              child: BlueprintEventGraph(
                viewModel: vm,
              ),
            ),
          ),
        );

        // Verify Create Widget node is rendered
        expect(find.text('Create Widget'), findsOneWidget);
        expect(find.text('Class'), findsOneWidget);

        // The Class pin inline editor should be a Select<String> combobox showing WGT_HUD
        expect(find.byKey(ValueKey('literal_${node.id}_class_select')), findsOneWidget);
        expect(find.text('WGT_HUD'), findsOneWidget);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
