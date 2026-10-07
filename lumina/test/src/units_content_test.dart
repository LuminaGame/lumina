import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// Content in centimetres; levels authored Z-up (the editor's
/// convention) and converted once to the runtime's Y-up.

/// The editor viewport's own placement (lumina_ui viewport_widget.dart
/// `_createTransformMatrix` fed with `(x, z, −y)`, `(rx, rz, −ry)`,
/// `(sx, sz, sy)`): Ry(yaw)·Rx(pitch)·Rz(roll), column-major.
Matrix4 _viewportMatrix(List<double> loc, List<double> rot, List<double> scl) {
  final tx = loc[0], ty = loc[2], tz = -loc[1];
  final radX = rot[0] * math.pi / 180, radY = -rot[2] * math.pi / 180, radZ = rot[1] * math.pi / 180;
  final sx = scl[0], sy = scl[2], sz = scl[1];
  final cx = math.cos(radX), sx_ = math.sin(radX);
  final cy = math.cos(radY), sy_ = math.sin(radY);
  final cz = math.cos(radZ), sz_ = math.sin(radZ);
  return Matrix4(
    (cy * cz + sy_ * sx_ * sz_) * sx, (cx * sz_) * sx, (-sy_ * cz + cy * sx_ * sz_) * sx, 0,
    (-cy * sz_ + sy_ * sx_ * cz) * sy, (cx * cz) * sy, (sy_ * sz_ + cy * sx_ * cz) * sy, 0,
    (sy_ * cx) * sz, (-sx_) * sz, (cy * cx) * sz, 0,
    tx, ty, tz, 1,
  );
}

