import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';
import 'package:vector_math/vector_math_64.dart';

/// Point light exposure on a real GPU: a sunless level lit only by a point or a
/// spot light, rendered through a game world whose active camera the world
/// exposes ([LuminaAutoExposure]). Before the fix the camera kept the sunny-16
/// exposure and the floor under the user's 55 695 lm red lamp was (5, 0, 0).
///
/// Top-down camera 15 m above a grey floor, 640×480, 60° vertical FOV: one
/// pixel is 3.61 cm on the floor.
const _w = 640;
const _h = 480;
const _cameraHeight = 1500.0;
final double _cmPerPixel = _cameraHeight * math.tan(math.pi / 6) * 2 / _h;

const _props = ['Props/Barrels/dented_barrel.glb', 'Props/AC_units/ac_unit_a_300x300.glb'];

class _Frame {
  _Frame() {
    engine = FilamentEngine.create()!;
    scene = engine.createScene();
    view = engine.createView();
    renderer = engine.createRenderer();
    swapChain = engine.createHeadlessSwapChain(_w, _h);
    native = engine.createCamera(engine.createEntity());
    view
      ..scene = scene
      ..camera = native
      ..setViewport(0, 0, _w, _h);
    world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene, view: view);
    // Looking straight down; image up is −Z.
    world.persistentLevel.registerActor(LuminaActor(
      root: LuminaCameraComponent(location: Vector3(0, _cameraHeight, 0), rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -math.pi / 2))
        ..isActive = true,
    ));
  }

  late final FilamentEngine engine;
  late final FilamentScene scene;
  late final FilamentView view;
  late final FilamentRenderer renderer;
  late final FilamentSwapChain swapChain;
  late final FilamentCamera native;
  late final LuminaWorld world;
  final ffi.Pointer<ffi.Uint8> _pixels = calloc<ffi.Uint8>(_w * _h * 4);

  Future<void> floorAndProps() async {
    final floor = LuminaPrimitiveActor(shape: LuminaPrimitiveShape.plane, size: Vector3(6000, 0, 6000), color: luminaHexToRgb('#8C8C8C'));
    world.persistentLevel.registerActor(floor);
    final meshes = <LuminaStaticMeshComponent>[];
    for (final (i, rel) in _props.indexed) {
      final path = '${SmokeArtifacts.testAssetsDir.path}/$rel';
      if (!File(path).existsSync()) continue;
      // Above the measured row (image up is −Z); glTF metres × 100 by default.
      final mesh = LuminaStaticMeshComponent(
        meshAssetPath: path,
        location: Vector3(i == 0 ? -120.0 : 160.0, 0, -260),
      );
      meshes.add(mesh);
      world.persistentLevel.registerActor(LuminaActor(root: mesh));
    }
    world.beginPlay();
    await floor.meshComponent.loaded;
    for (final m in meshes) {
      await m.loaded;
    }
  }

  Uint8List capture() {
    world.tick(1 / 60);
    for (var i = 0; i < 4; i++) {
      if (renderer.beginFrame(swapChain)) {
        renderer.render(view);
        if (i == 3) {
          c.filament_renderer_read_pixels(renderer.nativePointer, engine.nativePointer, 0, 0, _w, _h, _pixels.cast(), ffi.nullptr, ffi.nullptr);
        }
        renderer.endFrame();
      }
      engine.flushAndWait();
    }
    // Filament reads bottom-up; flip to top-down for the PNG and the probes.
    final out = Uint8List(_w * _h * 4);
    final src = _pixels.asTypedList(_w * _h * 4);
    for (var y = 0; y < _h; y++) {
      out.setRange(y * _w * 4, (y + 1) * _w * 4, src, (_h - 1 - y) * _w * 4);
    }
    return out;
  }

  double get ev100 => math.log(native.aperture * native.aperture / native.shutterSpeed * 100 / native.sensitivity) / math.ln2;

  void dispose() {
    world.cleanup();
    calloc.free(_pixels);
    engine.dispose();
  }
}

/// Mean RGB of the 7×7 patch [cm] to the right of the image centre.
List<double> _probe(Uint8List rgba, double cm) {
  final cx = _w ~/ 2 + (cm / _cmPerPixel).round();
  final cy = _h ~/ 2;
  final sum = [0.0, 0.0, 0.0];
  for (var y = cy - 3; y <= cy + 3; y++) {
    for (var x = cx - 3; x <= cx + 3; x++) {
      final i = (y * _w + x) * 4;
      for (var k = 0; k < 3; k++) {
        sum[k] += rgba[i + k];
      }
    }
  }
  return [for (final s in sum) s / 49];
}

