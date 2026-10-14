import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:vector_math/vector_math_64.dart';

/// The Garment editor's 3D scene in the viewport's editor world: a sun and
/// sky, the body (a skeletal mesh at the origin, its mesh space being the
/// world's: Y up, cm) and the garment's source mesh at its placement.
class GarmentPreviewScene {
  LuminaWorld? _world;
  final List<LuminaActor> _environment = [];
  LuminaActor? _bodyActor, _garmentActor;
  LuminaStaticMeshComponent? _garment;
  String? _bodyPath, _garmentPath, _garmentMaterials;
  LuminaAssetProvider? _garmentProvider;
  Timer? _timer;

  bool get isAttached => _world != null && !_world!.isCleanedUp;
  LuminaAnimatedMeshComponent? get body => _bodyActor?.rootComponent as LuminaAnimatedMeshComponent?;
  LuminaStaticMeshComponent? get garment => _garment;

  /// Binds the viewport's world and ticks it at 60 Hz (transforms reach the
  /// renderer on a tick).
  void attach(LuminaWorld world) {
    detach();
    _world = world;
    _mountEnvironment();
    final body = _bodyPath, garment = _garmentPath;
    _bodyPath = _garmentPath = null;
    if (body != null) setBody(body);
    if (garment != null) setGarment(garment, provider: _garmentProvider, materialsFrom: _garmentMaterials);
    _timer = Timer.periodic(const Duration(microseconds: 16667), (_) => _tick());
  }

  void _tick() {
    final w = _world;
    if (w == null || w.isCleanedUp) return;
    try {
      w.tick(0.0);
    } catch (e) {
      debugPrint('[GarmentPreviewScene] tick: $e');
    }
  }

  void _mountEnvironment() {
    final w = _world!;
    if (!w.hasNativeContext) return;
    for (final a in [
      LuminaActor(
        key: const LuminaObjectKey('garment_preview_sun'),
        root: LuminaDirectionalLightComponent(
          rotation: Quaternion.euler(35 * math.pi / 180, -50 * math.pi / 180, 0),
          color: Vector3(1.0, 0.97, 0.92),
          intensity: 90000.0,
          castShadows: true,
          isSun: true,
        ),
      ),
      LuminaActor(
        key: const LuminaObjectKey('garment_preview_sky'),
        root: LuminaSkyComponent.color(color: Vector4(0.10, 0.11, 0.14, 1.0), skyIntensity: 14000.0, iblIntensity: 22000.0),
      ),
    ]) {
      w.persistentLevel.registerActor(a);
      _environment.add(a);
    }
  }

  /// Shows the body at [path] (an absolute mesh path; '' hides it).
  void setBody(String path) {
    if (path == _bodyPath) return;
    _bodyPath = path;
    final w = _world;
    if (w == null) return;
    if (_bodyActor != null) w.persistentLevel.unregisterActor(_bodyActor!);
    _bodyActor = null;
    if (path.isEmpty) return;
    final actor = LuminaActor(
      key: const LuminaObjectKey('garment_preview_body'),
      root: LuminaAnimatedMeshComponent(meshAssetPath: path),
    );
    w.persistentLevel.registerActor(actor);
    _bodyActor = actor;
  }

  /// Shows the garment mesh at [path] (an absolute mesh path, or a key
  /// [provider] serves; '' hides it), drawn with the slot materials of
  /// [materialsFrom] when given (a fitted garment: its source mesh's).
  void setGarment(String path, {LuminaAssetProvider? provider, String? materialsFrom}) {
    if (path == _garmentPath && provider == _garmentProvider && materialsFrom == _garmentMaterials) return;
    _garmentPath = path;
    _garmentProvider = provider;
    _garmentMaterials = materialsFrom;
    final w = _world;
    if (w == null) return;
    if (_garmentActor != null) w.persistentLevel.unregisterActor(_garmentActor!);
    _garmentActor = null;
    _garment = null;
    if (path.isEmpty) return;
    final mesh = LuminaStaticMeshComponent(meshAssetPath: path, assetProvider: provider)..slotMaterialSource = materialsFrom;
    final actor = LuminaActor(key: const LuminaObjectKey('garment_preview_garment'), root: mesh);
    w.persistentLevel.registerActor(actor);
    _garmentActor = actor;
    _garment = mesh;
  }

  /// Puts the garment at [doc]'s placement (identity for a fitted garment,
  /// which is already in the body's space: pass [placed] false).
  void place(LuminaGarmentDocument doc, {bool placed = true}) {
    final g = _garment;
    if (g == null) return;
    if (!placed) {
      g
        ..relativeLocation = Vector3.zero()
        ..relativeRotation = Quaternion.identity()
        ..relativeScale = Vector3.all(1);
      return;
    }
    final q = LuminaGarmentMath.quaternionFromEuler(doc.rotation);
    g
      ..relativeLocation = Vector3(doc.location[0], doc.location[1], doc.location[2])
      ..relativeRotation = Quaternion(q[0], q[1], q[2], q[3])
      ..relativeScale = Vector3(doc.scale[0], doc.scale[1], doc.scale[2]);
  }

  void detach() {
    _timer?.cancel();
    _timer = null;
    final w = _world;
    if (w != null && !w.isCleanedUp) {
      for (final a in [?_bodyActor, ?_garmentActor, ..._environment]) {
        try {
          w.persistentLevel.unregisterActor(a);
        } catch (e) {
          debugPrint('[GarmentPreviewScene] detach: $e');
        }
      }
    }
    _environment.clear();
    _bodyActor = _garmentActor = null;
    _garment = null;
    _world = null;
  }
}