void main() {
  group('LuminaAxes', () {
    test('location (x, y, z) Z-up → (x, z, −y) Y-up and back; scale follows its axis', () {
      expect(LuminaAxes.location([1, 2, 3]), Vector3(1, 3, -2));
      expect(LuminaAxes.toAuthoringLocation(Vector3(1, 3, -2)), [1, 2, 3]);
      expect(LuminaAxes.scale([1, 2, 3]), Vector3(1, 3, 2));
    });

    test('rotation matches the editor viewport for yaw, pitch, roll and a mix', () {
      for (final rot in const [
        [0.0, 0.0, 90.0],
        [30.0, 0.0, 0.0],
        [0.0, 45.0, 0.0],
        [-50.0, 20.0, -30.0],
      ]) {
        final runtime = Matrix4.compose(LuminaAxes.location(const [400, 0, 60]), LuminaAxes.rotation(rot), LuminaAxes.scale(const [1, 2, 3]));
        final editor = _viewportMatrix(const [400, 0, 60], rot, const [1, 2, 3]);
        for (var i = 0; i < 16; i++) {
          expect(runtime.storage[i], closeTo(editor.storage[i], 1e-9), reason: 'rotation $rot, element $i');
        }
      }
      // Yaw about authoring Z is a turn about the runtime's up axis, and a
      // positive yaw turns right: yaw 90 faces +X.
      final forward = LuminaAxes.rotation(const [0, 0, 90]).asRotationMatrix().transformed(Vector3(0, 0, -1));
      expect(forward.y, closeTo(0, 1e-12));
      expect(forward.x, closeTo(1, 1e-12));
    });
  });

  group('asset unit scale', () {
    late FilamentEngine engine;
    late FilamentScene scene;
    late LuminaWorld world;
    setUp(() {
      engine = FilamentEngine.create()!;
      scene = engine.createScene();
      world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
    });
    tearDown(() {
      world.cleanup();
      scene.dispose();
      engine.dispose();
    });

    Future<Uint8List> mannequin(String _) async => File(LuminaThirdPersonContent.bundledMeshPath).readAsBytes();

    test('a glTF mesh (metres) draws ×100: the mannequin is ~180 cm tall; assetUnitScale 1 keeps 1.8', () async {
      final cm = LuminaStaticMeshComponent(meshAssetPath: 'mannequin.glb', assetProvider: mannequin);
      final raw = LuminaStaticMeshComponent(meshAssetPath: 'mannequin_raw.glb', assetProvider: mannequin, assetUnitScale: 1);
      world.persistentLevel.registerActor(LuminaActor(root: cm));
      world.persistentLevel.registerActor(LuminaActor(root: raw));
      world.beginPlay();
      await Future.wait([cm.loaded, raw.loaded]);
      final cmHeight = cm.localBounds!.max.y - cm.localBounds!.min.y;
      expect(cmHeight, closeTo(180, 3));
      expect(raw.localBounds!.max.y - raw.localBounds!.min.y, closeTo(1.8, 0.03));
      expect(cm.renderTransform.getMaxScaleOnAxis(), closeTo(100, 1e-9));
    });

    test('a primitive is generated in cm and drawn at its authored size', () async {
      final crate = LuminaPrimitiveActor(shape: LuminaPrimitiveShape.box, size: Vector3.all(100), color: Vector3(0.7, 0.5, 0.3));
      world.persistentLevel.registerActor(crate);
      world.beginPlay();
      await crate.meshComponent.loaded;
      expect(crate.meshComponent.assetUnitScale, 1);
      final b = crate.meshComponent.localBounds!;
      expect(b.max.x - b.min.x, closeTo(100, 0.5));
    });
  });

  group('templates and codegen', () {
    Map<String, dynamic> actor(List<Map<String, dynamic>> actors, String name) => actors.firstWhere((a) => a['name'] == name);
    Map<String, dynamic> size(Map<String, dynamic> a) => Map<String, dynamic>.from(((a['components'] as List).first as Map)['properties'] as Map);

    test('Third Person yard is authored in cm, Z up', () {
      final actors = GameTemplateCatalog.thirdPerson.levelActors;
      expect(size(actor(actors, 'Ground'))['sizeX'], 6000);
      expect(size(actor(actors, 'Wall_North'))['sizeZ'], 250, reason: 'a primitive size is Z up too: sizeZ is its height');
      expect((actor(actors, 'PlayerStart')['location'] as List)[2], greaterThanOrEqualTo(90), reason: 'Z is up');
      expect(size(actor(actors, 'Platform'))['sizeZ'], 200);
      expect((actor(actors, 'Platform')['location'] as List)[2], 100);
      final stairs = actors.where((a) => (a['name'] as String).startsWith('Stair_')).map((a) => size(a)['sizeZ'] as double).toList()..sort();
      for (var i = 1; i < stairs.length; i++) {
        expect(stairs[i] - stairs[i - 1], lessThanOrEqualTo(20), reason: 'a step never rises more than 20 cm');
      }
      expect(actor(actors, 'DirectionalLight_Sun')['rotation'], [-50, 0, 30]);
    });

    test('First Person room is authored in cm, Z up', () {
      final actors = GameTemplateCatalog.firstPerson.levelActors;
      expect(size(actor(actors, 'Floor'))['sizeX'], 2000);
      expect((actor(actors, 'Wall_North')['location'] as List)[2], 150);
      expect((actor(actors, 'Crate_B')['location'] as List)[2], 150);
    });

    test('the template primitives draw the same shapes now that their sizes are stored Z up', () {
      // Runtime (Y-up) extents the shapes have always been drawn with.
      const drawn = <String, Map<String, List<double>>>{
        'thirdPerson': {
          'Ground': [6000, 0, 6000],
          'Wall_North': [6000, 250, 50],
          'Wall_East': [50, 250, 6000],
          'Platform': [800, 200, 800],
          'Stair_03': [300, 60, 50],
          'Hurdle': [600, 50, 40],
          'Crate_01': [100, 100, 100],
          'Pillar_01': [80, 400, 80],
          'Divider_Wall': [40, 200, 1000],
          'Marker_Sphere': [160, 160, 160],
        },
        'firstPerson': {
          'Floor': [2000, 0, 2000],
          'Wall_North': [2000, 300, 30],
          'Wall_West': [30, 300, 2000],
          'Crate_C': [140, 60, 140],
          'Pillar': [80, 300, 80],
        },
      };
      for (final template in [GameTemplateCatalog.thirdPerson, GameTemplateCatalog.firstPerson]) {
        final key = template == GameTemplateCatalog.thirdPerson ? 'thirdPerson' : 'firstPerson';
        for (final e in drawn[key]!.entries) {
          expect(luminaPrimitiveSize(size(actor(template.levelActors, e.key))).storage, e.value, reason: '$key ${e.key}');
        }
      }
    });

    test('new manifests declare cm / Z up; older ones read as legacy metres', () {
      const project = LuminaProject(projectName: 'u');
      expect(project.toMap()['world_units'], 'cm');
      expect(project.toMap()['up_axis'], 'z');
      expect(project.isLegacyMetreProject, isFalse);
      final legacy = LuminaProject.fromMap(Map<String, dynamic>.from(jsonDecode(jsonEncode(project.toMap())) as Map)
        ..remove('world_units')
        ..remove('up_axis'));
      expect(legacy.worldUnits, 'm');
      expect(legacy.upAxis, 'y');
      expect(legacy.isLegacyMetreProject, isTrue);
    });

    test('the editor grid defaults to 1 m squares over ±20 m; the translate snap is 10 cm', () {
      const snap = EditorSnapSettings();
      expect(snap.gridStep, 100.0);
      expect(snap.gridExtent, 2000.0);
      expect(snap.translateSnapStep, 10.0);
      final read = EditorSnapSettings.fromMap(const {});
      expect([read.gridStep, read.gridExtent], [100.0, 2000.0]);
    });
  });
}
