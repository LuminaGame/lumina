import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/data/models/lumina_asset.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/event_graph.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/graph_canvas.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  testWidgets('BlueprintEventGraph renders nodes, pins, and search palette', (tester) async {
    final vm = BlueprintEditorViewModel(
      assetPath: 'contents/blueprints/BP_Hero.lmas',
      initialAsset: LuminaAsset(assetId: 'BP_Hero', name: 'BP_Hero', type: AssetType.actor),
    );

    final begin = vm.addGraphNode('event_beginplay', const Offset(40, 40))!;
    final print = vm.addGraphNode('print_string', const Offset(260, 40))!;

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

    expect(find.text('Event BeginPlay'), findsOneWidget);
    expect(find.text('Print String'), findsOneWidget);
    // Exec pins are drawn unlabelled; data pins carry names.
    expect(find.byKey(ValueKey('pin_${begin.id}_exec_out_out')), findsOneWidget);
    expect(find.byKey(ValueKey('pin_${print.id}_exec_in_in')), findsOneWidget);
    expect(find.text('In String'), findsOneWidget);

    // Open palette
    final state = tester.state<BlueprintGraphCanvasState>(find.byType(BlueprintGraphCanvas));
    state.openNodePalette(const Offset(100, 100));
    await tester.pumpAndSettle();

    expect(find.text('Node Palette'), findsOneWidget);
    expect(find.text('Search nodes...'), findsOneWidget);
  });
}
