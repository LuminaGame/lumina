// The UMG Viewport web smoke app: three Viewports side by side, each
// previewing a prop that the camera frames once it loads and orbits slowly.
// The web renders at most two Viewports at once; the third shows the
// "Viewport limit reached" placeholder. Meshes are fetched from the serving
// page (`viewport_assets/<project path>`). It reports to the page for
// lumina_widgets/test/smoke/umg_viewport_web_smoke_test.dart:
//   window.luminaViewportSmoke = {ready, failed, controllers, refused, frames}
//
// Build: flutter build web -t lib/viewport_web_smoke.dart
//   (flutter_filament/web/flutter_filament.{js,wasm} copied into example/web/)
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_widgets/lumina_widgets.dart';

/// The props, by project path (the test writes them next to the page).
const _props = [
  'contents/meshes/static/SM_Barrel.lmas',
  'contents/meshes/static/SM_AcUnit.lmas',
  'contents/meshes/static/SM_Hat_B.lmas',
];

Future<Uint8List> _fetch(String path) async {
  final response = await globalContext.callMethod<JSPromise<JSObject>>('fetch'.toJS, 'viewport_assets/$path'.toJS).toDart;
  if (!(response['ok']! as JSBoolean).toDart) {
    throw StateError('$path: HTTP ${(response['status']! as JSNumber).toDartInt}');
  }
  final buffer = await response.callMethod<JSPromise<JSArrayBuffer>>('arrayBuffer'.toJS).toDart;
  return buffer.toDart.asUint8List();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FilamentWeb.ensureInitialized();
  LuminaAssets.defaultProvider = _fetch;
  runApp(const ViewportWebSmokeApp());
}

class ViewportWebSmokeApp extends StatefulWidget {
  const ViewportWebSmokeApp({super.key});

  @override
  State<ViewportWebSmokeApp> createState() => _ViewportWebSmokeAppState();
}

class _ViewportWebSmokeAppState extends State<ViewportWebSmokeApp> {
  final _keys = [for (var i = 0; i < _props.length; i++) GlobalKey<LuminaUmgViewportState>()];
  final _controllers = <int, LuminaViewportController>{};
  int _ready = 0;
  final _failed = <String>[];
  late final Timer _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(milliseconds: 200), (_) => _report());
  }

  @override
  void dispose() {
    _poll.cancel();
    super.dispose();
  }

  void _report() {
    final refused = _keys.where((k) => k.currentState?.showsLimitPlaceholder ?? false).length;
    final frames = [for (final c in _controllers.values) c.clock.framesRendered];
    globalContext['luminaViewportSmoke'] = JSObject()
      ..['ready'] = _ready.toJS
      ..['failed'] = _failed.join('\n').toJS
      ..['controllers'] = _controllers.length.toJS
      ..['refused'] = refused.toJS
      ..['frames'] = frames.fold<int>(0, (a, b) => a + b).toJS
      ..['cameras'] = [
        for (final c in _controllers.values)
          '${c.runtime.boundsOf('*')?.min} ${c.runtime.boundsOf('*')?.max} d=${c.runtime.orbit.distance.round()} '
              '${c.runtime.orbit.width.round()}x${c.runtime.orbit.height.round()}',
      ].join(' | ').toJS;
  }

  Map<String, Object?> _scene(String mesh) {
    final scene = LuminaViewportScene()
      ..setEnvironment(LuminaViewportEnvironmentMode.sky)
      ..setInteraction(autoRotate: 24.0);
    scene.addNode(LuminaViewportNodeKind.staticMesh, asset: mesh);
    return scene.json;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF101014),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _props.length; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                Expanded(
                  child: LuminaUmgViewport(
                    key: _keys[i],
                    name: 'Viewport$i',
                    designScene: _scene(_props[i]),
                    onController: (c) => c == null ? _controllers.remove(i) : _controllers[i] = c,
                    onEvent: (event, args) {
                      if (event == LuminaWidgetEvents.onSceneReady) _ready++;
                      if (event == LuminaWidgetEvents.onAssetLoadFailed) _failed.add('${args['asset']}: ${args['message']}');
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
