import 'dart:io';
import 'dart:math' as math;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:lumina_editor_data/lumina_editor.dart';

/// Where a click in the Garment editor's viewport goes.
enum GarmentPickMode {
  /// Clicks do nothing (the gizmo moves the garment).
  none,

  /// A click on the garment sets the selected landmark's garment point.
  garment,

  /// A click on the body sets the selected landmark's body point.
  body,
}

/// A mesh read for picking: the geometry in cm (the body's mesh space; a
/// garment's own source space).
class GarmentEditorMesh {
  GarmentEditorMesh(this.path, this.data);

  /// The project-relative mesh asset.
  final String path;
  final LuminaSkinnedMeshData data;
}

/// View model of the Garment editor: one garment `.lmas` (a
/// `LuminaGarmentDocument`) with its source mesh placed on the reference
/// body by a gizmo, its landmarks placed by clicks on either mesh, aligned
/// by the landmarks, saved in place. Meshes and the project's asset lists
/// are read on worker isolates.
class GarmentEditorViewModel extends ChangeNotifier {
  GarmentEditorViewModel({required this.assetPath});

  /// The `.lmas` file edited.
  final String assetPath;

  LuminaGarmentDocument _doc = const LuminaGarmentDocument();
  LuminaGarmentDocument _saved = const LuminaGarmentDocument();
  LuminaAsset? _asset;
  bool _loaded = false;
  bool _disposed = false;
  String? _error;
  String? _selectedLandmark;
  GarmentPickMode _pickMode = GarmentPickMode.none;
  String _previewBody = '';
  GarmentEditorMesh? _source, _body;
  final Map<String, Future<GarmentEditorMesh?>> _meshLoads = {};
  List<RealAssetInfo> _meshes = const [], _skeletalMeshes = const [], _clothSettings = const [];
  int _revision = 0;

  LuminaGarmentDocument get doc => _doc;
  bool get isLoaded => _loaded;
  bool get isDirty => _doc != _saved;
  String? get error => _error;
  String? get selectedLandmark => _selectedLandmark;
  GarmentPickMode get pickMode => _pickMode;

  /// The body the viewport shows: the preview body when one is chosen,
  /// else the reference body.
  String get previewBody => _previewBody.isNotEmpty ? _previewBody : _doc.referenceBody;
  String get previewBodyChoice => _previewBody;

  /// The source mesh and reference body as read for picking (null while
  /// loading or unset).
  GarmentEditorMesh? get sourceMesh => _source;
  GarmentEditorMesh? get bodyMesh => _body;

  /// Increases when the meshes or the placement change (the viewport
  /// rebuilds its preview).
  int get revision => _revision;

  /// The project's static and skeletal meshes (garment sources), skeletal
  /// meshes (bodies) and cloth settings, for the pickers.
  List<RealAssetInfo> get meshAssets => _meshes;
  List<RealAssetInfo> get skeletalMeshAssets => _skeletalMeshes;
  List<RealAssetInfo> get clothSettingsAssets => _clothSettings;

