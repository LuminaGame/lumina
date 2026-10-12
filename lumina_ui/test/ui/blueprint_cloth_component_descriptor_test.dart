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

  skinnedClothDescriptorTests();
}

/// The Skinned Cloth (garment) component: registered under its own name
/// (never matched to the skeletal mesh), its properties the engine's keys
/// with the engine's defaults, the same set in the Details panel.
void skinnedClothDescriptorTests() {
  test('the Skinned Cloth descriptor is its own Physics scene component', () {
    final d = BlueprintComponentRegistry.getDescriptor('LuminaSkinnedClothComponent')!;
    expect(d.typeName, 'LuminaSkinnedClothComponent');
    expect(d.displayName, 'Skinned Cloth');
    expect(d.category, 'Physics');
    expect(BlueprintComponentRegistry.getDescriptor('LuminaSkeletalMeshComponent')!.typeName, isNot('LuminaSkinnedClothComponent'));
  });

  test('every Skinned Cloth property round-trips through the engine with the same defaults', () {
    final d = BlueprintComponentRegistry.getDescriptor('LuminaSkinnedClothComponent')!;
    final props = <String, dynamic>{for (final p in d.properties) p.dartField: p.defaultValue};
    final engine = LuminaSkinnedClothComponent().toProperties();
    final fromEditor = LuminaSkinnedClothComponent.fromProperties(props);
    final saved = fromEditor.toProperties();
    for (final key in props.keys) {
      if (const {'meshAsset', 'color', 'backstopDistance'}.contains(key)) continue;
      expect(saved[key], engine[key], reason: key);
    }
    expect(fromEditor.meshAsset, isNull, reason: 'an empty garment mesh is a generated skirt');
    expect(fromEditor.backstopDistance, isNull, reason: 'a negative backstop is none');
  });

  test('the Details panel describes the same Skinned Cloth properties', () {
    final details = ComponentPropertyRegistry.descriptors['LuminaSkinnedClothComponent']!;
    final schema = BlueprintComponentRegistry.getDescriptor('LuminaSkinnedClothComponent')!.properties.map((p) => p.dartField).toSet();
    expect(details.properties.map((p) => p.id).toSet(), schema);
  });
}
