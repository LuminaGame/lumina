import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina_runtime.dart';

/// One world unit is one centimetre.
void main() {
  test('LuminaUnits: 100 units per metre, gravity 980 cm/s², conversions both ways', () {
    expect(LuminaUnits.unitsPerMetre, 100);
    expect(LuminaUnits.gravity, 980);
    expect(LuminaUnits.metres(1.8), closeTo(180, 1e-9));
    expect(LuminaUnits.toMetres(250), 2.5);
  });

  test('a world pulls down at 980 cm/s² unless the project says otherwise', () {
    final world = LuminaWorld();
    expect(world.gravityZ, -980);
    world.gravityZ = -490;
    expect(world.gravityZ, -490);
  });
}