  /// The project folder the asset lives in (above its `contents/`).
  String get projectDir {
    final normal = assetPath.replaceAll(r'\', '/');
    final i = normal.lastIndexOf('/contents/');
    return i < 0 ? File(assetPath).parent.path : normal.substring(0, i);
  }

  /// The absolute path of a project-relative asset.
  String absolute(String relative) => relative.isEmpty || File(relative).isAbsolute ? relative : '$projectDir/$relative';

  Future<void> load() async {
    try {
      final bytes = await File(assetPath).readAsBytes();
      _asset = LuminaAsset.fromBytes(bytes);
      _doc = _saved = LuminaGarmentDocument.fromAsset(_asset!);
      _error = null;
    } catch (e) {
      _error = 'Cannot read $assetPath: $e';
    }
    _loaded = true;
    _notify();
    await Future.wait([_scanAssets(), _reloadMeshes()]);
  }

  Future<void> _scanAssets() async {
    final dir = projectDir;
    final all = await _scan(dir);
    if (_disposed) return;
    _meshes = [for (final a in all) if (a.type == AssetType.filamesh || a.type == AssetType.filameshSk) a];
    _skeletalMeshes = [for (final a in all) if (a.type == AssetType.filameshSk) a];
    _clothSettings = [for (final a in all) if (a.type == AssetType.clothSettings) a];
    _notify();
  }

  Future<void> _reloadMeshes() async {
    final source = _doc.sourceMesh, body = previewBody;
    final results = await Future.wait([_mesh(source), _mesh(body)]);
    if (_disposed) return;
    // Another choice may have come in meanwhile.
    if (_doc.sourceMesh == source) _source = results[0];
    if (previewBody == body) _body = results[1];
    _revision++;
    _notify();
  }

  /// [relative]'s geometry, read and parsed on a worker isolate (cached).
  Future<GarmentEditorMesh?> _mesh(String relative) {
    if (relative.isEmpty) return Future.value();
    return _meshLoads.putIfAbsent(relative, () async {
      final path = absolute(relative);
      try {
        final data = await readGarmentEditorMesh(path);
        return GarmentEditorMesh(relative, data);
      } catch (e) {
        _error = 'Cannot read $relative: $e';
        _meshLoads.remove(relative);
        return null;
      }
    });
  }

  /// Waits for the meshes being read (tests and the smoke run).
  Future<void> get meshesReady async {
    for (final f in [..._meshLoads.values]) {
      await f;
    }
  }

  void _set(LuminaGarmentDocument next) {
    if (next == _doc) return;
    _doc = next;
    _revision++;
    _notify();
  }

  Future<void> setSourceMesh(String relative) async {
    _set(_doc.copyWith(sourceMesh: relative));
    await _reloadMeshes();
  }

  Future<void> setReferenceBody(String relative) async {
    _set(_doc.copyWith(referenceBody: relative));
    await _reloadMeshes();
  }

  /// Shows the garment on another body ('' : the reference body); not saved.
  Future<void> setPreviewBody(String relative) async {
    _previewBody = relative;
    _revision++;
    _notify();
    await _reloadMeshes();
  }

  void setSlot(String slot) => _set(_doc.copyWith(slot: slot));
  void setThickness(double cm) => _set(_doc.copyWith(thickness: cm));
  void setSimulateAsCloth(bool on) => _set(_doc.copyWith(simulateAsCloth: on));
  void setClothSettings(String relative) => _set(_doc.copyWith(clothSettingsAsset: relative));

  void setPlacement({List<double>? location, List<double>? rotation, List<double>? scale}) =>
      _set(_doc.copyWith(location: location, rotation: rotation, scale: scale));

  // --- Landmarks -------------------------------------------------------------------------

  /// The presets not placed yet.
  List<String> get missingPresets => [
    for (final p in LuminaGarmentDocument.presets)
      if (_doc.landmark(p) == null) p,
  ];

  /// Adds the landmark [name] (a preset or a custom name) and selects it;
  /// false when the name is empty or taken.
  bool addLandmark(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _doc.landmark(trimmed) != null) return false;
    _selectedLandmark = trimmed;
    _set(_doc.withLandmark(LuminaGarmentLandmark(trimmed)));
    return true;
  }

  void removeLandmark(String name) {
    if (_selectedLandmark == name) _selectedLandmark = null;
    _set(_doc.withoutLandmark(name));
  }

  void selectLandmark(String? name) {
    _selectedLandmark = name;
    _notify();
  }

  void setPickMode(GarmentPickMode mode) {
    _pickMode = mode;
    _notify();
  }

  /// A click's ray (body / runtime frame, cm): in garment mode it sets the
  /// selected landmark's garment point where the ray meets the placed
  /// garment (stored in the source mesh's space), in body mode its body
  /// point on the body. False when nothing was hit or nothing is selected.
  bool pick(double ox, double oy, double oz, double dx, double dy, double dz) {
    final name = _selectedLandmark;
    final landmark = name == null ? null : _doc.landmark(name);
    if (landmark == null || _pickMode == GarmentPickMode.none) return false;
    if (_pickMode == GarmentPickMode.body) {
      final body = _body;
      if (body == null) return false;
      final hit = LuminaGarmentMath.raycast(body.data.positions, body.data.triangles, ox, oy, oz, dx, dy, dz);
      if (hit == null) return false;
      _set(_doc.withLandmark(landmark.withBody([hit.x, hit.y, hit.z])));
      return true;
    }
    final source = _source;
    if (source == null) return false;
    final placed = placedSourcePositions();
    final hit = LuminaGarmentMath.raycast(placed, source.data.triangles, ox, oy, oz, dx, dy, dz);
    if (hit == null) return false;
    _set(_doc.withLandmark(landmark.withGarment(unplace([hit.x, hit.y, hit.z]))));
    return true;
  }

