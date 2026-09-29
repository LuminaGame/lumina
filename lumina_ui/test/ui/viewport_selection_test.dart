import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

void main() {
  group('Viewport Selection VM', () {
    test('Ctrl+click toggles selection', () {
      final vm = EditorViewModel(enableTimers: false, autoInitAssets: false);
      vm.addActorNodeForTest(EditorActorNode(id: 'actorA', name: 'A', type: 'StaticMesh', location: [0,0,0]));
      vm.addActorNodeForTest(EditorActorNode(id: 'actorB', name: 'B', type: 'StaticMesh', location: [0,0,0]));
      vm.addActorNodeForTest(EditorActorNode(id: 'actorC', name: 'C', type: 'StaticMesh', location: [0,0,0]));
      vm.selectActors(['actorA']);
      expect(vm.selectedActorIds.contains('actorA'), isTrue);
      
      vm.toggleActorSelection('actorB');
      expect(vm.selectedActorIds.contains('actorA'), isTrue);
      expect(vm.selectedActorIds.contains('actorB'), isTrue);
      expect(vm.primarySelectedActor?.id, 'actorB'); // Last selected is primary
      
      vm.toggleActorSelection('actorB');
      expect(vm.selectedActorIds.contains('actorB'), isFalse);
      expect(vm.selectedActorIds.contains('actorA'), isTrue);
    });

    test('Marquee replaces selection, shift adds', () {
      final vm = EditorViewModel(enableTimers: false, autoInitAssets: false);
      vm.addActorNodeForTest(EditorActorNode(id: 'actorA', name: 'A', type: 'StaticMesh', location: [0,0,0]));
      vm.addActorNodeForTest(EditorActorNode(id: 'actorB', name: 'B', type: 'StaticMesh', location: [0,0,0]));
      vm.addActorNodeForTest(EditorActorNode(id: 'actorC', name: 'C', type: 'StaticMesh', location: [0,0,0]));
      vm.selectActors(['actorA', 'actorB']);
      
      vm.clearSelection();
      vm.selectActors(['actorC']);
      expect(vm.selectedActorIds.contains('actorA'), isFalse);
      expect(vm.selectedActorIds.contains('actorC'), isTrue);
    });
  });
}
