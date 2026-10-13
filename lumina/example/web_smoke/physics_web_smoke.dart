// The physics web smoke app: Jolt Physics in the browser. It loads
// flutter_filament's and flutter_jolt's WebAssembly modules, runs the engine's
// rigid body tests (test/src/physics/rigid_body_test.dart, through the
// browser test runner) on the Jolt backend, then simulates real props from
// test-assets (a tower of barrels hit by a thrown barrel, air-conditioning
// units stacked beside it) and draws them. Meshes are fetched from the
// serving page (`physics_assets/<test-assets path>`). It reports to the page
// for test/smoke/physics_web_smoke_test.dart:
//   window.luminaPhysicsSmoke = {jolt, backend, tests, passed, failed,
//                                failures, ready, failedAssets, frames,
//                                stepMs, thrown, impulse, thrownX,
//                                towerMovedCm, settled, lowestBarrel}
//
// Build: flutter build web -t web_smoke/physics_web_smoke.dart
//   (flutter_filament/web/flutter_filament.{js,wasm} and
//    tools/flutter_jolt/web/flutter_jolt.{js,wasm} copied into example/web/)
// The rigid body test file and the browser test runner live under the
// engine's test/, imported by path (this entry is outside lib/ for that).

// ignore_for_file: always_use_package_imports

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

import '../../test/src/physics/rigid_body_test.dart' as rigid_body;
import '../../test/support/web_test_shim.dart';

const _barrels = ['Props/Barrels/fuel_barrel_red.glb', 'Props/Barrels/fuel_barrel_yellow.glb'];
const _acUnit = 'Props/AC_units/roof_aircon_unit_150x150_a.glb';

Future<Uint8List> _fetch(String path) async {
  final response = await globalContext.callMethod<JSPromise<JSObject>>('fetch'.toJS, 'physics_assets/$path'.toJS).toDart;
  if (!(response['ok']! as JSBoolean).toDart) {
    throw StateError('$path: HTTP ${(response['status']! as JSNumber).toDartInt}');
  }
  final buffer = await response.callMethod<JSPromise<JSArrayBuffer>>('arrayBuffer'.toJS).toDart;
  return buffer.toDart.asUint8List();
}

final Map<String, Object?> _report = {};

void _publish() {
  final state = JSObject();
  for (final e in _report.entries) {
    final v = e.value;
    state[e.key] = switch (v) {
      final bool b => b.toJS,
      final num n => n.toJS,
      final String s => s.toJS,
      _ => '$v'.toJS,
    };
  }
  globalContext['luminaPhysicsSmoke'] = state;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FilamentWeb.ensureInitialized();
  final jolt = await LuminaPhysicsSubsystem.prepareJolt();
  LuminaAssets.defaultProvider = _fetch;
  LuminaPhysicsSubsystem.defaultBackend = LuminaPhysicsBackendKind.jolt;
  _report['jolt'] = jolt;
  _report['backend'] = LuminaPhysicsSubsystem().backendKind.name;

  // The engine's rigid body tests, on Jolt, in the browser.
  rigid_body.main();
  final results = await runWebTests();
  _report['tests'] = results.length;
  _report['passed'] = results.where((r) => r.passed).length;
  _report['failed'] = results.where((r) => !r.passed).length;
  _report['failures'] = [for (final r in results.where((r) => !r.passed)) '${r.name}: ${r.error}'].join('\n');
  _publish();

  // The props' sizes (glTF metres), read before the scene is built.
  final bounds = <String, Aabb3>{};
  final failedAssets = <String>[];
  for (final a in [..._barrels, _acUnit]) {
    try {
      final mesh = (await GlbReader.parse(await _fetch(a)))!;
      bounds[a] = Aabb3.minMax(
        Vector3(mesh.minBounds[0], mesh.minBounds[1], mesh.minBounds[2]) * LuminaUnits.unitsPerMetre,
        Vector3(mesh.maxBounds[0], mesh.maxBounds[1], mesh.maxBounds[2]) * LuminaUnits.unitsPerMetre,
      );
    } catch (e) {
      failedAssets.add('$a: $e');
    }
  }
  _report['failedAssets'] = failedAssets.join('\n');
  _publish();
  runApp(PhysicsWebSmokeApp(bounds: bounds));
}

class PhysicsWebSmokeApp extends StatefulWidget {
  const PhysicsWebSmokeApp({super.key, required this.bounds});

  final Map<String, Aabb3> bounds;

  @override
  State<PhysicsWebSmokeApp> createState() => _PhysicsWebSmokeAppState();
}

class _PhysicsWebSmokeAppState extends State<PhysicsWebSmokeApp> {
  LuminaWorld? _world;
  final List<LuminaCollisionComponent> _barrelBodies = [];
  LuminaCylinderComponent? _thrown;
  bool _impulseApplied = false;
  List<Vector3> _towerStart = const [];
  double _time = 0;
  int _frames = 0;
  double _stepMs = 0;
  int? _lastMicros;

  /// A simulating prop: [collider] centred on the mesh's bounds, the mesh
  /// drawn as its child.
  T _prop<T extends LuminaCollisionComponent>(String asset, T collider, Vector3 at, double massKg) {
    final b = widget.bounds[asset]!;
    final centre = (b.min + b.max) * 0.5;
    collider
      ..relativeLocation = at
      ..simulatePhysics = true
      ..overrideMass = true
      ..massKg = massKg;
    final actor = LuminaActor(root: collider);
    final mesh = LuminaStaticMeshComponent(meshAssetPath: asset, location: -centre)..attachToComponent(collider);
    actor.addComponent(mesh);
    _world!.persistentLevel.registerActor(actor);
    return collider;
  }

