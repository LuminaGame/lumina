import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/details/services/multi_edit_service.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/details/models/editor_component_node.dart';

void main() {
  group('MultiEditService', () {
    test('Empty selection returns default common view', () {
      final view = MultiEditService.computeMultiEditView([]);
      expect(view.locationMixed, [false, false, false]);
    });

    test('Intersection logic finds common components', () {
      final a1 = EditorActorNode(id: '1', name: 'A1', type: 't', location: [0,0,0], components: [
        EditorComponentNode(id: 'c1', type: 'LuminaMeshComponent', name: 'Mesh'),
        EditorComponentNode(id: 'c2', type: 'LuminaAudioComponent', name: 'Audio'),
      ]);
      final a2 = EditorActorNode(id: '2', name: 'A2', type: 't', location: [0,0,0], components: [
        EditorComponentNode(id: 'c3', type: 'LuminaMeshComponent', name: 'Mesh'),
      ]);
      
      final view = MultiEditService.computeMultiEditView([a1, a2]);
      expect(view.components.length, 1);
      expect(view.components.first.componentType, 'LuminaMeshComponent');
    });

    test('Mixed value detection works per-axis for Transform', () {
      final a1 = EditorActorNode(id: '1', name: 'A1', type: 't', location: [0,0,0], components: []);
      final a2 = EditorActorNode(id: '2', name: 'A2', type: 't', location: [50,0,0], components: []);
      
      final view = MultiEditService.computeMultiEditView([a1, a2]);
      expect(view.locationMixed, [true, false, false]);
      expect(view.locationCommon[1], 0.0);
    });
    
    test('Double precision jitter is ignored (1e-6)', () {
      final a1 = EditorActorNode(id: '1', name: 'A1', type: 't', location: [1.0, 0, 0], components: []);
      final a2 = EditorActorNode(id: '2', name: 'A2', type: 't', location: [1.0000001, 0, 0], components: []);
      
      final view = MultiEditService.computeMultiEditView([a1, a2]);
      expect(view.locationMixed, [false, false, false]);
    });
  });
}
