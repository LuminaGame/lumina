// The UMG Viewport Direct-path smoke app: a game presented directly into
// its window (Filament presents, the UI is captured and blended over every
// frame) with UMG Viewports over it. It measures the game alone, with one
// Viewport (the mannequin playing its idle, its skeleton drawn as Filament
// lines) and with two (plus a barrel), then waits for an OS click on the
// mannequin's head and reports the pick. Needs a runner with the game
// window channel (GameWindowRunnerService.apply) and the props in the
// project folder named by LUMINA_VIEWPORT_PROJECT; writes its state to the
// JSON file named by LUMINA_VIEWPORT_REPORT twice a second:
//   {phase, presentation, measures: {alone|one|two: {...}}, pickTarget, picks, ...}
//
// Build: flutter build windows -t lib/viewport_direct_smoke.dart --profile
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_filament/flutter_filament.dart' hide BlendMode;
import 'package:lumina/lumina.dart';
import 'package:lumina_widgets/lumina_widgets.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

const _mannequin = 'contents/meshes/skeletal/SKM_Mannequin.lmas';
const _idle = 'contents/animations/Idle/Idle.lmas';
const _barrel = 'contents/meshes/static/SM_Barrel.lmas';
const _acUnit = 'contents/meshes/static/SM_AcUnit.lmas';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LuminaWidgets.ensureInitialized();
  final project = Platform.environment['LUMINA_VIEWPORT_PROJECT'] ?? '';
  LuminaAssets.projectDir = project;
  LuminaGameWindow.backend = LuminaWindowModeChannel();
  runApp(_DirectSmokeApp(report: File(Platform.environment['LUMINA_VIEWPORT_REPORT'] ?? 'viewport_direct_report.json')));
}

class _Game extends LuminaGame {
  @override
  LuminaObject? build(LuminaBuildContext context) {
    final camera = LuminaCameraComponent(rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -math.atan2(300, 900)), fieldOfViewInDegrees: 60)
      ..isActive = true;
    return LuminaNodeGroup(children: [
      LuminaPrimitiveActor(shape: LuminaPrimitiveShape.plane, size: Vector3(1800, 1, 1400), color: Vector3(0.30, 0.33, 0.31)),
      LuminaActor(
        root: LuminaDirectionalLightComponent(
          rotation: Quaternion.axisAngle(Vector3(0, 1, 0), 0.6) * Quaternion.axisAngle(Vector3(1, 0, 0), -0.95),
          intensity: 110000,
          castShadows: true,
        ),
      ),
      LuminaActor(root: LuminaSkyComponent.color(color: Vector4(0.36, 0.48, 0.70, 1), skyIntensity: 30000, iblIntensity: 22000)),
      for (var i = 0; i < 5; i++)
        LuminaActor(root: LuminaStaticMeshComponent(meshAssetPath: i.isEven ? _barrel : _acUnit), location: Vector3(-400.0 + i * 200, 0, -150.0 * (i % 3))),
      LuminaActor(root: camera, location: Vector3(0, 300, 900)),
    ]);
  }
}

class _DirectSmokeApp extends StatefulWidget {
  const _DirectSmokeApp({required this.report});
  final File report;

  @override
  State<_DirectSmokeApp> createState() => _DirectSmokeAppState();
}