  /// The source mesh's vertices placed on the body (cm).
  Float64List placedSourcePositions() {
    final source = _source;
    if (source == null) return Float64List(0);
    final m = _doc.placementMatrix();
    final p = source.data.positions;
    final out = Float64List(p.length);
    for (var i = 0; i + 2 < p.length; i += 3) {
      final x = p[i], y = p[i + 1], z = p[i + 2];
      out[i] = m[0] * x + m[4] * y + m[8] * z + m[12];
      out[i + 1] = m[1] * x + m[5] * y + m[9] * z + m[13];
      out[i + 2] = m[2] * x + m[6] * y + m[10] * z + m[14];
    }
    return out;
  }

  /// A placed point back in the source mesh's space.
  List<double> unplace(List<double> placed) {
    final s = _doc.scale;
    final p = [placed[0] - _doc.location[0], placed[1] - _doc.location[1], placed[2] - _doc.location[2]];
    final q = LuminaGarmentMath.quaternionFromEuler(_doc.rotation);
    final r = LuminaGarmentMath.rotate([-q[0], -q[1], -q[2], q[3]], p);
    return [r[0] / s[0], r[1] / s[1], r[2] / s[2]];
  }

  /// The landmarks with both points, and how far apart each pair is now
  /// (cm, the garment point placed).
  Map<String, double> landmarkErrors() => {
    for (final l in _doc.landmarks)
      if (l.isComplete) l.name: _distance(_doc.place(l.garment!), l.body!),
  };

  /// Places the garment so its landmarks land on the body's: the best
  /// similarity (uniform scale, rotation, translation) over every complete
  /// pair, the rotation kept with fewer than three. False with none.
  bool align() {
    final pairs = [for (final l in _doc.landmarks) if (l.isComplete) l];
    if (pairs.isEmpty) return false;
    final fit = LuminaGarmentMath.fitSimilarity(
      [for (final l in pairs) l.garment!],
      [for (final l in pairs) l.body!],
    );
    final keepRotation = pairs.length < 3;
    final rotation = keepRotation ? LuminaGarmentMath.quaternionFromEuler(_doc.rotation) : fit.rotation;
    // With the rotation kept, translation and scale are refitted around it.
    final LuminaSimilarity applied;
    if (keepRotation) {
      final rotated = [for (final l in pairs) LuminaGarmentMath.rotate(rotation, l.garment!)];
      final f = LuminaGarmentMath.fitSimilarity(rotated, [for (final l in pairs) l.body!]);
      applied = LuminaSimilarity(f.scale, rotation, f.translation);
    } else {
      applied = fit;
    }
    _set(_doc.copyWith(
      location: applied.translation,
      rotation: keepRotation ? _doc.rotation : LuminaGarmentMath.eulerFromQuaternion(applied.rotation),
      scale: [applied.scale, applied.scale, applied.scale],
    ));
    return true;
  }

  static double _distance(List<double> a, List<double> b) {
    final dx = a[0] - b[0], dy = a[1] - b[1], dz = a[2] - b[2];
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  // --- Save -------------------------------------------------------------------------------

  void revert() => _set(_saved);

  Future<bool> save() async {
    try {
      final asset = _doc.toAsset(name: _asset?.name ?? File(assetPath).uri.pathSegments.last.replaceAll('.lmas', ''), assetId: _asset?.assetId);
      final kept = LuminaAsset(
        assetId: asset.assetId,
        name: asset.name,
        type: asset.type,
        hasThumbnail: _asset?.hasThumbnail ?? false,
        thumbnailPng: _asset?.thumbnailPng,
        rawPayload: asset.rawPayload,
        references: asset.references,
        metadata: {...?_asset?.metadata, 'last_modified': DateTime.now().toIso8601String()},
      );
      await File(assetPath).writeAsBytes(kept.toProtoBufferBytes(), flush: true);
      _asset = kept;
      _saved = _doc;
      _error = null;
      _notify();
      return true;
    } catch (e) {
      _error = 'Cannot save: $e';
      _notify();
      return false;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The project's assets, scanned on a worker isolate.
Future<List<RealAssetInfo>> _scan(String dir) =>
    Isolate.run(() => AssetRepository().scanProjectContents(dir), debugName: 'garment assets');

/// The geometry of the mesh asset at [path] (a `.glb`, or a mesh `.lmas`
/// through its `.entity.glb`), read and parsed on a worker isolate.
Future<LuminaSkinnedMeshData> readGarmentEditorMesh(String path) => Isolate.run(() async {
  final bytes = await LuminaMeshAssetCache.meshBytes((p) => File(p).readAsBytes(), path);
  try {
    return LuminaSkinnedMeshData.fromGlb(bytes, draco: LuminaGlbLoader.decoders.draco);
  } on UnsupportedError {
    return LuminaSkinnedMeshData.fromGlb(bytes);
  }
}, debugName: 'garment mesh');
