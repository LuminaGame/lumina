import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/details/models/editor_component_node.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  group('Details Multi Select', () {
    testWidgets('Intersection of 2 actors', (tester) async {
      final vm = EditorViewModel(enableTimers: false);
      addTearDown(vm.dispose);
      
      vm.addActorNodeForTest(EditorActorNode(
        id: '1', name: 'A1', type: 'LuminaStaticMesh', location: [0,0,0], components: [
          EditorComponentNode(id: 'c1', type: 'LuminaMeshComponent', name: 'Mesh'),
          EditorComponentNode(id: 'c2', type: 'LuminaAudioComponent', name: 'Audio'),
      ]));
      vm.addActorNodeForTest(EditorActorNode(
        id: '2', name: 'A2', type: 'LuminaStaticMesh', location: [0,0,0], components: [
          EditorComponentNode(id: 'c3', type: 'LuminaMeshComponent', name: 'Mesh'),
      ]));
      
      vm.selectActors(['1', '2']);
      
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(child: DetailsWidget(viewModel: vm)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      
      expect(find.text('2 Actors Selected'), findsWidgets);
      expect(find.text('Mesh', skipOffstage: false), findsWidgets);
      expect(find.text('Audio', skipOffstage: false), findsNothing);
    });

    testWidgets('Mixed rendering', (tester) async {
      final vm = EditorViewModel(enableTimers: false);
      addTearDown(vm.dispose);
      
      vm.addActorNodeForTest(EditorActorNode(
        id: '1', name: 'A1', type: 'LuminaStaticMesh', location: [0,0,0], components: []
      ));
      vm.addActorNodeForTest(EditorActorNode(
        id: '2', name: 'A2', type: 'LuminaStaticMesh', location: [50,0,0], components: []
      ));
      
      vm.selectActors(['1', '2']);
      
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(child: DetailsWidget(viewModel: vm)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      
      expect(find.text('2 Actors Selected'), findsWidgets);
      expect(find.text('—', skipOffstage: false), findsWidgets); // Mixed dash for X
      expect(find.text('0.00', skipOffstage: false), findsWidgets); // Y and Z are common
    });
  });
}