String _fmt(List<double> rgb) => '(${rgb.map((v) => v.round()).join(', ')})';

void main() {
  test('Point light exposure smoke: the user\'s red point light lights a sunless floor', () async {
    final f = _Frame();
    addTearDown(f.dispose);
    await f.floorAndProps();
    // The user's light: 55 695 lm, #D22121, 2000 cm, shadows, 1.5 m up.
    f.world.persistentLevel.registerActor(LuminaActor(
      root: LuminaPointLightComponent(
        location: Vector3(0, 150, 0),
        color: luminaLightColorFromHex('#D22121'),
        intensity: 55695,
        falloffRadius: 2000,
        castShadows: true,
      ),
    ));
    final frame = f.capture();
    final under = _probe(frame, 0);
    final twoMetres = _probe(frame, 200);
    SmokeArtifacts.saveScreenshot(
      'Point light exposure smoke: the user\'s red point light lights a sunless floor',
      SmokeArtifacts.encodePng(_w, _h, frame),
      usedAssets: _props,
      metrics: {'ev100': f.ev100, 'under_light_rgb': _fmt(under), 'at_2m_rgb': _fmt(twoMetres)},
    );
    expect(f.ev100, lessThan(LuminaAutoExposure.daylightEv100 - 5), reason: 'a lamp-lit level is not exposed for the sun');
    expect(under[0], greaterThan(120), reason: 'the floor under the lamp is lit: ${_fmt(under)}');
    expect(under[0], greaterThan(under[1] * 2.5), reason: 'and red: ${_fmt(under)}');
    expect(twoMetres[0], greaterThan(40), reason: 'still lit 2 m away: ${_fmt(twoMetres)}');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('Point light exposure smoke: black outside the attenuation radius', () async {
    final f = _Frame();
    addTearDown(f.dispose);
    await f.floorAndProps();
    f.world.persistentLevel.registerActor(LuminaActor(
      root: LuminaPointLightComponent(
        location: Vector3(0, 150, 0),
        color: luminaLightColorFromHex('#D22121'),
        intensity: 55695,
        falloffRadius: 400,
      ),
    ));
    final frame = f.capture();
    final inside = _probe(frame, 150);
    final outside = _probe(frame, 600);
    SmokeArtifacts.saveScreenshot(
      'Point light exposure smoke: black outside the attenuation radius',
      SmokeArtifacts.encodePng(_w, _h, frame),
      usedAssets: _props,
      metrics: {'ev100': f.ev100, 'inside_1_5m_rgb': _fmt(inside), 'outside_6m_rgb': _fmt(outside)},
    );
    expect(inside[0], greaterThan(60), reason: 'lit inside the 4 m radius: ${_fmt(inside)}');
    expect(outside.reduce(math.max), lessThan(8), reason: 'black at 6 m, outside the radius: ${_fmt(outside)}');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('Point light exposure smoke: a spot light pointing down lights its cone', () async {
    final f = _Frame();
    addTearDown(f.dispose);
    await f.floorAndProps();
    // The user's spot light: 50 000 lm, white, 2000 cm, 30°/45°, 3 m up,
    // pointing straight down.
    f.world.persistentLevel.registerActor(LuminaActor(
      root: LuminaSpotLightComponent(
        location: Vector3(0, 300, 0),
        rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -math.pi / 2),
        intensity: 50000,
        falloffRadius: 2000,
        innerConeAngleDegrees: 30,
        outerConeAngleDegrees: 45,
      ),
    ));
    final frame = f.capture();
    final centre = _probe(frame, 0);
    final outside = _probe(frame, 450); // tan(45°) · 3 m = 3 m cone edge
    SmokeArtifacts.saveScreenshot(
      'Point light exposure smoke: a spot light pointing down lights its cone',
      SmokeArtifacts.encodePng(_w, _h, frame),
      usedAssets: _props,
      metrics: {'ev100': f.ev100, 'cone_centre_rgb': _fmt(centre), 'outside_cone_4_5m_rgb': _fmt(outside)},
    );
    expect(centre.reduce(math.min), greaterThan(120), reason: 'the cone is lit: ${_fmt(centre)}');
    expect(outside.reduce(math.max), lessThan(8), reason: 'dark outside the 45° cone: ${_fmt(outside)}');
  }, timeout: const Timeout(Duration(minutes: 3)));

  // A 10 000 lm white bulb 1.5 m above a mid-grey floor (#8C8C8C) reads as a
  // bright lamp under auto exposure: the floor under it renders
  // in 150–235 (sRGB, 0–255) — well lit, not clipped. Alone, 1 000 lm and
  // 100 000 lm bulbs are exposed to the same brightness (1 000 lm sits at the
  // EV100 3 floor); side by side, the brightest sets the exposure and the
  // others are 10× and 100× dimmer.
  const brightRange = (150.0, 235.0);
  for (final lumens in [1000.0, 10000.0, 100000.0]) {
    final name = 'Point light exposure smoke: a ${lumens.toInt()} lm bulb at 1.5 m reads as a bright lamp';
    test(name, () async {
      final f = _Frame();
      addTearDown(f.dispose);
      await f.floorAndProps();
      f.world.persistentLevel.registerActor(LuminaActor(
        root: LuminaPointLightComponent(location: Vector3(0, 150, 0), intensity: lumens, falloffRadius: 1000),
      ));
      final frame = f.capture();
      final under = _probe(frame, 0);
      final luma = 0.2126 * under[0] + 0.7152 * under[1] + 0.0722 * under[2];
      SmokeArtifacts.saveScreenshot(name, SmokeArtifacts.encodePng(_w, _h, frame),
          usedAssets: _props, metrics: {'lumens': lumens, 'ev100': f.ev100, 'under_light_rgb': _fmt(under), 'under_light_luma': luma});
      expect(luma, inInclusiveRange(brightRange.$1, brightRange.$2), reason: '${lumens.toInt()} lm at 1.5 m: ${_fmt(under)}');
    }, timeout: const Timeout(Duration(minutes: 3)));
  }

  test('Point light exposure smoke: 1 000, 10 000 and 100 000 lm side by side', () async {
    final f = _Frame();
    addTearDown(f.dispose);
    await f.floorAndProps();
    final xs = <double, double>{1000.0: -500.0, 10000.0: 0.0, 100000.0: 500.0};
    for (final e in xs.entries) {
      f.world.persistentLevel.registerActor(LuminaActor(
        root: LuminaPointLightComponent(location: Vector3(e.value, 150, 0), intensity: e.key, falloffRadius: 350),
      ));
    }
    final frame = f.capture();
    final luma = {
      for (final e in xs.entries)
        e.key: (() {
          final p = _probe(frame, e.value);
          return 0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2];
        })(),
    };
    SmokeArtifacts.saveScreenshot('Point light exposure smoke: 1 000, 10 000 and 100 000 lm side by side',
        SmokeArtifacts.encodePng(_w, _h, frame),
        usedAssets: _props, metrics: {'ev100': f.ev100, for (final e in luma.entries) 'luma_${e.key.toInt()}_lm': e.value});
    expect(f.ev100, closeTo(LuminaAutoExposure.ev100For([LuminaPointLightComponent(intensity: 100000)]), 1e-3),
        reason: 'the brightest bulb sets the exposure');
    expect(luma[100000.0]!, greaterThan(200), reason: '$luma');
    expect(luma[10000.0]!, lessThan(luma[100000.0]! * 0.75), reason: '$luma');
    expect(luma[1000.0]!, lessThan(luma[10000.0]! * 0.75), reason: '$luma');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('Point light exposure smoke: with a sun the exposure stays sunny 16', () async {
    final f = _Frame();
    addTearDown(f.dispose);
    await f.floorAndProps();
    f.world.persistentLevel.registerActor(LuminaActor(
      root: LuminaDirectionalLightComponent(intensity: 100000, rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -math.pi / 3)),
    ));
    f.world.persistentLevel.registerActor(LuminaActor(
      root: LuminaPointLightComponent(location: Vector3(0, 150, 0), color: luminaLightColorFromHex('#D22121'), intensity: 55695, falloffRadius: 2000),
    ));
    final frame = f.capture();
    final under = _probe(frame, 0);
    SmokeArtifacts.saveScreenshot(
      'Point light exposure smoke: with a sun the exposure stays sunny 16',
      SmokeArtifacts.encodePng(_w, _h, frame),
      usedAssets: _props,
      metrics: {'ev100': f.ev100, 'under_light_rgb': _fmt(under)},
    );
    expect(f.ev100, closeTo(LuminaAutoExposure.daylightEv100, 1e-3));
    expect(under.reduce(math.min), greaterThan(60), reason: 'the sunlit floor: ${_fmt(under)}');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
