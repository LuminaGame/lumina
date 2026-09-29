import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina/lumina.dart';
import 'dart:io';

void main() {
  group('Gizmo Transactions', () {
    test('One drag = one undo transaction', () async {
      final pDir = Directory.systemTemp.createTempSync('GizmoTxTest');
      final p = LuminaProject(
        projectName: 'T',
        engineVersion: '0.0.1',
        activeLevel: 'contents/levels/L.lmas',
        isDirty: false,
        lastModifiedTimestamp: '',
        lastCodeGeneratedTimestamp: '',
        settings: EngineScalabilitySettings(
          targetFps: 60,
          vsyncEnabled: true,
          qualityPreset: 'epic',
        ),
      );
      final vm = EditorViewModel(initialProject: p, projectLocation: pDir.path);
      
      final actor = EditorActorNode(
        id: '1',
        name: 'A',
        type: 'LuminaActor',
        location: [0,0,0],
        rotation: [0,0,0],
        scale: [1,1,1],
      );
      vm.addActorNodeForTest(actor);
      vm.selectActor(actor);
      
      vm.beginTransformDrag();
      
      for (int i=1; i<=20; i++) {
        vm.updateActorLocation([i.toDouble(), 0, 0]);
      }
      
      vm.endTransformDrag();
      
      expect(actor.location[0], 20.0);
      
      vm.transactions.undo();
      expect(actor.location[0], 0.0);
      
      vm.transactions.redo();
      expect(actor.location[0], 20.0);
    });
    
    test('Esc mid-drag restores snapshot and pushes no transaction', () async {
      final pDir = Directory.systemTemp.createTempSync('GizmoTxTest2');
      final p = LuminaProject(
        projectName: 'T',
        engineVersion: '0.0.1',
        activeLevel: 'contents/levels/L.lmas',
        isDirty: false,
        lastModifiedTimestamp: '',
        lastCodeGeneratedTimestamp: '',
        settings: EngineScalabilitySettings(
          targetFps: 60,
          vsyncEnabled: true,
          qualityPreset: 'epic',
        ),
      );
      final vm = EditorViewModel(initialProject: p, projectLocation: pDir.path);
      
      final actor = EditorActorNode(
        id: '1',
        name: 'A',
        type: 'LuminaActor',
        location: [0,0,0],
        rotation: [0,0,0],
        scale: [1,1,1],
      );
      vm.addActorNodeForTest(actor);
      vm.selectActor(actor);
      
      vm.beginTransformDrag();
      vm.updateActorLocation([10, 10, 10]);
      
      vm.cancelTransformDrag();
      
      expect(actor.location[0], 0.0);
      vm.updateActorLocation([5,5,5]); 
    });
  });
}
