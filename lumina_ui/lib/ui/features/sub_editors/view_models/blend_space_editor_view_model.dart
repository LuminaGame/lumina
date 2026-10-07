import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumina/lumina.dart';

import 'package:lumina_ui/ui/features/main_editor/commands/editor_transaction.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/anim_graph_asset_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/anim_preview_scene.dart';

/// The Blend Space editor's state: lumina's
/// [LuminaBlendSpaceDocument] from the BLEND_SPACE `.lmas`,
/// axes, samples dropped from the target mesh's clips and snapped to the
/// grid divisions, and a preview point whose nearest sample the preview
/// mesh plays (lumina's nearest-sample-plus-crossfade, never a weighted
/// blend). Every edit is one undo step.
class BlendSpaceEditorViewModel extends ChangeNotifier {
  final String assetPath;
  late final String? projectDir = AnimGraphAssetService.projectDirOf(assetPath);

  List<LuminaBlendSpaceAxis> _axes = [];
  List<LuminaBlendSpaceSample> _samples = [];
  String _targetMesh = '';
  String _onDiskJson = '';
  List<String> _clips = const [];
  int _divisionsX = 4;
  int _divisionsY = 4;
  int? _selectedSample;
  double _pointX = 0.0;
  double _pointY = 0.0;
  final TransactionManager transactions = TransactionManager();
  String? _interactionBefore;
  String? _interactionLabel;

  final AnimPreviewScene preview = AnimPreviewScene();
  String? _lastClip;

  BlendSpaceEditorViewModel({required this.assetPath}) {
    preview.beforeTick = (_) => _playNearest();
    preview.afterTick = () {
      if (preview.currentClip != _lastClip) {
        _lastClip = preview.currentClip;
        notifyListeners();
      }
    };
  }

  String get name => AnimGraphAssetService.baseName(assetPath);
  String get relativePath {
    final dir = projectDir;
    final abs = File(assetPath).absolute.path;
    return dir != null && abs.startsWith('$dir/') ? abs.substring(dir.length + 1) : assetPath;
  }

  LuminaBlendSpaceDocument get document => LuminaBlendSpaceDocument(axes: List.of(_axes), samples: List.of(_samples));
  String get targetMesh => _targetMesh;
  List<String> get clips => _clips;
  int get divisionsX => _divisionsX;
  int get divisionsY => _divisionsY;
  int? get selectedSample => _selectedSample;
  (double, double) get previewPoint => (_pointX, _pointY);
  bool get is2D => _axes.length > 1;
  bool get isDirty => _json() != _onDiskJson;

  /// The sample the preview point picks.
  LuminaBlendSpaceSample? get nearestSample => document.nearest(_pointX, _pointY);

  /// The clip the preview mesh plays now.
  String? get previewClip => preview.currentClip;

  String _json() => const JsonEncoder.withIndent('  ').convert(document.toJson());

  Future<void> load() async {
    final dir = projectDir;
    final doc = dir == null ? null : AnimGraphAssetService.readBlendSpace(dir, relativePath);
    final d = doc ?? AnimGraphAssetService.newBlendSpace();
    _axes = List.of(d.axes);
    _samples = List.of(d.samples);
    _onDiskJson = doc == null ? '' : _json();
    if (dir != null) {
      _targetMesh = AnimGraphAssetService.blendSpaceTarget(dir, relativePath) ?? '';
      if (_targetMesh.isEmpty) {
        // A Blend Space saved without a target: the mesh whose clips it plays.
        for (final m in AnimGraphAssetService.skeletalMeshes(dir)) {
          final names = AnimGraphAssetService.clipNames(dir, m.relativePath).toSet();
          if (_samples.isNotEmpty && _samples.every((s) => names.contains(s.clip))) {
            _targetMesh = m.relativePath;
            break;
          }
        }
      }
      _clips = AnimGraphAssetService.clipNames(dir, _targetMesh);
      final source = AnimGraphAssetService.meshSource(dir, _targetMesh);
      preview.setMesh(source?.path, provider: source?.provider);
    }
    _pointX = _axes.isEmpty ? 0 : (_axes[0].min + _axes[0].max) / 2;
    _pointY = _axes.length > 1 ? _axes[1].min : 0;
    transactions.clear();
    notifyListeners();
  }

  Future<bool> save() async {
    final dir = projectDir;
    if (dir == null) return false;
    AnimGraphAssetService.writeBlendSpace(dir, relativePath, document, targetMesh: _targetMesh);
    _onDiskJson = _json();
    EngineLoggerService().log('Saved Blend Space $relativePath', level: 'info');
    notifyListeners();
    return true;
  }

  // --- undo -------------------------------------------------------------------

  String _snapshot() => jsonEncode(document.toJson());

  void _restore(String json) {
    final d = LuminaBlendSpaceDocument.fromJson(Map<String, dynamic>.from(jsonDecode(json) as Map));
    _axes = List.of(d.axes);
    _samples = List.of(d.samples);
    if (_selectedSample != null && _selectedSample! >= _samples.length) _selectedSample = null;
    notifyListeners();
  }

