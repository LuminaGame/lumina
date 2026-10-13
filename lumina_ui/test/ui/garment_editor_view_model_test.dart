import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/garment_editor_view_model.dart';

/// The Garment editor's view model on a real temp project: the T-shirt from
/// `test-assets/Props/Clothes Line/` placed on the mannequin, landmarks
/// picked on both meshes by rays, aligned, saved and read back.
void main() {
  final assets = Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.parent.path}/test-assets';
  final tshirt = File('$assets/Props/Clothes Line/tshirt.glb');
  final manny = File('$assets/mannequin/SKM_Manny_Simple.glb');
  final skip = tshirt.existsSync() && manny.existsSync() ? false : 'the T-shirt or the mannequin is missing from test-assets';

  late Directory project;
  late String garmentPath;

  setUp(() async {
    project = await Directory.systemTemp.createTemp('garment_vm_');
    await Directory('${project.path}/contents/meshes/static').create(recursive: true);
    await Directory('${project.path}/contents/meshes/skeletal').create(recursive: true);
    await Directory('${project.path}/contents/characters').create(recursive: true);
    await tshirt.copy('${project.path}/contents/meshes/static/tshirt.glb');
    await manny.copy('${project.path}/contents/meshes/skeletal/SKM_Manny_Simple.glb');
    await File('${project.path}/Garments.lmproject').writeAsString('{"projectName":"Garments"}');
    garmentPath = '${project.path}/contents/characters/G_Tshirt.lmas';
    await File(garmentPath).writeAsBytes(const LuminaGarmentDocument().toAsset(name: 'G_Tshirt').toProtoBufferBytes());
  });

  tearDown(() async {
    try {
      await project.delete(recursive: true);
    } catch (_) {}
  });

  Future<GarmentEditorViewModel> open() async {
    final vm = GarmentEditorViewModel(assetPath: garmentPath);
    await vm.load();
    await vm.setSourceMesh('contents/meshes/static/tshirt.glb');
    await vm.setReferenceBody('contents/meshes/skeletal/SKM_Manny_Simple.glb');
    await vm.meshesReady;
    return vm;
  }

  test('both meshes load for picking; the project lists its meshes', () async {
    final vm = await open();
    addTearDown(vm.dispose);
    expect(vm.error, isNull);
    expect(vm.sourceMesh!.data.vertexCount, greaterThan(300));
    expect(vm.bodyMesh!.data.vertexCount, 48705);
    expect(vm.projectDir.replaceAll(r'\', '/'), project.path.replaceAll(r'\', '/'));
    expect(vm.isDirty, isTrue, reason: 'the meshes were chosen');
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  test('a ray on the placed T-shirt sets the landmark on its surface; on the body, on the body; Align brings them together; save → reload equal',
      () async {
    final vm = await open();
    addTearDown(vm.dispose);
    // The shirt hangs flat across X on the line: turned to face +Z, at the chest.
    vm.setPlacement(location: [0, 150, 18], rotation: [0, 90, 0], scale: [1, 1, 1]);
    final grid = LuminaTriangleGrid(vm.sourceMesh!.data.positions, vm.sourceMesh!.data.triangles);

    const picks = {'Neck': (0.0, 145.0), 'Shoulder L': (16.0, 140.0), 'Shoulder R': (-16.0, 140.0), 'Waist': (0.0, 100.0)};
    for (final e in picks.entries) {
      expect(vm.addLandmark(e.key), isTrue);
      vm.setPickMode(GarmentPickMode.garment);
      expect(vm.pick(e.value.$1, e.value.$2, 200, 0, 0, -1), isTrue, reason: '${e.key} on the shirt');
      final g = vm.doc.landmark(e.key)!.garment!;
      final onSurface = grid.closest(g[0], g[1], g[2])!;
      expect(onSurface.distance, lessThan(0.5), reason: 'stored in the source mesh\'s space');
      vm.setPickMode(GarmentPickMode.body);
      expect(vm.pick(e.value.$1, e.value.$2, 200, 0, 0, -1), isTrue, reason: '${e.key} on the body');
    }
    expect(vm.addLandmark('Neck'), isFalse, reason: 'taken');
    expect(vm.missingPresets, isNot(contains('Neck')));
    final before = vm.landmarkErrors();
    // Off by a metre: Align brings it back.
    vm.setPlacement(location: [100, 60, -40]);
    expect(vm.align(), isTrue);
    final after = vm.landmarkErrors();
    // ignore: avoid_print
    print('landmark error before ${before.values.map((e) => e.toStringAsFixed(1))} after ${after.values.map((e) => e.toStringAsFixed(1))} cm');
    for (final e in after.values) {
      expect(e, lessThan(4.0));
    }
    expect(await vm.save(), isTrue);
    expect(vm.isDirty, isFalse);
    final reread = GarmentEditorViewModel(assetPath: garmentPath);
    addTearDown(reread.dispose);
    await reread.load();
    expect(reread.doc, vm.doc);
    expect(reread.doc.landmarks.map((l) => l.name), picks.keys);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  test('a missing source mesh is reported, not thrown; revert restores the saved document', () async {
    final vm = GarmentEditorViewModel(assetPath: garmentPath);
    addTearDown(vm.dispose);
    await vm.load();
    await vm.setSourceMesh('contents/meshes/static/nope.glb');
    await vm.meshesReady;
    expect(vm.sourceMesh, isNull);
    expect(vm.error, contains('nope.glb'));
    vm.setThickness(3);
    expect(vm.isDirty, isTrue);
    vm.revert();
    expect(vm.doc, const LuminaGarmentDocument());
  }, skip: skip);
}
