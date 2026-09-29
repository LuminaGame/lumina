@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;
import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

/// flutter_filament's public Dart API in a browser: an engine on a
/// WebGL2 canvas, the ubershader provider, a real GLB (gltfio + default
/// resource providers) and a pick callback through the function table.
/// The frame is printed as `SMOKE_PNG <name> <base64>` for
/// tool/web/run_browser_tests.dart to publish in the smoke report.
const _w = 320;
const _h = 240;

Future<Uint8List> _fetch(String url) async {
  final r = await web.window.fetch(url.toJS).toDart;
  if (!r.ok) throw StateError('$url -> ${r.status}');
  return (await r.arrayBuffer().toDart).toDart.asUint8List();
}

void _printPng(String name, web.HTMLCanvasElement canvas) {
  final data = canvas.toDataURL('image/png');
  // ignore: avoid_print
  print('SMOKE_PNG $name ${data.substring(data.indexOf(',') + 1)}');
}

void main() {
  setUpAll(() => FilamentWeb.ensureInitialized(moduleUrl: '/web/module/flutter_filament.js'));

  test('web api: a gltf barrel renders through the Dart API and pick calls back', () async {
    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement
      ..id = 'filament'
      ..width = _w
      ..height = _h;
    web.document.body!.append(canvas);
    addTearDown(() => canvas.remove());

    final engine = FilamentEngine.createForCanvas('#filament');
    expect(engine, isNotNull, reason: 'no WebGL2 engine on the canvas');
    addTearDown(engine!.dispose);
    final swapChain = engine.createSwapChain(ffi.nullptr);
    final renderer = engine.createRenderer();
    final scene = engine.createScene();
    final view = engine.createView();
    final camera = engine.createCamera(engine.createEntity());
    view
      ..scene = scene
      ..camera = camera
      ..setViewport(0, 0, _w, _h);
    renderer.setClearOptions(r: 0.05, g: 0.10, b: 0.25, a: 1);

    final sun = engine.createEntity();
    LightBuilder(LightType.directional)
        .color(1.0, 0.97, 0.9)
        .intensity(100000.0)
        .direction(-0.5, -0.8, -0.35)
        .build(engine, sun);
    scene.addEntity(sun);

    expect(c.filament_gltfio_is_webp_supported(), isTrue, reason: 'the barrel texture is WebP (EXT_texture_webp)');
    final provider = FilamentMaterialProvider.createUbershader(engine: engine);
    final loader = FilamentAssetLoader.create(engine: engine, materialProvider: provider);
    final asset = loader.createAsset(await _fetch('/web/test_assets/Props/Barrels/empty_barrel.glb'));
    expect(asset, isNotNull, reason: 'gltfio rejected the GLB');
    final resources = FilamentResourceLoader.create(engine: engine)..registerDefaultProviders(engine);
    expect(resources.loadResources(asset!), isTrue, reason: 'textures and buffers');
    asset.addToScene(scene);
    expect(asset.renderableEntities, isNotEmpty);

    final box = asset.getBoundingBox();
    final center = box.center;
    final extent = box.max - box.min;
    final radius = [extent.x, extent.y, extent.z].reduce((a, b) => a > b ? a : b) / 2;
    final dist = radius * 2.6 + 0.1;
    camera.setProjection(fovDegrees: 45, aspect: _w / _h, near: dist * 0.01, far: dist * 20);
    camera.lookAt(eyeX: center.x + dist * 0.6, eyeY: center.y + dist * 0.35, eyeZ: center.z + dist,
        centerX: center.x, centerY: center.y, centerZ: center.z);

    Future<void> frame() async {
      if (renderer.beginFrame(swapChain)) {
        renderer.render(view);
        renderer.endFrame();
      }
      engine.flushAndWait();
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }

    for (var i = 0; i < 6; i++) {
      await frame();
    }

    // A pick through a NativeCallable: Filament calls back once the frame
    // that serviced it has completed.
    final picked = view.pick(_w ~/ 2, _h ~/ 2);
    PickingResult? result;
    unawaited(picked.then((r) => result = r));
    for (var i = 0; i < 30 && result == null; i++) {
      await frame();
    }
    expect(result, isNotNull, reason: 'the pick callback never fired');
    expect(result!.renderable, isNotNull, reason: 'the centre pixel is the barrel');
    expect(asset.renderableEntities, contains(result!.renderable!.id));

    // The canvas holds the frame: read it back through the WebGL context.
    renderer.beginFrame(swapChain);
    renderer.render(view);
    renderer.endFrame();
    engine.flushAndWait();
    final gl = canvas.getContext('webgl2') as web.WebGL2RenderingContext;
    final pixels = Uint8List(_w * _h * 4);
    gl.readPixels(0, 0, _w, _h, web.WebGL2RenderingContext.RGBA, web.WebGL2RenderingContext.UNSIGNED_BYTE, pixels.toJS);
    expect(gl.getError(), 0);
    // Background: the corner's colour (the clear colour after tone mapping).
    final bg = pixels.sublist(0, 4);
    var background = 0;
    for (var i = 0; i < pixels.length; i += 4) {
      if ((pixels[i] - bg[0]).abs() < 6 && (pixels[i + 1] - bg[1]).abs() < 6 && (pixels[i + 2] - bg[2]).abs() < 6) background++;
    }
    final foreground = _w * _h - background;
    expect(foreground, greaterThan(_w * _h ~/ 20), reason: 'the barrel covers part of the frame');
    expect(background, greaterThan(_w * _h ~/ 20), reason: 'the clear colour stays visible around it');
    final mid = ((_h ~/ 2) * _w + _w ~/ 2) * 4;
    final centre = pixels.sublist(mid, mid + 3);
    expect(centre.reduce((a, b) => a + b), greaterThan(90), reason: 'the barrel is textured, not black: $centre');
    _printPng('web api: gltf barrel through the Dart API', canvas);
    // ignore: avoid_print
    print('web api smoke: renderables=${asset.renderableEntityCount} foreground=$foreground background=$background centre=$centre picked=${result!.renderable!.id}');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