  LuminaCylinderComponent _barrel(String asset, Vector3 at) {
    final b = widget.bounds[asset]!;
    final size = b.max - b.min;
    final c = _prop(asset, LuminaCylinderComponent(radius: math.max(size.x, size.z) / 2, halfHeight: size.y / 2), at, 60);
    _barrelBodies.add(c);
    return c;
  }

  void _sceneCreated(FilamentEngine engine, FilamentScene scene, FilamentCamera camera, FilamentView view) {
    scene.setSkybox(FilamentSkybox.build(engine, color: Vector4(0.45, 0.58, 0.8, 1), intensity: 30000));
    scene.setIndirectLight(FilamentIndirectLight.build(engine,
        irradiance: SphericalHarmonics(bands: 1, coefficients: [0.7, 0.7, 0.75]), intensity: 30000));
    camera.setProjection(fovDegrees: 45, aspect: 1280 / 800, near: 10, far: 100000, direction: FovDirection.vertical);
    camera.lookAt(eyeX: 260, eyeY: 260, eyeZ: 620, centerX: 0, centerY: 80, centerZ: 0);
    final world = _world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
    world.registerSubsystem(LuminaCollisionSubsystem());
    final physics = world.registerSubsystem(LuminaPhysicsSubsystem(backend: LuminaPhysicsBackendKind.jolt));
    _report['sceneBackend'] = physics.backendKind.name;
    world.bindView(view);
    world.persistentLevel.registerActor(LuminaPrimitiveActor(
        location: Vector3(0, -10, 0), shape: LuminaPrimitiveShape.box, size: Vector3(4000, 20, 4000), color: Vector3(0.5, 0.52, 0.5)));
    world.persistentLevel.registerActor(
        LuminaActor(root: LuminaDirectionalLightComponent(rotation: LuminaAxes.rotation([-50, 0, 35]), intensity: 100000, castShadows: true)));

    if (widget.bounds.length == 3) {
      // A tower of barrels: two columns of three.
      for (var level = 0; level < 3; level++) {
        for (var column = 0; column < 2; column++) {
          final asset = _barrels[(level + column) % 2];
          final h = widget.bounds[asset]!.max.y - widget.bounds[asset]!.min.y;
          _barrel(asset, Vector3(-80 + column * 75.0, h / 2 + level * (h + 1), 0));
        }
      }
      // Air-conditioning units stacked beside it.
      final ac = widget.bounds[_acUnit]!;
      final acSize = ac.max - ac.min;
      for (var i = 0; i < 2; i++) {
        _prop(_acUnit, LuminaBoxComponent(boxExtent: acSize * 0.5), Vector3(180, acSize.y / 2 + i * (acSize.y + 1), -60 + i * 20.0), 120);
      }
    }
    world.beginPlay();
    _report['ready'] = true;
    _publish();
  }

  List<FilamentView> _tick(FilamentView view, int width, int height) {
    final world = _world;
    if (world == null) return [view];
    final now = DateTime.now().microsecondsSinceEpoch;
    final dt = _lastMicros == null ? 1 / 60 : ((now - _lastMicros!) / 1e6).clamp(1 / 240, 1 / 20);
    _lastMicros = now;
    _time += dt;
    // After 2.5 s a barrel is thrown at the tower.
    // Its body exists once the physics subsystem has seen it, so the throw
    // waits for it.
    if (_thrown == null && _time > 2.5 && widget.bounds.length == 3) {
      _towerStart = [for (final c in _barrelBodies) c.worldLocation.clone()];
      _thrown = _barrel(_barrels.first, Vector3(-420, 200, 0));
    }
    final thrown = _thrown;
    if (thrown != null && !_impulseApplied && thrown.physicsBody != null) {
      thrown.addImpulse(Vector3(1100, 250, 0), velocityChange: true);
      _impulseApplied = true;
    }
    final watch = Stopwatch()..start();
    world.tick(dt);
    _stepMs = _stepMs * 0.9 + watch.elapsedMicroseconds / 1000 * 0.1;
    _frames++;
    if (_frames % 10 == 0) {
      _report['frames'] = _frames;
      _report['stepMs'] = double.parse(_stepMs.toStringAsFixed(2));
      _report['time'] = double.parse(_time.toStringAsFixed(2));
      _report['thrown'] = _thrown != null;
      _report['lowestBarrel'] = _barrelBodies.isEmpty ? 0 : _barrelBodies.map((b) => b.worldLocation.y).reduce(math.min).round();
      _report['impulse'] = _impulseApplied;
      _report['thrownX'] = thrown?.worldLocation.x.round();
      var moved = 0.0;
      for (var i = 0; i < _towerStart.length; i++) {
        final d = _barrelBodies[i].worldLocation - _towerStart[i];
        moved = math.max(moved, math.sqrt(d.x * d.x + d.z * d.z));
      }
      _report['towerMovedCm'] = moved.round();
      _report['settled'] = _barrelBodies.every((b) => !(b.physicsBody?.isAwake ?? false));
      _publish();
    }
    return [view];
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: FilamentWidget(onSceneCreated: _sceneCreated, frameViews: _tick),
    );
  }
}
