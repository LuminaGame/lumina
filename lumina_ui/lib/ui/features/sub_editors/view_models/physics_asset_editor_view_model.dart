import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina_ui/ui/features/sub_editors/models/physics_asset_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/physics_preview_scene.dart';

/// Drives the Physics Asset sub-editor.
///
/// Loads a real PHYSICS_ASSET `.lmas`, resolves the skeletal mesh it references
/// through an `AssetReference{slot_name: 'skeletal_mesh'}`, parses that mesh's
/// real bone hierarchy, and authors per-bone bodies, constraints and
/// disabled-collision pairs into a versioned document persisted back into the
/// asset's metadata.
///
/// `Validate Overlaps` runs lumina's real narrow phase (`testPair`) over the
/// authored bodies in **bind pose** — that is the only physics the engine
/// actually runs; there is no dynamics solver, so nothing here simulates.
///
/// Everything is in world units, **centimetres**: the mesh is drawn at [meshUnitScale], bone transforms are expressed
/// at that scale, and bodies, offsets and overlap depths are cm.
class PhysicsAssetEditorViewModel extends ChangeNotifier {
  static const String metadataKey = 'physics_asset';
  static const String skeletalMeshSlot = 'skeletal_mesh';

  /// Mesh asset units -> world units. glTF is metres and the world is cm, so
  /// the preview draws the skeletal mesh at this scale (lumina's
  /// `assetUnitScale`) and every bone transform here uses it too.
  static const double meshUnitScale = LuminaUnits.unitsPerMetre;

  /// Smallest body length an edit accepts: 1 mm, in cm.
  static const double _minLength = 0.1;

  final String assetPath;

  LuminaAsset? _asset;
  GlbMeshData? _glbMesh;
  String? _skeletalMeshPath;
  String? _skeletalMeshAssetId;
  String? _linkError;

  bool _isLoading = true;
  bool _hasError = false;
  bool _isDirty = false;
  String? _lastError;

  PhysicsAssetDocument _document = PhysicsAssetDocument();
  final List<GlbNode> _allBones = [];
  final List<GlbNode> _rootBones = [];

  /// Bind-pose bone globals in the mesh's own units (glTF metres), for
  /// measuring against the mesh's vertex positions.
  final Map<String, Matrix4> _assetBoneGlobals = {};

  /// The same transforms in world units (cm), where the bodies live.
  final Map<String, Matrix4> _boneGlobals = {};
  final Map<String, GlbNode> _bonesByName = {};

  String? _selectedBodyBone;
  String? _selectedConstraintName;
  String? _selectedBoneName;
  String _boneFilter = '';
  PhysicsViewMode _viewMode = PhysicsViewMode.solidBodies;

  List<PhysicsOverlapResult> _lastValidation = const [];
  bool _hasValidated = false;

  /// World transform of the previewed skeletal-mesh entity; body overlays and
  /// overlap tests use `entityWorld x G_bone x offset`.
  Matrix4 entityWorld = Matrix4.identity();

  PhysicsAssetEditorViewModel({required this.assetPath, LuminaAsset? initialAsset}) : _asset = initialAsset;

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  bool get isDirty => _isDirty;
  String? get lastError => _lastError;
  LuminaAsset? get asset => _asset;
  GlbMeshData? get glbMesh => _glbMesh;

  String? get skeletalMeshPath => _skeletalMeshPath;
  String? get skeletalMeshAssetId => _skeletalMeshAssetId;
  bool get hasSkeletalMesh => _skeletalMeshPath != null && _glbMesh != null;
  String? get linkError => _linkError;

  PhysicsAssetDocument get document => _document;
  List<GlbNode> get allBones => List.unmodifiable(_allBones);
  List<GlbNode> get rootBones => List.unmodifiable(_rootBones);
  List<String> get allBoneNames => _allBones.map((b) => b.name).toList();

  /// Bind-pose bone transforms in world units (cm), as the mesh is drawn.
  Map<String, Matrix4> get boneGlobals => Map.unmodifiable(_boneGlobals);
  Matrix4? boneGlobal(String boneName) => _boneGlobals[boneName];

