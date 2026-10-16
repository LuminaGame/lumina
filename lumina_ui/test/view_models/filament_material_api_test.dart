import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart' show LuminaWorkspace;
import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/filament_material_api.g.dart';
import 'package:path/path.dart' as p;

import '../../tool/src/filament_material_code.dart';
import '../../tool/src/filament_material_doc.dart';
import '../../tool/src/filament_material_merge.dart';

/// The Filament checkout the prebuilt scripts build from
/// (`LUMINA_FILAMENT_WORK`, else `<workspace>/build/filament-src`).
String filamentSource() =>
    Platform.environment['LUMINA_FILAMENT_WORK'] ?? p.join(LuminaWorkspace.root, 'build', 'filament-src');

/// Its material documentation.
File materialsDoc() => File(p.join(filamentSource(), 'docs_src', 'src_markdeep', 'Materials.md.html'));

void main() {
  final doc = materialsDoc();
  final skip = doc.existsSync() && FilamentMaterialCode.existsIn(filamentSource())
      ? false
      : 'Filament source with docs_src/src_markdeep/Materials.md.html and libs/filament-matp not found at '
            '${filamentSource()} (set LUMINA_FILAMENT_WORK to the Filament checkout)';

  test('the generated table lists every function of the documentation\'s shader API tables', () {
    final html = doc.readAsStringSync();
    final listed = FilamentMaterialDoc.listedFunctionNames(html);
    expect(listed, containsAll(['getWorldPosition', 'saturate', 'getCustom0', 'getCustom7', 'morphData4']));
    final generated = {for (final f in filamentFunctions) f.name};
    expect(listed.difference(generated), isEmpty);
  }, skip: skip);

  test('the generated tables match a fresh parse of the documentation checked against the source', () {
    final parsed = mergeFilamentMaterialCode(
      FilamentMaterialDoc.parse(doc.readAsStringSync()),
      FilamentMaterialCode.read(filamentSource()),
    );
    expect([for (final k in filamentHeaderKeys) k.values], [for (final k in parsed.headerKeys) k.values]);
    expect([for (final k in filamentHeaderKeys) k.name], [for (final k in parsed.headerKeys) k.name]);
    expect([for (final f in filamentMaterialInputs) f.name], [for (final f in parsed.fragmentInputs) f.name]);
    expect([for (final f in filamentMaterialVertexInputs) f.name], [for (final f in parsed.vertexInputs) f.name]);
    expect([for (final f in filamentFunctions) f.signature], [for (final f in parsed.functions) f.signature]);
    expect([for (final t in filamentParameterTypes) t.name], [for (final t in parsed.parameterTypes) t.name]);
  }, skip: skip);

  test('the generated tables carry the documented header values and defaults', () {
    final shading = filamentHeaderKeys.firstWhere((k) => k.name == 'shadingModel');
    expect(shading.values, ['lit', 'subsurface', 'cloth', 'unlit', 'specularGlossiness']);
    expect(shading.defaultValue, 'lit');
    final blending = filamentHeaderKeys.firstWhere((k) => k.name == 'blending');
    expect(blending.values, containsAll(['opaque', 'transparent', 'fade', 'add', 'masked', 'multiply', 'screen']));
    final requires = filamentHeaderKeys.firstWhere((k) => k.name == 'requires');
    expect(requires.values, containsAll(['uv0', 'uv1', 'color', 'position', 'tangents', 'custom0', 'custom7']));
    expect(filamentParameterTypes.map((t) => t.name), containsAll(['float4', 'sampler2d', 'samplerCubemap']));
    expect(filamentConstants.map((c) => c.name), ['PI', 'HALF_PI']);
    final metallic = filamentMaterialInputs.firstWhere((f) => f.name == 'metallic');
    expect(metallic.availableWith('lit'), isTrue);
    expect(metallic.availableWith('cloth'), isFalse);
    expect(metallic.defaultValue, '0.0');
    expect(filamentFunctions.firstWhere((f) => f.name == 'getWorldRayFromClip').apiLevel, 2);
    // The table is generated from the release the prebuilt Filament names (tool/filament/VERSION).
    final prebuilt = File(p.join(LuminaWorkspace.root, 'tool', 'filament', 'VERSION'));
    expect(filamentMaterialApiVersion, prebuilt.readAsStringSync().trim().split('-').first);
  });

  test('matc decides the valid values; what it ignores or no longer accepts is marked removed', () {
    final filter = filamentHeaderKeys.firstWhere((k) => k.name == 'variantFilter');
    expect(filter.values, containsAll(['shadowReceiver', 'skinning', 'vsm', 'fog', 'ssr', 'stereo']));
    expect(filter.values, isNot(contains('directionalLighting')));
    expect(filter.removedValues.keys, containsAll(['dynamicLighting', 'directionalLighting']));
    final specularAo = filamentHeaderKeys.firstWhere((k) => k.name == 'specularAmbientOcclusion');
    expect(specularAo.valueAliases, {'false': 'none', 'true': 'simple'});
  });

  test('keys, fields and functions the documentation leaves out come from the source', () {
    final undocumented = {for (final k in filamentHeaderKeys) if (!k.documented) k.name};
    expect(undocumented, containsAll(['domain', 'stereoscopicType', 'framebufferFetch', 'rayQuery']));
    final fields = {for (final f in filamentMaterialInputs) f.name: f};
    expect(fields['secondRoughness']!.apiLevel, 2);
    expect(fields['shadowStrength']!.documented, isFalse);
    expect(filamentFunctions.any((f) => f.name == 'getInstanceIndex' && !f.documented), isTrue);
    final offset = filamentFunctions.firstWhere((f) => f.name == 'getWorldOffset');
    expect(offset.deprecated, isNotNull);
    expect(offset.replacement, 'getUserWorldFromWorldMatrix()[3].xyz');
  });
}