  bool _mutate(String label, bool Function() change) {
    final before = _snapshot();
    if (!change()) return false;
    final after = _snapshot();
    if (after == before) return false;
    transactions.record(EditorTransaction(label: label, undo: () => _restore(before), redo: () => _restore(after)));
    notifyListeners();
    return true;
  }

  void undo() => transactions.undo();
  void redo() => transactions.redo();

  // --- axes -------------------------------------------------------------------

  double _snap(double v, LuminaBlendSpaceAxis axis, int divisions) {
    final span = axis.max - axis.min;
    if (divisions <= 0 || span == 0) return v.clamp(axis.min, axis.max).toDouble();
    final step = span / divisions;
    return (axis.min + ((v - axis.min) / step).round() * step).clamp(axis.min, axis.max).toDouble();
  }

  bool setAxis(int index, {String? name, double? min, double? max}) {
    if (index < 0 || index >= _axes.length) return false;
    final a = _axes[index];
    final next = LuminaBlendSpaceAxis(name ?? a.name, min ?? a.min, max ?? a.max);
    if (next.max <= next.min) return false;
    return _mutate('Edit axis ${next.name}', () {
      _axes[index] = next;
      return true;
    });
  }

  void setDivisions({int? x, int? y}) {
    _divisionsX = (x ?? _divisionsX).clamp(1, 32);
    _divisionsY = (y ?? _divisionsY).clamp(1, 32);
    notifyListeners();
  }

  /// Makes the Blend Space one-dimensional (Direction only) or adds a second
  /// axis.
  bool setDimensions(int count) {
    if (count == _axes.length || count < 1 || count > 2) return false;
    return _mutate(count == 1 ? 'Make 1D' : 'Make 2D', () {
      if (count == 1) {
        _axes = [_axes.first];
        _samples = [for (final s in _samples) LuminaBlendSpaceSample(s.clip, s.x, 0.0)];
      } else {
        _axes = [..._axes, const LuminaBlendSpaceAxis('Speed', 0, 500)];
      }
      return true;
    });
  }

  // --- samples ----------------------------------------------------------------

  /// Drops [clip] at ([x], [y]), snapped to the grid divisions.
  int? addSample(String clip, double x, double y) {
    if (_axes.isEmpty) return null;
    final sx = _snap(x, _axes[0], _divisionsX);
    final sy = is2D ? _snap(y, _axes[1], _divisionsY) : 0.0;
    final ok = _mutate('Add sample $clip', () {
      _samples.add(LuminaBlendSpaceSample(clip, sx, sy));
      return true;
    });
    if (!ok) return null;
    _selectedSample = _samples.length - 1;
    notifyListeners();
    return _selectedSample;
  }

  void selectSample(int? index) {
    _selectedSample = index;
    notifyListeners();
  }

  void beginSampleDrag(int index) {
    _interactionBefore ??= _snapshot();
    _interactionLabel = 'Move sample';
    _selectedSample = index;
  }

  /// Moves sample [index] to ([x], [y]) snapped to the divisions (live, during
  /// a drag).
  void dragSample(int index, double x, double y) {
    if (index < 0 || index >= _samples.length || _axes.isEmpty) return;
    final s = _samples[index];
    _samples[index] = LuminaBlendSpaceSample(s.clip, _snap(x, _axes[0], _divisionsX), is2D ? _snap(y, _axes[1], _divisionsY) : 0.0);
    notifyListeners();
  }

  void endSampleDrag() {
    final before = _interactionBefore;
    _interactionBefore = null;
    if (before == null) return;
    final after = _snapshot();
    if (after == before) return;
    transactions.record(EditorTransaction(
        label: _interactionLabel ?? 'Move sample', undo: () => _restore(before), redo: () => _restore(after)));
    notifyListeners();
  }

  bool setSample(int index, {String? clip, double? x, double? y}) {
    if (index < 0 || index >= _samples.length) return false;
    final s = _samples[index];
    return _mutate('Edit sample', () {
      _samples[index] = LuminaBlendSpaceSample(clip ?? s.clip, x ?? s.x, y ?? s.y);
      return true;
    });
  }

  bool removeSample(int index) {
    if (index < 0 || index >= _samples.length) return false;
    final ok = _mutate('Delete sample ${_samples[index].clip}', () {
      _samples.removeAt(index);
      return true;
    });
    if (ok) _selectedSample = null;
    return ok;
  }

  // --- preview ----------------------------------------------------------------

  /// Moves the preview point (not snapped); the preview mesh blends to the
  /// nearest sample.
  void setPreviewPoint(double x, double y) {
    _pointX = x;
    _pointY = is2D ? y : 0.0;
    _playNearest();
    notifyListeners();
  }

  void _playNearest() {
    final clip = nearestSample?.clip;
    if (clip != null) preview.crossFadeTo(clip);
  }

  void attachPreviewWorld(LuminaWorld world) => preview.attach(world);

  void detachPreviewWorld(LuminaWorld world) {
    if (identical(preview.world, world)) preview.detach();
  }

  void startHeadlessPreview({bool ticker = true}) => preview.attachHeadless(startTicker: ticker);

  @override
  void dispose() {
    preview.detach();
    super.dispose();
  }
}