  /// The bound mesh's bind-pose bounds in world units (cm), as drawn.
  Aabb3? get meshWorldBounds {
    final mesh = _glbMesh;
    if (mesh == null || mesh.positions.isEmpty) return null;
    return Aabb3.minMax(
      Vector3(mesh.minBounds[0], mesh.minBounds[1], mesh.minBounds[2])..scale(meshUnitScale),
      Vector3(mesh.maxBounds[0], mesh.maxBounds[1], mesh.maxBounds[2])..scale(meshUnitScale),
    );
  }

  /// Orbit target and distance (cm) that frame the mesh and every body.
  ({Vector3 target, double distance})? get previewFraming {
    Aabb3? all = meshWorldBounds;
    for (final body in _document.bodies) {
      final centre = bodyWorldTransform(body).getTranslation();
      final reach = math.max(body.effectiveHalfHeight, body.halfExtents.reduce(math.max));
      final box = Aabb3.centerAndHalfExtents(centre, Vector3.all(reach));
      if (all == null) {
        all = box;
      } else {
        all.hull(box);
      }
    }
    if (all == null) return null;
    final span = all.max - all.min;
    final maxSpan = math.max(span.x, math.max(span.y, span.z));
    return (target: all.center, distance: math.max(maxSpan * 1.8, 50.0));
  }

  PhysicsBody? get selectedBody =>
      _selectedBodyBone == null ? null : _document.bodyForBone(_selectedBodyBone!);
  PhysicsConstraint? get selectedConstraint =>
      _selectedConstraintName == null ? null : _document.constraintByName(_selectedConstraintName!);

  String get boneFilter => _boneFilter;
  PhysicsViewMode get viewMode => _viewMode;
  List<PhysicsOverlapResult> get lastValidation => List.unmodifiable(_lastValidation);
  bool get hasValidated => _hasValidated;

  /// Overlap validation always runs against the bind pose (no animation).
  bool get lastValidationIsBindPose => true;

  String get fileBasename =>
      assetPath.split(Platform.pathSeparator).last.replaceAll('.lmas', '');

  // ---------------------------------------------------------------- loading

  Future<void> load() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      final file = File(assetPath);
      if (!file.existsSync()) {
        _hasError = true;
        _isLoading = false;
        notifyListeners();
        return;
      }
      _asset = LuminaAsset.fromBytes(await file.readAsBytes());

      final docRaw = _asset!.metadata[metadataKey];
      if (docRaw != null && docRaw.isNotEmpty) {
        try {
          _document = PhysicsAssetDocument.fromJson(jsonDecode(docRaw) as Map<String, dynamic>);
          if (_document.migratedFromMetres) {
            EngineLoggerService().log(
              'Physics asset $fileBasename was authored in metres: converted its bodies to centimetres '
              '(saved in cm on the next Save).',
              level: 'info',
            );
          }
        } catch (e) {
          _document = PhysicsAssetDocument();
          EngineLoggerService().log('Physics asset document unreadable: $e', level: 'error');
        }
      } else {
        _document = PhysicsAssetDocument();
      }

      final ref = _asset!.references.where((r) => r.slotName == skeletalMeshSlot).firstOrNull;
      if (ref == null || ref.assetPath.isEmpty) {
        _linkError = 'No skeletal mesh is bound to this physics asset. Pick one to author bodies.';
        _skeletalMeshPath = null;
      } else {
        await _loadSkeleton(ref.assetPath, ref.assetId);
      }

