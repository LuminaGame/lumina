import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/features/main_editor/commands/editor_transaction.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/anim_graph_asset_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/pose_search_database_service.dart';

/// The Pose Search Database editor's state: the document (clips of the
/// target mesh with their flags, the schema, the search settings), the
/// mesh's clips to pick from, and the feature cache's build state. Every
/// edit is one undo step; loading, saving and building run off the UI
/// isolate.
class PoseSearchDatabaseEditorViewModel extends ChangeNotifier {
  final String assetPath;
  late final String? projectDir = AnimGraphAssetService.projectDirOf(assetPath);

  PoseSearchDatabaseEditorViewModel({required this.assetPath});

  LuminaPoseSearchDatabaseDocument _doc = const LuminaPoseSearchDatabaseDocument();
  String _onDiskJson = '';
  List<String> _meshClips = const [];
  final TransactionManager transactions = TransactionManager();
  bool _loading = false;
  bool _building = false;
  bool _disposed = false;
  int? _selected;
  String _filter = '';
  final Set<String> _collapsed = {};
  PoseSearchCacheState _cacheState = PoseSearchCacheState.missing;
  PoseSearchBuildReport? _report;
  String? _error;

  String get name => AnimGraphAssetService.baseName(assetPath);
  String get relativePath {
    final dir = projectDir;
    final abs = File(assetPath).absolute.path.replaceAll(r'\', '/');
    final root = dir?.replaceAll(r'\', '/');
    return root != null && abs.startsWith('$root/') ? abs.substring(root.length + 1) : assetPath.replaceAll(r'\', '/');
  }

  LuminaPoseSearchDatabaseDocument get document => _doc;
  List<String> get meshClips => _meshClips;
  bool get isLoading => _loading;
  bool get isBuilding => _building;
  bool get isDirty => _json() != _onDiskJson;
  int? get selectedClip => _selected;
  String get filter => _filter;
  PoseSearchCacheState get cacheState => _cacheState;
  PoseSearchBuildReport? get report => _report;
  String? get error => _error;

  /// Whether the database lists [clip].
  bool contains(String clip) => _doc.clips.any((c) => c.clip == clip);

  /// The mesh's clips matching the filter, grouped by their movement word
  /// (`Walk`, `Run`, `Stand`, …: the name without the `M_Neutral_` style
  /// prefix, up to the next `_`).
  Map<String, List<String>> get clipGroups {
    final f = _filter.toLowerCase();
    final out = <String, List<String>>{};
    for (final c in _meshClips) {
      if (f.isNotEmpty && !c.toLowerCase().contains(f)) continue;
      out.putIfAbsent(groupOf(c), () => []).add(c);
    }
    return Map.fromEntries(out.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  static String groupOf(String clip) {
    final parts = clip.split('_').where((p) => p.isNotEmpty).toList();
    var i = 0;
    if (parts.length > 2 && parts[0].length <= 2) i = 2; // M_Neutral_, F_Relaxed_
    return i < parts.length ? parts[i] : 'Other';
  }

  bool isCollapsed(String group) => _collapsed.contains(group);
  void toggleGroup(String group) {
    if (!_collapsed.remove(group)) _collapsed.add(group);
    notifyListeners();
  }

  void setFilter(String text) {
    _filter = text;
    notifyListeners();
  }

  String _json() => const JsonEncoder.withIndent('  ').convert(_doc.toJson());

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    final dir = projectDir;
    if (dir == null) return;
    _loading = true;
    _notify();
    try {
      final doc = await PoseSearchDatabaseService.read(dir, relativePath);
      if (_disposed) return;
      _doc = doc ?? const LuminaPoseSearchDatabaseDocument();
      _onDiskJson = doc == null ? '' : _json();
      _meshClips = await PoseSearchDatabaseService.clipNames(dir, _doc.targetMesh);
      if (_disposed) return;
      _cacheState = await PoseSearchDatabaseService.cacheState(dir, relativePath, _doc);
      _error = null;
    } catch (e) {
      _error = 'Cannot load $relativePath: $e';
    }
    _loading = false;
    transactions.clear();
    _notify();
  }

  Future<bool> save() async {
    final dir = projectDir;
    if (dir == null) return false;
    await PoseSearchDatabaseService.write(dir, relativePath, _doc);
    _onDiskJson = _json();
    if (_cacheState == PoseSearchCacheState.upToDate) _cacheState = PoseSearchCacheState.stale;
    EngineLoggerService().log('Saved Pose Search Database $relativePath', level: 'info');
    _notify();
    return true;
  }

  /// Saves, then builds the feature cache on a background isolate.
  Future<PoseSearchBuildReport?> build() async {
    final dir = projectDir;
    if (dir == null || _building) return null;
    _building = true;
    _error = null;
    _notify();
    try {
      await save();
      _report = await PoseSearchDatabaseService.build(dir, relativePath, _doc);
      _cacheState = PoseSearchCacheState.upToDate;
      EngineLoggerService().log(
          'Built Pose Search Database $relativePath: ${_report!.stats.rows} frames, '
          '${(_report!.stats.buildMicroseconds / 1000).toStringAsFixed(0)} ms',
          level: 'info');
    } catch (e) {
      _error = 'Build failed: $e';
    }
    _building = false;
    _notify();
    return _report;
  }

  // --- undo -------------------------------------------------------------------

  void _restore(String json) {
    _doc = LuminaPoseSearchDatabaseDocument.fromJson(Map<String, dynamic>.from(jsonDecode(json) as Map));
    if (_selected != null && _selected! >= _doc.clips.length) _selected = null;
    _cacheState = _cacheState == PoseSearchCacheState.missing ? _cacheState : PoseSearchCacheState.stale;
    _notify();
  }

  bool _mutate(String label, LuminaPoseSearchDatabaseDocument Function(LuminaPoseSearchDatabaseDocument d) change) {
    final before = jsonEncode(_doc.toJson());
    final next = change(_doc);
    final after = jsonEncode(next.toJson());
    if (after == before) return false;
    _doc = next;
    if (_cacheState == PoseSearchCacheState.upToDate) _cacheState = PoseSearchCacheState.stale;
    transactions.record(EditorTransaction(label: label, undo: () => _restore(before), redo: () => _restore(after)));
    _notify();
    return true;
  }

  void undo() => transactions.undo();
  void redo() => transactions.redo();

  // --- clips ------------------------------------------------------------------

  void selectClip(int? index) {
    _selected = index;
    _notify();
  }

  /// Adds [clips] the database does not list yet (loops guessed by name).
  bool addClips(Iterable<String> clips) {
    final fresh = [for (final c in clips) if (!contains(c) && _meshClips.contains(c)) c];
    if (fresh.isEmpty) return false;
    return _mutate(fresh.length == 1 ? 'Add ${fresh.first}' : 'Add ${fresh.length} clips', (d) => d.copyWith(clips: [
          ...d.clips,
          for (final c in fresh) LuminaPoseSearchClip(c, loop: LuminaPoseSearchClip.looksLooping(c), mirror: true),
        ]));
  }

  /// Adds every mesh clip whose name contains [text] (case-insensitive).
  bool addMatching(String text) {
    final f = text.trim().toLowerCase();
    if (f.isEmpty) return false;
    return addClips(_meshClips.where((c) => c.toLowerCase().contains(f)));
  }

  bool removeClip(int index) {
    if (index < 0 || index >= _doc.clips.length) return false;
    final name = _doc.clips[index].clip;
    final ok = _mutate('Remove $name', (d) => d.copyWith(clips: [...d.clips]..removeAt(index)));
    if (ok) _selected = null;
    _notify();
    return ok;
  }

  bool toggleClip(String clip) {
    final i = _doc.clips.indexWhere((c) => c.clip == clip);
    return i >= 0 ? removeClip(i) : addClips([clip]);
  }

  bool updateClip(int index, LuminaPoseSearchClip Function(LuminaPoseSearchClip c) change) {
    if (index < 0 || index >= _doc.clips.length) return false;
    return _mutate('Edit ${_doc.clips[index].clip}', (d) {
      final clips = [...d.clips];
      clips[index] = change(clips[index]);
      return d.copyWith(clips: clips);
    });
  }

  /// Sets [index]'s tags from comma separated text.
  bool setTags(int index, String text) => updateClip(index,
      (c) => c.copyWith(tags: {for (final t in text.split(',')) if (t.trim().isNotEmpty) t.trim()}.toList()));

  // --- settings and schema ----------------------------------------------------

  bool setSettings(
          {double? searchInterval, double? continuingPoseBias, double? blendTime, double? excludeEndSeconds, double? loopingCostBias}) =>
      _mutate(
          'Edit search settings',
          (d) => d.copyWith(
                searchInterval: searchInterval == null || searchInterval <= 0 ? null : searchInterval,
                continuingPoseBias: continuingPoseBias,
                blendTime: blendTime == null || blendTime <= 0 ? null : blendTime,
                excludeEndSeconds: excludeEndSeconds == null || excludeEndSeconds < 0 ? null : excludeEndSeconds,
                loopingCostBias: loopingCostBias,
              ));

  bool setSchema(LuminaPoseSearchSchema Function(LuminaPoseSearchSchema s) change) =>
      _mutate('Edit schema', (d) => d.copyWith(schema: change(d.schema)));

  /// Trajectory sample times from comma separated seconds (e.g. "-0.33,
  /// 0.33, 0.67, 1"); false when nothing parses.
  bool setTrajectoryTimes(String text) {
    final times = [for (final t in text.split(',')) double.tryParse(t.trim())].whereType<double>().toList()..sort();
    if (times.isEmpty) return false;
    return setSchema((s) => s.copyWith(trajectoryTimes: times));
  }

  bool addBone(String bone) {
    final name = bone.trim();
    if (name.isEmpty || _doc.schema.bones.any((b) => b.name == name)) return false;
    return setSchema((s) => s.copyWith(bones: [...s.bones, LuminaPoseSearchBone(name)]));
  }

  bool removeBone(String bone) => setSchema((s) => s.copyWith(bones: [for (final b in s.bones) if (b.name != bone) b]));

  bool setBoneWeights(String bone, {double? position, double? velocity}) => setSchema((s) => s.copyWith(bones: [
        for (final b in s.bones)
          b.name == bone
              ? LuminaPoseSearchBone(b.name,
                  position: (position ?? b.position).clamp(0.0, 100.0).toDouble(),
                  velocity: (velocity ?? b.velocity).clamp(0.0, 100.0).toDouble())
              : b,
      ]));
}
