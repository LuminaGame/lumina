import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/details/models/component_property_registry.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_component_registry.dart';

/// The Blueprint editor's Cloth component and its Details properties are the
/// keys the engine's cloth reads, with the engine's defaults.
void main() {
  test('the Cloth descriptor is registered as a Physics scene component', () {
    final d = BlueprintComponentRegistry.getDescriptor('LuminaClothComponent')!;
    expect(d.typeName, 'LuminaClothComponent');
    expect(d.displayName, 'Cloth');
    expect(d.category, 'Physics');
    expect(d.isSceneComponent, isTrue);
    expect(d.properties.firstWhere((p) => p.dartField == 'pinning').enumOptions, [
      for (final p in LuminaClothPinning.values) p.name,
    ]);
  });

  test('every Cloth property round-trips through the engine with the same defaults', () {
    final d = BlueprintComponentRegistry.getDescriptor('LuminaClothComponent')!;
    final props = <String, dynamic>{
      for (final p in d.properties)
        if (!const {'location', 'rotation', 'scale'}.contains(p.dartField)) p.dartField: p.defaultValue,
    };
    final engine = LuminaClothComponent();
    final fromEditor = LuminaClothComponent.fromProperties(props);
    final saved = engine.toProperties();
    for (final key in props.keys) {
      if (key == 'meshAsset' || key == 'color') continue;
      expect(fromEditor.toProperties()[key], saved[key], reason: key);
    }
    expect(fromEditor.meshAsset, isNull, reason: 'an empty asset reference is a grid');
    // `#E0615A` (sRGB) is the engine's default linear colour.
    expect(fromEditor.color.x, closeTo(engine.color.x, 0.02));
    expect(fromEditor.color.y, closeTo(engine.color.y, 0.02));
    expect(fromEditor.color.z, closeTo(engine.color.z, 0.02));
  });

  test('the Details panel describes the same Cloth properties', () {
    final details = ComponentPropertyRegistry.descriptors['LuminaClothComponent']!;
    final ids = details.properties.map((p) => p.id).toSet();
    final schema = BlueprintComponentRegistry.getDescriptor('LuminaClothComponent')!
        .properties
        .map((p) => p.dartField)
        .where((f) => !const {'location', 'rotation', 'scale'}.contains(f))
        .toSet();
    expect(ids, schema);
  });
}
