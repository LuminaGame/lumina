import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// Hiding an actor hides every scene component it has or gets, and a mesh
/// component's own `visible` switch is the same switch as `isVisible`.
void main() {
  test('a static mesh component keeps visible and isVisible in step both ways', () {
    final mesh = LuminaStaticMeshComponent(meshAssetPath: 'contents/meshes/SM_Barrel.lmas', visible: false);
    expect(mesh.isVisible, isFalse, reason: 'the constructor argument sets both');
    expect(mesh.visible, isFalse);
    mesh.isVisible = true;
    expect(mesh.visible, isTrue);
    mesh.visible = false;
    expect(mesh.isVisible, isFalse);
  });

  test('an actor constructed hidden hides its root and every component added to it', () {
    final actor = LuminaActor(key: const LuminaObjectKey('crate'), hiddenInGame: true);
    expect(actor.hiddenInGame, isTrue);
    expect(actor.rootComponent.isVisible, isFalse);
    final mesh = LuminaStaticMeshComponent(meshAssetPath: 'contents/meshes/SM_Barrel.lmas');
    actor.addComponent(mesh);
    expect(mesh.isVisible, isFalse, reason: 'a component added to a hidden actor is hidden');
    expect(mesh.visible, isFalse);
    final later = LuminaStaticMeshComponent(meshAssetPath: 'contents/meshes/SM_Lid.lmas');
    actor.addComponent(later);
    expect(later.visible, isFalse, reason: 'a component added afterwards is hidden too');
    actor.hiddenInGame = false;
    expect(mesh.visible, isTrue);
    expect(later.visible, isTrue);
    expect(actor.rootComponent.isVisible, isTrue);
  });

  test('the cascade the level generator emits hides a factory-made actor', () {
    final actor = LuminaActor(key: const LuminaObjectKey('bp'))..hiddenInGame = true;
    expect(actor.rootComponent.isVisible, isFalse);
  });
}