class _DirectSmokeAppState extends State<_DirectSmokeApp> {
  final _game = _Game();
  final _heroKey = GlobalKey<LuminaUmgViewportState>();
  final _measures = <String, Map<String, Object?>>{};
  final _picks = <Map<String, Object?>>[];
  final _events = <String>[];
  LuminaViewportController? _hero;
  String _phase = 'starting';
  int _viewports = 0;
  late final Timer _timer;
  final _clock = Stopwatch()..start();
  int _phaseStart = 0;
  int _firstFrame = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _step());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  FilamentRenderer? get _renderer => FilamentDirectPresenter.active?.renderer;

  /// The presented frame rate and GPU time over the phase so far.
  Map<String, Object?> _measure() {
    final renderer = _renderer;
    if (renderer == null) return {'error': 'not presenting directly'};
    final frames = [for (final f in renderer.getFrameInfoHistory(240)) if (f.frameId > _firstFrame) f];
    final gpu = [for (final f in frames) if (!f.isGpuPending && f.gpuFrameDuration > 0) f.gpuFrameDuration / 1e6];
    final cpu = [for (final f in frames) if (f.endFrame > f.beginFrame) (f.endFrame - f.beginFrame) / 1e6];
    final presents = FilamentDirectPresenter.active!.presentTimes(600);
    final since = presents.isEmpty ? <int>[] : presents.where((t) => t >= presents.last - 2000000000).toList();
    final fps = since.length < 2 ? 0.0 : (since.length - 1) / ((since.last - since.first) / 1e9);
    double mean(List<double> l) => l.isEmpty ? double.nan : l.reduce((a, b) => a + b) / l.length;
    String r(double v) => v.isNaN ? 'n/a' : v.toStringAsFixed(3);
    return {
      'viewports': _viewports,
      'frames': frames.length,
      'gpu_ms': r(mean(gpu)),
      'cpu_ms': r(mean(cpu)),
      'presented_fps': fps.toStringAsFixed(1),
      'ui_capture': '${LuminaUiCapture.stats.value}',
    };
  }

  void _startPhase(String phase, int viewports) {
    setState(() => _phase = phase);
    _phaseStart = _clock.elapsedMilliseconds;
    _firstFrame = _renderer?.getFrameInfoHistory(1).firstOrNull?.frameId ?? 0;
    if (viewports != _viewports) setState(() => _viewports = viewports);
  }

  void _step() {
    final flutterPath = Platform.environment['LUMINA_VIEWPORT_PRESENTATION'] == 'flutter';
    final presenting = flutterPath || (LuminaGamePresentation.decision.value.mode == LuminaPresentationMode.direct && _renderer != null);
    final elapsed = _clock.elapsedMilliseconds - _phaseStart;
    switch (_phase) {
      case 'starting':
        if (presenting && _clock.elapsedMilliseconds > 4000) _startPhase('alone', 0);
      case 'alone':
        if (elapsed > 4000) {
          _measures['alone'] = _measure();
          _startPhase('one', 1);
        }
      case 'one':
        if (elapsed > 5000) {
          _measures['one'] = _measure();
          _startPhase('two', 2);
        }
      case 'two':
        if (elapsed > 5000) {
          _measures['two'] = _measure();
          setState(() => _phase = 'pick');
        }
    }
    _write();
  }

  /// Where the mannequin's head is, in the window's client pixels.
  Map<String, Object?>? _pickTarget() {
    final c = _hero;
    final box = _heroKey.currentContext?.findRenderObject() as RenderBox?;
    if (c == null || box == null || !box.attached) return null;
    final hero = c.runtime.nodeIds.firstOrNull;
    if (hero == null) return null;
    final head = c.runtime.jointsOf(hero).where((j) => j.name == 'head').firstOrNull;
    final at = head == null ? null : c.runtime.project(head.position);
    if (at == null) return null;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final origin = box.localToGlobal(Offset.zero);
    // The controller projects to render pixels; the element lays out in logical ones.
    final (rw, rh) = (c.runtime.orbit.width, c.runtime.orbit.height);
    final local = Offset(at.$1 / rw * box.size.width, at.$2 / rh * box.size.height);
    final global = origin + local;
    return {'x': global.dx * dpr, 'y': global.dy * dpr, 'node': hero};
  }

  void _write() {
    final state = {
      'phase': _phase,
      'presentation': '${LuminaGamePresentation.decision.value}',
      'viewports': _viewports,
      'measures': _measures,
      if (_phase == 'pick') 'pickTarget': _pickTarget(),
      'picks': _picks,
      'events': _events.take(40).toList(),
      'dpr': MediaQuery.devicePixelRatioOf(context),
    };
    try {
      widget.report.writeAsStringSync(jsonEncode(state));
    } catch (_) {}
  }

  Map<String, Object?> _heroScene() {
    final scene = LuminaViewportScene()..setEnvironment(LuminaViewportEnvironmentMode.sky);
    final hero = scene.addNode(LuminaViewportNodeKind.skeletalMesh, asset: _mannequin);
    scene
      ..playAnimation(hero, _idle)
      ..showSkeleton(hero, [1.0, 0.85, 0.2, 1.0]);
    return scene.json;
  }

  Map<String, Object?> _barrelScene() {
    final scene = LuminaViewportScene()
      ..setEnvironment(LuminaViewportEnvironmentMode.sky)
      ..setInteraction(autoRotate: 30.0);
    scene.addNode(LuminaViewportNodeKind.staticMesh, asset: _barrel);
    return scene.json;
  }

  void _onEvent(String event, Map<String, Object?> args) {
    _events.add(event);
    if (event == LuminaWidgetEvents.onPicked) {
      setState(() => _picks.add({'node': args['node_id'], 'bone': args['bone'], 'ms': _clock.elapsedMilliseconds}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final panel = BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0), width: 2));
    return Directionality(
      textDirection: TextDirection.ltr,
      child: LuminaGameWidget(
        game: _game,
        decorated: false,
        allowDirectPresentation: true,
        // LUMINA_VIEWPORT_PRESENTATION=flutter compares the Flutter path.
        presentation: Platform.environment['LUMINA_VIEWPORT_PRESENTATION'] == 'flutter' ? LuminaPresentationMode.flutter : LuminaPresentationMode.direct,
        viewportOverlay: Stack(children: [
          if (_viewports >= 1)
            Positioned(
              left: 24,
              top: 24,
              width: 360,
              height: 420,
              child: DecoratedBox(
                decoration: panel,
                child: LuminaUmgViewport(
                  key: _heroKey,
                  name: 'Hero',
                  designScene: _heroScene(),
                  onController: (c) => _hero = c,
                  onEvent: _onEvent,
                ),
              ),
            ),
          if (_viewports >= 2)
            Positioned(
              right: 24,
              top: 24,
              width: 300,
              height: 300,
              child: DecoratedBox(
                decoration: panel,
                child: LuminaUmgViewport(name: 'Barrel', designScene: _barrelScene(), onEvent: _onEvent),
              ),
            ),
          Positioned(
            left: 24,
            bottom: 16,
            child: Text('Direct · $_phase · Viewports: $_viewports · picks: ${_picks.length}',
                style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 16)),
          ),
        ]),
      ),
    );
  }
}
