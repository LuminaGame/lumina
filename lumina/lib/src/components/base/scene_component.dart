import 'package:vector_math/vector_math_64.dart';
import '../../math/euler.dart';
import 'actor_component.dart';

/// Transform component that has a position, rotation, and scale in 3D space.
///
/// **Rotation convention.** A rotation means what
/// `Matrix4.compose` draws: the standard `R(q)·v = q·v·q*`. The runtime is
/// Y-up with −Z forward and +X right, so a component's [forwardVector],
/// [rightVector] and [upVector] are its drawn −Z, +X and +Y, a child at a
/// relative offset is drawn exactly where [worldLocation] says, and
/// [worldRotation] composes parent-first (`parent * relative`). Never use
/// vector_math's `Quaternion.rotate`/`rotated` for directions: they apply the
/// inverse rotation (and `rotate` overwrites its argument). Use
/// `rotateVector` (local → world) and `unrotateVector` (world → local) from
/// `math/euler.dart`. Gameplay rotations built from a control rotation go
/// through `luminaPawnEulerToQuaternion` / `luminaControlRotationToQuaternion`
/// so positive yaw still turns right.
class LuminaSceneComponent extends LuminaActorComponent {
  final Vector3 _relativeLocation = Vector3.zero();
  Quaternion _relativeRotation = Quaternion.identity();
  final Vector3 _relativeScale = Vector3(1.0, 1.0, 1.0);

  LuminaSceneComponent? _parentComponent;
  final List<LuminaSceneComponent> _childComponents = [];

  bool isVisible = true;
  double minDrawDistance = 0.0;
  double maxDrawDistance = 0.0; // 0.0 means infinite / no distance culling limit

  LuminaSceneComponent({
    super.key,
    Vector3? location,
    Quaternion? rotation,
    Vector3? scale,
    this.isVisible = true,
    this.minDrawDistance = 0.0,
    this.maxDrawDistance = 0.0,
  }) {
    if (location != null) _relativeLocation.setFrom(location);
    if (rotation != null) _relativeRotation = rotation;
    if (scale != null) _relativeScale.setFrom(scale);
  }

  /// Evaluates whether this component should be rendered based on camera distance.
  bool isVisibleAtDistance(double distance) {
    if (!isVisible) return false;
    if (minDrawDistance > 0.0 && distance < minDrawDistance) return false;
    if (maxDrawDistance > 0.0 && distance > maxDrawDistance) return false;
    return true;
  }

  Vector3 get relativeLocation => _relativeLocation;
  set relativeLocation(Vector3 v) {
    _relativeLocation.setFrom(v);
    _onTransformChanged();
  }

  /// Alias for relativeLocation.
  Vector3 get location => relativeLocation;
  set location(Vector3 v) => relativeLocation = v;

  Quaternion get relativeRotation => _relativeRotation;
  set relativeRotation(Quaternion q) {
    _relativeRotation = q;
    _onTransformChanged();
  }

  /// Alias for relativeRotation.
  Quaternion get rotation => relativeRotation;
  set rotation(Quaternion q) => relativeRotation = q;

  Vector3 get relativeScale => _relativeScale;
  set relativeScale(Vector3 v) {
    _relativeScale.setFrom(v);
    _onTransformChanged();
  }

  LuminaSceneComponent? get parentComponent => _parentComponent;
  List<LuminaSceneComponent> get childComponents => List.unmodifiable(_childComponents);

  /// Attaches this scene component to a parent scene component.
  void attachToComponent(LuminaSceneComponent parent) {
    if (_parentComponent == parent) return;
    _parentComponent?._childComponents.remove(this);
    _parentComponent = parent;
    parent._childComponents.add(this);
    _onTransformChanged();
  }

  /// Detaches from the parent; the relative transform is kept as is (the
  /// caller re-bases it when the world transform should stay).
  void detachFromParent() {
    if (_parentComponent == null) return;
    _parentComponent!._childComponents.remove(this);
    _parentComponent = null;
    _onTransformChanged();
  }

  /// Calculates world space location.
  Vector3 get worldLocation {
    if (_parentComponent == null) return _relativeLocation.clone();
    // The parent's drawn rotation applied to a copy of the offset (never
    // rotate the relative location itself).
    return _parentComponent!.worldLocation + _parentComponent!.worldRotation.rotateVector(_relativeLocation);
  }

  /// Calculates world space rotation.
  Quaternion get worldRotation {
    if (_parentComponent == null) return _relativeRotation;
    return _parentComponent!.worldRotation * _relativeRotation;
  }

  /// Calculates world space transform matrix.
  Matrix4 get worldTransform => Matrix4.compose(worldLocation, worldRotation, _relativeScale);

  /// Forward direction vector: the drawn −Z.
  Vector3 get forwardVector => worldRotation.rotateVector(Vector3(0, 0, -1));

  /// Right direction vector: the drawn +X.
  Vector3 get rightVector => worldRotation.rotateVector(Vector3(1, 0, 0));

  /// Up direction vector: the drawn +Y.
  Vector3 get upVector => worldRotation.rotateVector(Vector3(0, 1, 0));

  /// Hook invoked whenever this component's local or inherited transform changes.
  void onTransformChanged() {}

  void _onTransformChanged() {
    onTransformChanged();
    for (final child in _childComponents) {
      child._onTransformChanged();
    }
  }
}
