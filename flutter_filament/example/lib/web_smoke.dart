// The web smoke app: a FilamentWidget on a
// WebGL2 canvas showing Suzanne (the embedded filamesh, default material,
// one sun). It reports to the page for test/web/widget_web_smoke_test.dart:
//   window.flutterFilamentSmoke = {created, frames, disposed}
// and unmounts the widget once the page sets window.flutterFilamentUnmount.
//
// Build: flutter build web -t lib/web_smoke.dart   (web/flutter_filament.{js,wasm} copied into example/web/)
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:flutter_filament/flutter_filament.dart';

void main() => runApp(const WebSmokeApp());

class WebSmokeApp extends StatefulWidget {
  const WebSmokeApp({super.key});

  @override
  State<WebSmokeApp> createState() => _WebSmokeAppState();
}

class _WebSmokeAppState extends State<WebSmokeApp> {
  int _created = 0;
  int _frames = 0;
  bool _mounted = true;
  bool _disposed = false;
  Timer? _hashPoll;

  void _report() {
    final state = JSObject()
      ..['created'] = _created.toJS
      ..['frames'] = _frames.toJS
      ..['disposed'] = _disposed.toJS;
    globalContext['flutterFilamentSmoke'] = state;
  }

  @override
  void initState() {
    super.initState();
    _report();
    _hashPoll = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_mounted && globalContext['flutterFilamentUnmount'] != null) setState(() => _mounted = false);
    });
  }

  @override
  void dispose() {
    _hashPoll?.cancel();
    super.dispose();
  }

  void _sceneCreated(FilamentEngine engine, FilamentScene scene, FilamentCamera camera, FilamentView view) {
    _created++;
    final material = FilamentMaterial.internal(engine.defaultMaterialPointer, engine);
    final suzanne = FilamentRenderableManager(engine).createSuzanneMonkeyMesh(material.defaultInstance);
    scene.addEntity(suzanne);
    final sun = engine.createEntity();
    LightBuilder(LightType.directional).color(1.0, 0.97, 0.9).intensity(110000.0).direction(-0.4, -0.7, -0.6).build(engine, sun);
    scene.addEntity(sun);
    camera.lookAt(eyeX: 0, eyeY: 0.4, eyeZ: 4.2, centerX: 0, centerY: 0, centerZ: 0);
    _report();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF101014),
        body: _mounted
            ? FilamentWidget(
                onSceneCreated: _sceneCreated,
                onFrame: (_, _) {
                  _frames++;
                  if (_frames % 10 == 0) _report();
                },
                onDispose: () {
                  _disposed = true;
                  _report();
                },
              )
            : const Center(child: Text('unmounted', style: TextStyle(color: Colors.white))),
      ),
    );
  }
}
