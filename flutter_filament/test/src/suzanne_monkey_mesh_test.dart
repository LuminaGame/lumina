import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';

/// createSuzanneMonkeyMesh must reach a real native implementation.
void main() {
  test('createSuzanneMonkeyMesh loads the embedded Suzanne as a renderable', () {
    final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    addTearDown(engine.dispose);
    // The engine owns its default material: wrap it, never dispose it.
    final material = FilamentMaterial.internal(engine.defaultMaterialPointer, engine);
    final renderables = FilamentRenderableManager(engine);

    final entity = renderables.createSuzanneMonkeyMesh(material.defaultInstance);

    expect(entity, isNot(0));
    expect(renderables.hasComponent(entity), isTrue);
  });
}
