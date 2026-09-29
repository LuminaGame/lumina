import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';


void main() {
  late Directory tempDir;
  late EditorViewModel vm;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_folders_test_');
    final p = LuminaProject(projectName: 'TestProject');
    vm = EditorViewModel(initialProject: p, projectLocation: tempDir.path);
  });

  tearDown(() {
    vm.dispose();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('Folder persistence on a real temp project', () async {
    await vm.ensureDefaultLevelAssets();
    
    // Spawn Folder
    vm.spawnNewActor('Folder');
    final folderId = vm.actors.last.id;
    vm.renameActorWithTransaction(folderId, 'Lighting');
    
    // Move actors into folder
    final dirLight = vm.actors.firstWhere((a) => a.name == 'DirectionalLight_Sun').id;
    vm.reparentActorWithTransaction(dirLight, folderId);
    
    // Save level
    await vm.saveLevelAndGenerateCode();
    
    // Reload in a fresh VM
    final p = LuminaProject(projectName: 'TestProject');
    final vm2 = EditorViewModel(initialProject: p, projectLocation: tempDir.path);
    await vm2.ensureDefaultLevelAssets();
    
    final reloadedFolder = vm2.actors.firstWhere((a) => a.id == folderId);
    expect(reloadedFolder.type, 'Folder');
    expect(reloadedFolder.name, 'Lighting');
    
    final reloadedLight = vm2.actors.firstWhere((a) => a.id == dirLight);
    expect(reloadedLight.parentId, folderId);
    
    vm2.dispose();
  });
  
  test('Codegen skips folders', () async {
    await vm.ensureDefaultLevelAssets();
    vm.spawnNewActor('Folder');
    final folderId = vm.actors.last.id;
    vm.renameActorWithTransaction(folderId, 'Lighting');
    final dirLight = vm.actors.firstWhere((a) => a.name == 'DirectionalLight_Sun').id;
    vm.reparentActorWithTransaction(dirLight, folderId);
    
    await vm.saveLevelAndGenerateCode();
    
    final file = File('${tempDir.path}/TestProject/lib/levels/l_default_level.dart');
    expect(file.existsSync(), true);
    final code = file.readAsStringSync();
    
    expect(code.contains('Lighting'), false);
    expect(code.contains('Folder'), false);
    expect(code.contains('DirectionalLight_Sun'), true);
  });
  
  test('Codegen keeps actors nested folder-in-folder',() async {
    await vm.ensureDefaultLevelAssets();
    vm.spawnNewActor('Folder');
    final outer = vm.actors.last.id;
    vm.renameActorWithTransaction(outer, 'World');
    vm.spawnNewActor('Folder', parentId: outer);
    final inner = vm.actors.last.id;
    vm.renameActorWithTransaction(inner, 'Lighting');
    final sun = vm.actors.firstWhere((a) => a.name == 'DirectionalLight_Sun').id;
    vm.reparentActorWithTransaction(sun, inner);

    await vm.saveLevelAndGenerateCode();
    final code = File('${tempDir.path}/TestProject/lib/levels/l_default_level.dart').readAsStringSync();
    expect(code.contains('DirectionalLight_Sun'), true);
    expect(code.contains('LuminaDirectionalLightComponent('), true, reason: 'the light is a typed runtime component');
    expect(code.contains('// World'), false);
    expect(code.contains('// Lighting'), false);
  });

  test('setActorVisibility fires listeners, dirties project, and persists', () async {
    await vm.ensureDefaultLevelAssets();
    final childId = vm.actors.firstWhere((a) => a.name == 'DirectionalLight_Sun').id;
    
    var notified = false;
    vm.addListener(() => notified = true);
    
    vm.setActorVisibilityWithTransaction(childId, false);
    
    expect(notified, true);
    expect(vm.project.isDirty, true);
    expect(vm.hiddenActorCount, 1);
    
    await vm.saveLevelAndGenerateCode();
    final p = LuminaProject(projectName: 'TestProject');
    final vm2 = EditorViewModel(initialProject: p, projectLocation: tempDir.path);
    await vm2.ensureDefaultLevelAssets();
    
    expect(vm2.actors.firstWhere((a) => a.id == childId).isVisible, false);
    vm2.dispose();
  });
  
  test('Folder eye cascade and solo', () async {
    await vm.ensureDefaultLevelAssets();
    
    vm.spawnNewActor('Folder');
    final folderId = vm.actors.last.id;
    
    final child1 = vm.actors.firstWhere((a) => a.name == 'DirectionalLight_Sun').id;
    final child2 = vm.actors.firstWhere((a) => a.name == 'SkyAtmosphere_Env').id;
    vm.reparentActorWithTransaction(child1, folderId);
    vm.reparentActorWithTransaction(child2, folderId);
    
    // Hide one child manually
    vm.setActorVisibilityWithTransaction(child2, false);
    
    // Hide folder -> hides descendant
    vm.setActorVisibilityWithTransaction(folderId, false, recursive: true);
    expect(vm.actors.firstWhere((a) => a.id == folderId).isVisible, false);
    expect(vm.actors.firstWhere((a) => a.id == child1).isVisible, false);
    expect(vm.actors.firstWhere((a) => a.id == child2).isVisible, false);
    
    // Show folder -> restores child1, but child2 remains hidden? No, if we do it recursively, we should override. Wait.
    // Spec says: "re-showing restores each actor's own prior state". 
    // This implies we need a way to restore prior states.
  });
}