      _isDirty = false;
      _isLoading = false;
      notifyListeners();
    } catch (e, st) {
      _hasError = true;
      _isLoading = false;
      EngineLoggerService().log('Failed to load physics asset: $e\n$st', level: 'error');
      notifyListeners();
    }
  }

  Future<void> _loadSkeleton(String meshPath, String? assetId) async {
    _skeletalMeshPath = meshPath;
    _skeletalMeshAssetId = assetId;
    _linkError = null;
    _glbMesh = null;
    _allBones.clear();
    _rootBones.clear();
    _assetBoneGlobals.clear();
    _boneGlobals.clear();
    _bonesByName.clear();

    if (!File(meshPath).existsSync()) {
      _linkError = 'The referenced skeletal mesh is missing on disk: $meshPath';
      _skeletalMeshPath = null;
      return;
    }
    try {
      _glbMesh = await AssetRepository.loadMeshFromDisk(meshPath);
    } catch (e) {
      _linkError = 'The referenced skeletal mesh could not be parsed: $e';
      return;
    }
    final mesh = _glbMesh;
    if (mesh == null) {
      _linkError = _notAMeshReason(meshPath) ?? 'The referenced skeletal mesh could not be parsed.';
      return;
    }

    _allBones.addAll(mesh.allNodes.where((n) => n.type == GlbNodeType.bone));
    if (_allBones.isEmpty) {
      _allBones.addAll(mesh.allNodes.where((n) => n.type != GlbNodeType.mesh));
    }
    for (final b in _allBones) {
      _bonesByName[b.name] = b;
    }
    _rootBones.addAll(mesh.rootNodes.where(_containsBone));
    if (_rootBones.isEmpty && _allBones.isNotEmpty) _rootBones.add(_allBones.first);

    for (final root in mesh.rootNodes) {
      _accumulateGlobals(root, Matrix4.identity());
    }
    if (_allBones.isEmpty) {
      _linkError = 'The referenced skeletal mesh has no bones.';
    }
  }

  /// Names the asset when [path] is a readable `.lmas` that is not a mesh at
  /// all (a texture or material of the same import family, say), so the link
  /// error does not read as a parse failure of a valid mesh.
  static String? _notAMeshReason(String path) {
    if (!path.endsWith('.lmas')) return null;
    try {
      final asset = LuminaAsset.fromBytes(File(path).readAsBytesSync());
      const meshTypes = {AssetType.filamesh, AssetType.filameshSk, AssetType.unknown};
      if (meshTypes.contains(asset.type)) return null;
      return 'The referenced asset "${asset.name}" is a ${asset.type.name} asset, not a skeletal mesh.';
    } catch (_) {
      return null;
    }
  }

  bool _containsBone(GlbNode node) {
    if (node.type == GlbNodeType.bone) return true;
    for (final c in node.children) {
      if (_containsBone(c)) return true;
    }
    return false;
  }

  void _accumulateGlobals(GlbNode node, Matrix4 parent) {
    final global = parent.multiplied(_localTransform(node));
    _assetBoneGlobals[node.name] = global;
    // S(u) x G x S(1/u): the translation scales, the rotation does not.
    _boneGlobals[node.name] = Matrix4.copy(global)..setTranslation(global.getTranslation()..scale(meshUnitScale));
    for (final child in node.children) {
      _accumulateGlobals(child, global);
    }
  }

  static Matrix4 _localTransform(GlbNode node) {
    final t = node.translation;
    final r = node.rotation;
    final s = node.scale;
    return Matrix4.compose(
      Vector3(
        t != null && t.isNotEmpty ? t[0] : 0.0,
        t != null && t.length > 1 ? t[1] : 0.0,
        t != null && t.length > 2 ? t[2] : 0.0,
      ),
      r != null && r.length >= 4 ? Quaternion(r[0], r[1], r[2], r[3]) : Quaternion.identity(),
      Vector3(
        s != null && s.isNotEmpty ? s[0] : 1.0,
        s != null && s.length > 1 ? s[1] : 1.0,
        s != null && s.length > 2 ? s[2] : 1.0,
      ),
    );
  }

  /// Binds (or rebinds) the skeletal mesh this physics asset authors bodies for.
  Future<bool> bindSkeletalMesh(String meshPath, {String? assetId}) async {
    await _loadSkeleton(meshPath, assetId ?? _skeletalMeshAssetId);
    if (!hasSkeletalMesh) {
      _lastError = _linkError;
      notifyListeners();
      return false;
    }
    _isDirty = true;
    _lastError = null;
    notifyListeners();
    return true;
  }

  // ------------------------------------------------------------- selection

  /// Bone highlighted in the tree (the target of Add / Replace Body).
  String? get selectedBoneName => _selectedBoneName;

  void selectBone(String? boneName) {
    _selectedBoneName = boneName;
    _selectedBodyBone = null;
    _selectedConstraintName = null;
    notifyListeners();
  }

  void selectBody(String? boneName) {
    _selectedBodyBone = boneName;
    _selectedBoneName = boneName;
    _selectedConstraintName = null;
    notifyListeners();
  }

  void selectConstraint(String? name) {
    _selectedConstraintName = name;
    _selectedBodyBone = null;
    notifyListeners();
  }

  /// Name of [boneName]'s parent bone, or null for a root bone.
  String? parentBoneOf(String boneName) {
    for (final candidate in _allBones) {
      if (candidate.children.any((c) => c.name == boneName)) return candidate.name;
    }
    return null;
  }

  /// The nearest ancestor bone that already carries a body.
  String? nearestParentBodyBone(String boneName) {
    var current = parentBoneOf(boneName);
    while (current != null) {
      if (_document.bodyForBone(current) != null) return current;
      current = parentBoneOf(current);
    }
    return null;
  }

  void setBoneFilter(String filter) {
    _boneFilter = filter.trim().toLowerCase();
    notifyListeners();
  }

  void setViewMode(PhysicsViewMode mode) {
    _viewMode = mode;
    notifyListeners();
  }

  /// True when a bone row (or one of its descendants / bodies) survives the filter.
  bool matchesFilter(GlbNode node) {
    if (_boneFilter.isEmpty) return true;
    if (node.name.toLowerCase().contains(_boneFilter)) return true;
    final body = _document.bodyForBone(node.name);
    if (body != null && body.name.toLowerCase().contains(_boneFilter)) return true;
    for (final c in node.children) {
      if (matchesFilter(c)) return true;
    }
    return false;
  }

  // ------------------------------------------------------------ authoring

  /// Adds an auto-sized body to [boneName]. Returns false (with [lastError])
  /// when the bone is unknown or already carries a body.
  bool addBody(String boneName, PhysicsShapeType shape) {
    if (!_bonesByName.containsKey(boneName)) {
      _lastError = 'Unknown bone "$boneName".';
      notifyListeners();
      return false;
    }
    if (_document.bodyForBone(boneName) != null) {
      _lastError = '$boneName already has a body — use Replace Body to change its shape.';
      notifyListeners();
      return false;
    }
    final body = _autoSizedBody(boneName, shape);
    _document.bodies.add(body);
    _selectedBodyBone = boneName;
    _selectedBoneName = boneName;
    _selectedConstraintName = null;
    _lastError = null;
    _markDirty();
    return true;
  }

  /// Changes the shape of an existing body, keeping its sizing and offsets.
  bool replaceBody(String boneName, PhysicsShapeType shape) {
    final body = _document.bodyForBone(boneName);
    if (body == null) return addBody(boneName, shape);
    body.shape = shape;
    if (shape == PhysicsShapeType.capsule && body.halfHeight < body.radius) {
      body.halfHeight = body.radius;
    }
    _selectedBodyBone = boneName;
    _selectedBoneName = boneName;
    _selectedConstraintName = null;
    _lastError = null;
    _markDirty();
    return true;
  }

  /// Removes [boneName]'s body plus every constraint and disabled pair that
  /// referenced it, so no dangling references survive a save.
  bool removeBody(String boneName) {
    final body = _document.bodyForBone(boneName);
    if (body == null) return false;
    _document.bodies.remove(body);
    _document.constraints.removeWhere((c) => c.touches(boneName));
    _document.disabledCollisionPairs.removeWhere((p) => p.contains(boneName));
    if (_selectedBodyBone == boneName) _selectedBodyBone = null;
    if (_selectedConstraintName != null && _document.constraintByName(_selectedConstraintName!) == null) {
      _selectedConstraintName = null;
    }
    _lastError = null;
    _markDirty();
    return true;
  }

  /// A body fitted to [boneName]'s segment, as an auto-generated body: its
  /// long axis (the body's local +Y, the engine capsule's axis)
  /// runs along the bone, it is centred half way along the segment, it spans
  /// the segment, and its radius reaches the skin around that axis.
  PhysicsBody _autoSizedBody(String boneName, PhysicsShapeType shape) {
    final seg = _assetSegment(boneName);
    final segment = seg.length * meshUnitScale;
    var radius = boneSkinRadius(boneName);
    if (radius <= 1e-6) radius = math.max(segment * 0.25, 1.0); // 1 cm floor
    var halfHeight = math.max(segment * 0.5, radius);
    if (shape == PhysicsShapeType.capsule && radius > halfHeight) radius = halfHeight;
    final centre = seg.direction * (segment * 0.5);
    return PhysicsBody(
      boneName: boneName,
      shape: shape,
      radius: radius,
      halfHeight: halfHeight,
      halfExtents: [radius, halfHeight, radius],
      offsetLocation: [centre.x, centre.y, centre.z],
      offsetRotationDeg: _eulerDegreesTurningYOnto(seg.direction),
      massKg: 1.0,
    );
  }

  /// The offset rotation, in [quaternionFromEulerDegrees]' convention, that
  /// turns the body's local +Y onto the unit vector [d]. That convention is
  /// `qY(y) x qX(x) x qZ(z)`; with y = 0, +Y goes to
  /// `(-sin z, cos z cos x, cos z sin x)`.
  static List<double> _eulerDegreesTurningYOnto(Vector3 d) {
    final z = math.asin((-d.x).clamp(-1.0, 1.0));
    final x = math.atan2(d.z, d.y);
    return [x * 180.0 / math.pi, 0.0, z * 180.0 / math.pi];
  }

  /// Length of the bone's segment in world units (cm): to its first child
  /// bone, or for a leaf its own offset from its parent.
  double boneSegmentLength(String boneName) => _assetSegment(boneName).length * meshUnitScale;

  /// The bone's segment in its own frame and the mesh's units (glTF metres):
  /// the direction and distance to its first child, or for a leaf the parent
  /// -> bone direction carried on past the joint.
  ({Vector3 direction, double length}) _assetSegment(String boneName) {
    final node = _bonesByName[boneName];
    final fallback = (direction: Vector3(0, 1, 0), length: 0.2);
    if (node == null) return fallback;
    Vector3? vec(List<double>? t) => t == null || t.length < 3 ? null : Vector3(t[0], t[1], t[2]);
    for (final child in node.children) {
      final t = vec(child.translation);
      if (t != null && t.length > 1e-6) return (direction: t.normalized(), length: t.length);
    }
    final t = vec(node.translation);
    if (t != null && t.length > 1e-6 && parentBoneOf(boneName) != null) {
      final r = node.rotation;
      final local = r != null && r.length >= 4 ? Quaternion(r[0], r[1], r[2], r[3]) : Quaternion.identity();
      return (direction: local.inverted().rotated(t.normalized()), length: t.length);
    }
    return fallback;
  }

  /// Radial extent of the skin vertices weighted >= 0.5 to [boneName], measured
  /// around the bone's segment axis, in world units (cm). Returns 0 when the
  /// mesh has no skin data.
  double boneSkinRadius(String boneName) {
    final mesh = _glbMesh;
    final node = _bonesByName[boneName];
    final global = _assetBoneGlobals[boneName];
    if (mesh == null || node == null || global == null) return 0.0;
    final joints = mesh.jointsPerVertex;
    final weights = mesh.weightsPerVertex;
    if (joints == null || weights == null) return 0.0;

    final jointOrder = mesh.skeletonJointIndices.toList();
    final origin = global.getTranslation();
    final axis = Quaternion.fromRotation(global.getRotation()).rotated(_assetSegment(boneName).direction).normalized();

    double maxRadial = 0.0;
    final vertexCount = mesh.vertexCount;
    for (int v = 0; v < vertexCount; v++) {
      final base = v * 4;
      if (base + 3 >= joints.length || base + 3 >= weights.length) break;
      double weight = 0.0;
      for (int i = 0; i < 4; i++) {
        final raw = joints[base + i];
        final nodeIndex = raw < jointOrder.length ? jointOrder[raw] : raw;
        if (nodeIndex == node.index) weight += weights[base + i];
      }
      if (weight < 0.5) continue;
      final pi = v * 3;
      if (pi + 2 >= mesh.positions.length) break;
      final p = Vector3(mesh.positions[pi], mesh.positions[pi + 1], mesh.positions[pi + 2]) - origin;
      final radial = (p - axis * p.dot(axis)).length;
      if (radial > maxRadial) maxRadial = radial;
    }
    return maxRadial * meshUnitScale;
  }

  // ------------------------------------------------------- body properties

  void _withBody(String boneName, void Function(PhysicsBody body) edit) {
    final body = _document.bodyForBone(boneName);
    if (body == null) return;
    edit(body);
    _markDirty();
  }

  void setBodyShape(String boneName, PhysicsShapeType shape) => replaceBody(boneName, shape);

  void setBodyRadius(String boneName, double value) =>
      _withBody(boneName, (b) => b.radius = math.max(_minLength, value));

  void setBodyHalfHeight(String boneName, double value) =>
      _withBody(boneName, (b) => b.halfHeight = math.max(_minLength, value));

  void setBodyExtent(String boneName, int axis, double value) =>
      _withBody(boneName, (b) => b.halfExtents[axis] = math.max(_minLength, value));

  void setBodyOffsetLocation(String boneName, int axis, double value) =>
      _withBody(boneName, (b) => b.offsetLocation[axis] = value);

  void setBodyOffsetRotation(String boneName, int axis, double value) =>
      _withBody(boneName, (b) => b.offsetRotationDeg[axis] = value);

  void setBodyMass(String boneName, double value) =>
      _withBody(boneName, (b) => b.massKg = math.max(0.0, value));

  void setBodyLinearDamping(String boneName, double value) =>
      _withBody(boneName, (b) => b.linearDamping = math.max(0.0, value));

  void setBodyAngularDamping(String boneName, double value) =>
      _withBody(boneName, (b) => b.angularDamping = math.max(0.0, value));

  void setBodyPhysicsMaterial(String boneName, String name) =>
      _withBody(boneName, (b) => b.physicsMaterial = name);

  // -------------------------------------------------------- constraints

  /// Adds a constraint between the bodies on [boneA] (parent) and [boneB].
  bool addConstraint(String boneA, String boneB) {
    if (boneA == boneB) {
      _lastError = 'A constraint needs two distinct bones.';
      notifyListeners();
      return false;
    }
    if (_document.bodyForBone(boneA) == null || _document.bodyForBone(boneB) == null) {
      _lastError = 'Both bones must already carry a body.';
      notifyListeners();
      return false;
    }
    final exists = _document.constraints.any((c) =>
        (c.bodyA == boneA && c.bodyB == boneB) || (c.bodyA == boneB && c.bodyB == boneA));
    if (exists) {
      _lastError = 'These bodies are already constrained.';
      notifyListeners();
      return false;
    }
    final constraint = PhysicsConstraint(bodyA: boneA, bodyB: boneB);
    _document.constraints.add(constraint);
    _selectedConstraintName = constraint.name;
    _selectedBodyBone = null;
    _lastError = null;
    _markDirty();
    return true;
  }

  bool removeConstraint(String name) {
    final before = _document.constraints.length;
    _document.constraints.removeWhere((c) => c.name == name);
    if (_document.constraints.length == before) return false;
    if (_selectedConstraintName == name) _selectedConstraintName = null;
    _markDirty();
    return true;
  }

  void _withConstraint(String name, void Function(PhysicsConstraint c) edit) {
    final c = _document.constraintByName(name);
    if (c == null) return;
    edit(c);
    _markDirty();
  }

  void setConstraintMode(String name, PhysicsAngularMode mode) =>
      _withConstraint(name, (c) => c.angularMode = mode);

  double _clampDegrees(double v) => v.clamp(-180.0, 180.0).toDouble();

  void setConstraintSwing1(String name, double deg) =>
      _withConstraint(name, (c) => c.swing1Deg = _clampDegrees(deg));

  void setConstraintSwing2(String name, double deg) =>
      _withConstraint(name, (c) => c.swing2Deg = _clampDegrees(deg));

  void setConstraintTwist(String name, double deg) =>
      _withConstraint(name, (c) => c.twistDeg = _clampDegrees(deg));

  bool constraintLimitsEnabled(PhysicsConstraint constraint) => constraint.limitsEnabled;

  // ------------------------------------------------- collision disables

  bool disableCollisionBetween(String boneA, String boneB) {
    if (boneA == boneB) return false;
    if (_document.bodyForBone(boneA) == null || _document.bodyForBone(boneB) == null) {
      _lastError = 'Both bones must already carry a body.';
      notifyListeners();
      return false;
    }
    if (_document.isPairDisabled(boneA, boneB)) return false;
    _document.disabledCollisionPairs.add([boneA, boneB]);
    _markDirty();
    return true;
  }

  bool enableCollisionBetween(String boneA, String boneB) {
    final before = _document.disabledCollisionPairs.length;
    _document.disabledCollisionPairs.removeWhere((p) =>
        (p[0] == boneA && p[1] == boneB) || (p[0] == boneB && p[1] == boneA));
    if (_document.disabledCollisionPairs.length == before) return false;
    _markDirty();
    return true;
  }

  bool isCollisionDisabled(String boneA, String boneB) => _document.isPairDisabled(boneA, boneB);

  // ------------------------------------------------------------ transforms

  /// `entityWorld x G_bone x offset` — the same chain sockets use, in cm
  /// (`G_bone` at [meshUnitScale]; the offset is already cm).
  Matrix4 bodyWorldTransform(PhysicsBody body) {
    final bone = _boneGlobals[body.boneName] ?? Matrix4.identity();
    return entityWorld.multiplied(bone).multiplied(body.offsetTransform);
  }

  // ----------------------------------------------------------- validation

  /// Runs lumina's real narrow phase over every authored body pair in bind
  /// pose. Disabled pairs are skipped (and labelled); clean pairs are omitted.
  List<PhysicsOverlapResult> validateOverlaps() {
    final bodies = _document.bodies;
    final results = <PhysicsOverlapResult>[];
    final contact = ContactResult();
    for (int i = 0; i < bodies.length; i++) {
      for (int j = i + 1; j < bodies.length; j++) {
        final a = bodies[i];
        final b = bodies[j];
        if (_document.isPairDisabled(a.boneName, b.boneName)) {
          results.add(PhysicsOverlapResult(
            bodyA: a.name,
            bodyB: b.name,
            boneA: a.boneName,
            boneB: b.boneName,
            penetrationDepth: 0.0,
            isColliding: false,
            disabled: true,
          ));
          continue;
        }
        contact.reset();
        final hit = testPair(
          a.toCollisionShape(),
          bodyWorldTransform(a),
          b.toCollisionShape(),
          bodyWorldTransform(b),
          contact,
        );
        if (!hit) continue;
        results.add(PhysicsOverlapResult(
          bodyA: a.name,
          bodyB: b.name,
          boneA: a.boneName,
          boneB: b.boneName,
          penetrationDepth: contact.penetrationDepth,
          isColliding: true,
          disabled: false,
        ));
      }
    }
    _lastValidation = results;
    _hasValidated = true;
    notifyListeners();
    return results;
  }

  /// Blocking document errors, surfaced inline and gating Save.
  List<String> get validationErrors {
    final errors = <String>[];
    final bodyBones = _document.bodies.map((b) => b.boneName).toSet();
    final seen = <String>{};
    for (final b in _document.bodies) {
      if (!seen.add(b.boneName)) {
        errors.add('Bone "${b.boneName}" carries more than one body.');
      }
    }
    for (final c in _document.constraints) {
      if (!bodyBones.contains(c.bodyA)) {
        errors.add('Constraint ${c.name} references missing body "${c.bodyA}".');
      }
      if (!bodyBones.contains(c.bodyB)) {
        errors.add('Constraint ${c.name} references missing body "${c.bodyB}".');
      }
      if (c.bodyA == c.bodyB) {
        errors.add('Constraint ${c.name} joins a body to itself.');
      }
    }
    for (final p in _document.disabledCollisionPairs) {
      for (final bone in p) {
        if (!bodyBones.contains(bone)) {
          errors.add('Disabled collision pair references missing body "$bone".');
        }
      }
    }
    return errors;
  }

  // -------------------------------------------------------------- overlays

  /// World-space line sets for the current view mode.
  List<PhysicsOverlayLineSet> buildOverlay() {
    final sets = <PhysicsOverlayLineSet>[];
    if (_viewMode != PhysicsViewMode.constraintsOnly) {
      for (final body in _document.bodies) {
        sets.add(PhysicsOverlayBuilder.buildBody(
          body,
          bodyWorldTransform(body),
          isSelected: _selectedBodyBone == body.boneName,
          dimmed: _document.disabledCollisionPairs.any((p) => p.contains(body.boneName)),
          filled: _viewMode == PhysicsViewMode.solidBodies,
        ));
      }
    }
    for (final c in _document.constraints) {
      final a = _document.bodyForBone(c.bodyA);
      final b = _document.bodyForBone(c.bodyB);
      if (a == null || b == null) continue;
      sets.add(PhysicsOverlayBuilder.buildConstraint(
        c,
        bodyWorldTransform(a),
        bodyWorldTransform(b),
        isSelected: _selectedConstraintName == c.name,
      ));
    }
    return sets;
  }

  /// Translucent solid bodies — only the `Solid Bodies` view mode draws them.
  List<PhysicsSolidMesh> buildSolidBodies() {
    if (_viewMode != PhysicsViewMode.solidBodies) return const [];
    return [
      for (final body in _document.bodies)
        PhysicsOverlayBuilder.buildSolidBody(
          body,
          bodyWorldTransform(body),
          isSelected: _selectedBodyBone == body.boneName,
          dimmed: _document.disabledCollisionPairs.any((p) => p.contains(body.boneName)),
        ),
    ];
  }

  // ------------------------------------------------------------------ save

  void _markDirty() {
    _isDirty = true;
    notifyListeners();
  }

  Future<bool> save() async {
    final errors = validationErrors;
    if (errors.isNotEmpty) {
      _lastError = errors.first;
      EngineLoggerService().log('Physics asset save blocked: ${errors.first}', level: 'error');
      notifyListeners();
      return false;
    }

    final metadata = Map<String, String>.from(_asset?.metadata ?? const {});
    metadata[metadataKey] = jsonEncode(_document.toJson());
    metadata['last_modified'] = DateTime.now().toIso8601String();
    metadata['body_count'] = _document.bodies.length.toString();
    metadata['constraint_count'] = _document.constraints.length.toString();

    final references = <AssetReference>[
      ...?_asset?.references.where((r) => r.slotName != skeletalMeshSlot),
    ];
    if (_skeletalMeshPath != null) {
      references.add(AssetReference(
        slotName: skeletalMeshSlot,
        assetId: _skeletalMeshAssetId ?? '',
        assetPath: _skeletalMeshPath!,
      ));
    }

    final updated = LuminaAsset(
      assetId: _asset?.assetId ?? fileBasename,
      name: _asset?.name ?? fileBasename,
      type: AssetType.physicsAsset,
      hasThumbnail: _asset?.hasThumbnail ?? false,
      thumbnailPng: _asset?.thumbnailPng,
      rawPayload: _asset?.rawPayload,
      rawMatSource: _asset?.rawMatSource ?? '',
      metadata: metadata,
      references: references,
    );

    try {
      final file = File(assetPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(updated.toProtoBufferBytes());
      _asset = updated;
      _isDirty = false;
      _lastError = null;
      EngineLoggerService().log('Saved PhysicsAsset to $assetPath', level: 'info');
      notifyListeners();
      return true;
    } catch (e, st) {
      _lastError = 'Save failed: $e';
      EngineLoggerService().log('Failed to save PhysicsAsset: $e\n$st', level: 'error');
      notifyListeners();
      return false;
    }
  }
}
