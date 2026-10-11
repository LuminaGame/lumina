import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../components/pose_authoring/pose_fixture.dart';

export '../../components/pose_authoring/pose_fixture.dart';

/// A grabber played from a script: the test moves it and presses its grip
/// step by step, and it records the haptic pulses it was asked for. A real
/// implementation of the grabber interface, not a stand-in for an engine
/// class.
class ScriptedGrabber implements LuminaGrabber {
  ScriptedGrabber(this.id, {Vector3? at, this.hasHaptics = true}) {
    if (at != null) position.setFrom(at);
  }

  @override
  final String id;
  final bool hasHaptics;

  final Vector3 position = Vector3.zero();
  Quaternion rotation = Quaternion.identity();
  double gripValue = 0;
  bool tracked = true;
  LuminaGrabRay? rayValue;
  final List<(double, double)> pulses = [];
  final List<Vector3> grabbedPoints = [];

  @override
  Matrix4 get worldTransform => Matrix4.compose(position, rotation, Vector3.all(1));

  @override
  double get grip => gripValue;

  @override
  bool get isTracked => tracked;

  @override
  LuminaGrabRay? get ray => rayValue;

  @override
  void pulse(double amplitude, double seconds) {
    if (hasHaptics) pulses.add((amplitude, seconds));
  }

  @override
  void grabbedAt(Vector3 point) => grabbedPoints.add(point.clone());
}

/// A posable MetaHuman-named character (standalone, solving its own pose
/// array) and an interactor that grabs its handles.
class GrabRun {
  GrabRun({double lowerArm = 0.28})
      : run = PoseRun(LuminaPoseRig.detect(metahumanSkeleton(lowerArm: lowerArm)), mesh: meshAt(Vector3(0, 0, 0))) {
    // The arms hang relaxed (bent, in reach of every drag the tests make):
    // posed once and baked into the base pose, so no handle holds a target.
    final poser = run.component..captureMode = LuminaPoseCaptureMode.bakeToPose;
    for (final (side, x) in const [('l', 1.0), ('r', -1.0)]) {
      poser.setHandleTarget('hand_$side', run.at('upperarm_$side') + Vector3(18 * x, -28, 18));
    }
    run.tick();
    for (final side in const ['l', 'r']) {
      poser.clearHandle('hand_$side');
    }
    run.tick();
    poser.captureMode = LuminaPoseCaptureMode.holdTargets;
    interactor.register(run.component);
    interactor
      ..onHandleGrabbed = ((h, g) => grabbed.add('${h.handle}@$g'))
      ..onHandleReleased = ((h, g) => released.add('${h.handle}@$g'))
      ..onHandleHovered = ((h, g) => hovered.add('${h?.handle}@$g'));
  }

  final PoseRun run;
  final LuminaPoseGrabInteractor interactor = LuminaPoseGrabInteractor(findPosersInReach: false, showHandles: false);
  final List<String> grabbed = [], released = [], hovered = [];

  LuminaPoseAuthoringComponent get poser => run.component;

  /// One frame: the character solves, and the interactor drives its handles
  /// first through the solve's hook.
  void tick([int frames = 1]) => run.tick(frames);

  Vector3 handle(String name) => poser.handleWorldLocation(name)!;
}
