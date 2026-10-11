import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// A component type a plugin's runtime module adds.
class _PluginBeacon extends LuminaSceneComponent {
  _PluginBeacon(this.strength);
  final double strength;
}

void main() {
  tearDown(() => LuminaBlueprintComponents.unregisterType('PluginBeacon'));

  test('a registered type is built from its stored properties, with its transform', () {
    LuminaBlueprintComponents.registerType('PluginBeacon', (p) => _PluginBeacon((p['strength'] as num?)?.toDouble() ?? 1));
    expect(LuminaBlueprintComponents.isRegisteredType('PluginBeacon'), isTrue);
    final actor = LuminaActor();
    final built = LuminaBlueprintComponents.construct(actor, [
      LuminaBlueprintComponent(
        id: 'beacon',
        name: 'Beacon',
        type: 'PluginBeacon',
        properties: {'strength': 3.5, 'location': [0, 0, 120]},
      ),
    ]);
    final beacon = built['beacon'];
    expect(beacon, isA<_PluginBeacon>());
    expect((beacon! as _PluginBeacon).strength, 3.5);
    // Authoring Z-up 120 cm is runtime Y-up 120 cm.
    expect((beacon as LuminaSceneComponent).relativeLocation.y, closeTo(120, 1e-6));
    expect(actor.components, contains(beacon));
  });

  test('an unregistered type is reported and skipped', () {
    final diagnostics = <LuminaBlueprintDiagnostic>[];
    final built = LuminaBlueprintComponents.construct(LuminaActor(), [
      LuminaBlueprintComponent(id: 'x', name: 'X', type: 'PluginBeacon'),
    ], diagnostics: diagnostics);
    expect(built.containsKey('x'), isFalse);
    expect(diagnostics.single.message, contains('no runtime counterpart'));
  });
}
