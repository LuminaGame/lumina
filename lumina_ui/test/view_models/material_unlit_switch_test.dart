import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart' show FilamatShading;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';

/// Switching a material to Unlit drops the lit-only assignments
/// (those pins are greyed out) and the material still compiles.
void main() {
  late Directory project;

  setUp(() => project = Directory.systemTemp.createTempSync('material_unlit_switch_'));
  tearDown(() => project.deleteSync(recursive: true));

  test('Unlit drops metallic / roughness and compiles; Lit brings them back from the graph', () async {
    // A new material: the editor opens it on its default (lit) template.
    final vm = MaterialEditorViewModel(assetPath: '${project.path}/contents/materials/M_Switch.lmas');
    await vm.load();
    vm.graph.ensureSynced();
    expect(vm.currentCode, contains('material.roughness'), reason: 'the default material is lit');
    expect(vm.currentCode, contains('material.metallic'));

    await vm.updateHeaderSettings(shading: FilamatShading.unlit);
    expect(vm.currentCode, contains('shadingModel : unlit'));
    expect(vm.currentCode, isNot(contains('material.metallic')));
    expect(vm.currentCode, isNot(contains('material.roughness')));
    expect(await vm.compile(), isTrue, reason: vm.issues.map((i) => i.message).join('\n'));

    await vm.updateHeaderSettings(shading: FilamatShading.lit);
    expect(vm.currentCode, contains('material.metallic'));
    expect(vm.currentCode, contains('material.roughness'));
    expect(await vm.compile(), isTrue);
  });
}
