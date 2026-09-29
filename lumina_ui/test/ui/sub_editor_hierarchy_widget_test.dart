import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_hierarchy_widget.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/static_mesh_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/static_mesh_editor_view_model.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  group('SubEditorHierarchyWidget Tests', () {
    final testNodes = [
      GlbNode(
        index: 0,
        name: 'AttackHelicopter.entity',
        type: GlbNodeType.group,
        children: [
          GlbNode(
            index: 1,
            name: 'ClientOnly',
            type: GlbNodeType.group,
            children: [
              GlbNode(
                index: 2,
                name: 'AHMissilePod_Left',
                type: GlbNodeType.group,
                children: [
                  GlbNode(index: 3, name: 'MissilePod_LOD0_1', type: GlbNodeType.mesh, meshIndex: 0),
                ],
              ),
              GlbNode(
                index: 4,
                name: 'AttackHeli_skinned',
                type: GlbNodeType.bone,
                children: [
                  GlbNode(index: 5, name: 'AttackHelicopter_LOD0', type: GlbNodeType.mesh, meshIndex: 1),
                  GlbNode(index: 6, name: 'RearRotor_LOD0', type: GlbNodeType.mesh, meshIndex: 2),
                ],
              ),
            ],
          ),
          GlbNode(
            index: 7,
            name: 'ServerOnly',
            type: GlbNodeType.group,
            children: [
              GlbNode(index: 8, name: 'turret_attackheli', type: GlbNodeType.group),
            ],
          ),
        ],
      ),
    ];

    testWidgets('Should render Hierarchy tree with nodes, counts, and search filter', (WidgetTester tester) async {
      GlbNode? selected;

      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: SizedBox(
              width: 300,
              height: 600,
              child: SubEditorHierarchyWidget(
                rootNodes: testNodes,
                onNodeSelected: (n) => selected = n,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Hierarchy'), findsOneWidget);
      expect(find.text('AttackHelicopter.entity'), findsOneWidget);
      expect(find.text('ClientOnly'), findsOneWidget);
      expect(find.text('AHMissilePod_Left'), findsOneWidget);
      expect(find.text('AttackHeli_skinned'), findsOneWidget);

      // Tap on node to select
      await tester.tap(find.text('AHMissilePod_Left'));
      await tester.pump();
      expect(selected?.name, equals('AHMissilePod_Left'));

      // Test Search filtering
      await tester.enterText(find.byType(TextField), 'Rotor');
      await tester.pump();

      expect(find.text('RearRotor_LOD0'), findsOneWidget);
      expect(find.text('AHMissilePod_Left'), findsNothing);
    });

    testWidgets('Should toggle node visibility when eye icon is clicked', (WidgetTester tester) async {
      GlbNode? toggledNode;
      bool? isVis;

      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: SizedBox(
              width: 300,
              height: 600,
              child: SubEditorHierarchyWidget(
                rootNodes: testNodes,
                onNodeVisibilityChanged: (node, visible) {
                  toggledNode = node;
                  isVis = visible;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Find eye icon and tap it
      final eyeFinder = find.byIcon(LucideIcons.eye);
      expect(eyeFinder, findsWidgets);

      await tester.tap(eyeFinder.first);
      await tester.pump();

      expect(toggledNode, isNotNull);
      expect(isVis, isFalse);
    });

    testWidgets('StaticMeshSubEditor should render 3-pane layout with Hierarchy, Viewport, and Inspector', (WidgetTester tester) async {
      final fixture = '${Directory.current.parent.path}/test-assets/fixtures/attackhelicopter.entity.glb';
      final mesh = await tester.runAsync(() => AssetRepository.loadMeshFromDisk(fixture));
      expect(mesh, isNotNull, reason: 'real fixture must parse');
      final vm = StaticMeshEditorViewModel(assetPath: fixture, initialGlbMesh: mesh);
      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: SizedBox(
              width: 1200,
              height: 700,
              child: StaticMeshSubEditor(
                assetName: 'attackhelicopter.entity.glb',
                viewModel: vm,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('STATIC MESH'), findsOneWidget);
      expect(find.text('attackhelicopter.entity.glb'), findsOneWidget);
      expect(find.text('MESH STATISTICS'), findsOneWidget);
      expect(find.text('Hierarchy'), findsWidgets);
    });
  });
}
