import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/details/models/component_property_registry.dart';
import 'package:lumina_ui/ui/features/details/models/editor_component_node.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  group('Details Inspector', () {
    testWidgets('Selecting an actor with a CharacterMovement + Capsule component renders exactly those sections', (tester) async {
      final vm = EditorViewModel(enableTimers: false);
      addTearDown(vm.dispose);
      
      final actor = EditorActorNode(
        id: 'act_test',
        name: 'PlayerPawn',
        type: 'LuminaPawn',
        location: [0.0,0.0,0.0],
        components: []
      );
      
      actor.components.add(EditorComponentNode(id: 'c1', type: 'LuminaCharacterMovementComponent', name: 'Movement'));
      actor.components.add(EditorComponentNode(id: 'c2', type: 'LuminaCapsuleComponent', name: 'Capsule'));
      
      vm.addActorNodeForTest(actor);
      vm.selectActorById('act_test');
      
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: DetailsWidget(viewModel: vm),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      
      expect(find.text('Movement', skipOffstage: false), findsWidgets);
      expect(find.text('Capsule', skipOffstage: false), findsWidgets);
      
      // Sections
      expect(find.text('Character Movement: Walking', skipOffstage: false), findsWidgets);
      expect(find.text('Shape', skipOffstage: false), findsWidgets);
      
      // A property
      expect(find.text('Max Walk Speed', skipOffstage: false), findsWidgets);
      expect(find.text('Capsule Half Height', skipOffstage: false), findsWidgets);
    });
  });
}
