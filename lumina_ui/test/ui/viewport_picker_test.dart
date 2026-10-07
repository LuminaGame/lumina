import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina_ui/ui/features/main_editor/services/viewport_picker.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

void main() {
  _assetSpaceBounds();
  group('ViewportPicker', () {
    test('ray-AABB intersection nearer wins', () async {
      // Mock or use real? "Uses a REAL temp project... with real .lmas/.glb bounds"
      final picker = ViewportPicker();
      
      // Need real meshData bounds to test.
      final meshData = GlbMeshData(
        positions: [],
        indices: [],
        minBounds: [-50, -50, -50],
        maxBounds: [50, 50, 50],
      );

      final actorNear = EditorActorNode(
        id: 'actor_near',
        name: 'Near',
        type: 'StaticMesh',
        location: [0, 0, 200],
        meshData: meshData,
      );

      final actorFar = EditorActorNode(
        id: 'actor_far',
        name: 'Far',
        type: 'StaticMesh',
        location: [0, 0, 400],
        meshData: meshData,
      );
      
      final ray = Ray.originDirection(Vector3.array([0, 0, 0]), Vector3.array([0, 0, 1]));
      
      final hits = picker.pickActors([actorNear, actorFar], ray, null);
      
      expect(hits.isNotEmpty, isTrue);
      expect(hits.first.actor.id, 'actor_near');
    });

    test('Hidden and locked actors are skipped', () {
      final picker = ViewportPicker();
      final meshData = GlbMeshData(
        positions: [],
        indices: [],
        minBounds: [-50, -50, -50],
        maxBounds: [50, 50, 50],
      );

      final actorHidden = EditorActorNode(
        id: 'hidden',
        name: 'Hidden',
        type: 'StaticMesh',
        location: [0, 0, 200],
        meshData: meshData,
        isVisible: false,
      );

      final actorLocked = EditorActorNode(
        id: 'locked',
        name: 'Locked',
        type: 'StaticMesh',
        location: [0, 0, 200],
        meshData: meshData,
        isLocked: true,
      );
      
      final ray = Ray.originDirection(Vector3.array([0, 0, 0]), Vector3.array([0, 0, 1]));
      final hits = picker.pickActors([actorHidden, actorLocked], ray, null);
      
      expect(hits.isEmpty, isTrue);
    });
  });
}

/// The mesh bounds a GLB carries are in the asset's own Y-up space, while an
/// editor actor's location and scale are Z-up. The picker used to add the two
/// together unconverted, so the box it tested was rotated away from the mesh
/// the viewport actually draws and clicking an actor never selected it.
void _assetSpaceBounds() {
  group('mesh bounds are converted from asset space to editor space', () {
    // A door-shaped glTF mesh: 2 wide, 3 tall, 1 deep in its own Y-up metres,
    // drawn ×100 in the centimetre world: 200 × 300 × 100.
    GlbMeshData doorMesh() => GlbMeshData(
          positions: const [],
          indices: const [],
          minBounds: const [-1.0, 0.0, -0.5],
          maxBounds: const [1.0, 3.0, 0.5],
        );

    EditorActorNode door({List<double>? location, List<double>? scale}) => EditorActorNode(
          id: 'door',
          name: 'Door',
          type: 'StaticMesh',
          location: location ?? [0.0, 0.0, 0.0],
          scale: scale ?? [1.0, 1.0, 1.0],
          meshData: doorMesh(),
        );

    test('the tall axis of the mesh becomes the editor up axis', () {
      final picker = ViewportPicker();
      final actor = door();

      // Straight down from well above the origin: the editor's up axis is Z,
      // and the mesh is 3 tall, so this must hit.
      final fromAbove = Ray.originDirection(Vector3(0, 0, 1000), Vector3(0, 0, -1));
      expect(picker.pickActors([actor], fromAbove, null), isNotEmpty,
          reason: 'the mesh is 300 tall along editor Z');

      // Along editor Y (depth) the mesh is only 100 deep, so a ray 300 out
      // on that axis must miss.
      final pastTheSide = Ray.originDirection(Vector3(0, 300, 1000), Vector3(0, 0, -1));
      expect(picker.pickActors([actor], pastTheSide, null), isEmpty,
          reason: 'the mesh is 100 deep, not 600');
    });

    test('a click at the actor location hits it wherever the actor is moved', () {
      final picker = ViewportPicker();
      final actor = door(location: [-5400.0, 4510.0, 0.0]);

      final atTheActor = Ray.originDirection(Vector3(-5400, 4510, 2000), Vector3(0, 0, -1));
      expect(picker.pickActors([actor], atTheActor, null), isNotEmpty);

      final whereItUsedToBeTested = Ray.originDirection(Vector3(-5400, 0, 2000), Vector3(0, 0, -1));
      expect(picker.pickActors([actor], whereItUsedToBeTested, null), isEmpty,
          reason: 'the box must follow the actor, not sit at an unrelated depth');
    });

    test('scale is applied on the editor axis it belongs to', () {
      final picker = ViewportPicker();
      // Editor scale is (x, depth, up). Ten times taller, same footprint.
      final tall = door(scale: [1.0, 1.0, 10.0]);

      final high = Ray.originDirection(Vector3(0, 0, 10000), Vector3(0, 0, -1));
      expect(picker.pickActors([tall], high, null), isNotEmpty);

      final deep = Ray.originDirection(Vector3(0, 400, 1000), Vector3(0, 0, -1));
      expect(picker.pickActors([tall], deep, null), isEmpty,
          reason: 'the up scale must not stretch the depth axis');
    });

    test('the hit distance is still the near face, so the closer actor wins', () {
      final picker = ViewportPicker();
      final near = door(location: [0.0, 0.0, 0.0]);
      final far = EditorActorNode(
        id: 'far',
        name: 'Far',
        type: 'StaticMesh',
        location: [0.0, 0.0, -2000.0],
        meshData: doorMesh(),
      );

      final ray = Ray.originDirection(Vector3(0, 0, 1000), Vector3(0, 0, -1));
      final hits = picker.pickActors([far, near], ray, null);
      expect(hits.first.actor.id, 'door');
    });
  });
}
