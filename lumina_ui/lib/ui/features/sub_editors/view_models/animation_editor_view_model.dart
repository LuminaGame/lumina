import 'dart:convert';
import 'dart:io';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:lumina/lumina.dart';
import '../models/animation_playback_controller.dart';
import '../models/anim_notify_and_curves.dart';
import '../models/anim_bone_track_info.dart';
import '../models/selected_keyframe_details.dart';
import '../services/anim_graph_asset_service.dart';

part 'animation_editor_view_model/state.dart';
part 'animation_editor_view_model/preview_and_retarget.dart';
part 'animation_editor_view_model/playback.dart';
part 'animation_editor_view_model/notifies_curves_blend_space.dart';
part 'animation_editor_view_model/dope_sheet.dart';

class AnimationEditorViewModel extends _AnimationEditorViewModelState
    with
        _AnimationEditorPreviewAndRetarget,
        _AnimationEditorPlayback,
        _AnimationEditorNotifiesCurvesBlendSpace,
        _AnimationEditorDopeSheet {
  AnimationEditorViewModel({required super.assetPath, super.initialAsset, super.vsync});

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  bool get isDirty => _isDirty;
  @override
  LuminaAsset? get asset => _asset;
  GlbMeshData? get glbMesh => _glbMesh;

  RealAssetInfo? get previewMeshAsset => _previewMeshAsset;
  String? get previewMeshPath => _previewMeshPath;
  String? get previewMeshSourcePath {
    if (_previewMeshAsset?.lmasPath != null) return _previewMeshAsset!.lmasPath;
    if (_previewMeshAsset != null) {
      final pDir = _findProjectDir(assetPath);
      if (pDir != null) return '$pDir/${_previewMeshAsset!.relativePath}';
    }
    return assetPath;
  }
  List<RealAssetInfo> get availableSkeletalMeshes => List.unmodifiable(_availableSkeletalMeshes);

  double get timelineZoom => _timelineZoom;
  bool get snapToFrames => _snapToFrames;
  int get snapInterval => _snapInterval;
  Set<String> get selectedKeyframeIds => Set.unmodifiable(_selectedKeyframeIds);

  @override
  List<GlbAnimationClip> get clips => _clips;
  int get selectedClip => _selectedClip;
  bool get isPlaying => _isPlaying;
  bool get isLooping => _isLooping;
  double get speed => _speed;
  double get rateScale => _rateScale;
  double get positionSeconds => _positionSeconds;
  double get frameRate => _frameRate;
  @override
  String get interpolation => _interpolation;
  String get additiveType => _additiveType;

  List<EditorAnimNotify> get notifies => _notifies;
  List<AnimCurveData> get curves => _curves;
  BlendSpaceData get blendSpace => _blendSpace;
  double get blendParamX => _blendParamX;
  double get blendParamY => _blendParamY;
  bool get enableRootMotion => _enableRootMotion;
  List<EditorAnimNotify> get recentlyFiredNotifies => List.unmodifiable(_recentlyFiredNotifies);

  String get fileBasename {
    final file = File(assetPath);
    return file.path.split(Platform.pathSeparator).last.replaceAll('.lmas', '');
  }

  @override
  GlbAnimationClip? get activeClip =>
      _clips.isNotEmpty && _selectedClip < _clips.length ? _clips[_selectedClip] : null;

  @override
  double get duration => activeClip?.duration ?? 0.0;

  int get totalFrames => (duration * _frameRate).ceil();

  List<double> get activeClipKeyframes => activeClip?.compositeKeyframeTimes ?? const [];

  List<AnimBoneTrackInfo> get allBoneTrackInfos {
    final clip = activeClip;
    if (clip == null) return const [];
    final Map<String, List<GlbAnimationChannel>> grouped = {};
    for (final ch in clip.channels) {
      grouped.putIfAbsent(ch.nodeName, () => []).add(ch);
    }
    final List<AnimBoneTrackInfo> list = [];
    for (final entry in grouped.entries) {
      final nodeIdx = entry.value.first.nodeIndex;
      list.add(AnimBoneTrackInfo.compute(entry.key, nodeIdx, entry.value, clip.duration));
    }
    return list;
  }
  String get boneSearchQuery => _boneSearchQuery;
  void setBoneSearchQuery(String query) {
    if (_boneSearchQuery == query) return;
    _boneSearchQuery = query;
    notifyListeners();
  }

  /// Returns only bones that actively vary (position/rotation/scale) over time.
  List<AnimBoneTrackInfo> get animatedBoneTracks {
    return allBoneTrackInfos.where((b) => b.hasVariation).toList();
  }

  /// Returns animated bones matching the search filter query.
  List<AnimBoneTrackInfo> get filteredAnimatedBoneTracks {
    if (_boneSearchQuery.isEmpty) return animatedBoneTracks;
    final q = _boneSearchQuery.toLowerCase();
    return animatedBoneTracks.where((b) => b.boneName.toLowerCase().contains(q)).toList();
  }

  Map<String, List<double>> get boneKeyframeTracks {
    final clip = activeClip;
    if (clip == null) return const {};
    final Map<String, Set<double>> map = {};
    for (final ch in clip.channels) {
      final set = map.putIfAbsent(ch.nodeName, () => <double>{});
      set.addAll(ch.keyframeTimes);
    }
    return map.map((key, val) => MapEntry(key, val.toList()..sort()));
  }

  @override
  int get currentFrame {
    if (totalFrames == 0) return 0;
    return (_positionSeconds * _frameRate).floor().clamp(0, totalFrames);
  }

  String get formattedTime => formatTimecode(_positionSeconds);
  String get formattedTotalTime => formatTimecode(duration);

  Set<int> get activeAnimatedNodeIndices => activeClip?.animatedNodeIndices ?? const {};

  List<GlbNode> get allBones {
    if (_glbMesh == null) return [];
    final explicit = _glbMesh!.allNodes.where((n) => n.type == GlbNodeType.bone).toList();
    if (explicit.isNotEmpty) return explicit;
    return _glbMesh!.allNodes.where((n) => n.type != GlbNodeType.mesh).toList();
  }

  List<GlbNode> get rootBones {
    if (_glbMesh == null) return [];
    final explicit = _glbMesh!.rootNodes.where((n) => n.type == GlbNodeType.bone || n.children.isNotEmpty).toList();
    if (explicit.isNotEmpty) return explicit;
    return _glbMesh!.rootNodes.where((n) => n.type != GlbNodeType.mesh).toList();
  }

  Map<String, double> get currentBlendWeights => _blendSpace.computeWeights(_blendParamX, _blendParamY);

  @override
  EditorBlendSample? get dominantSample {
    final weights = currentBlendWeights;
    if (weights.isEmpty) return null;
    String bestId = weights.keys.first;
    double bestWeight = weights.values.first;
    for (final entry in weights.entries) {
      if (entry.value > bestWeight) {
        bestWeight = entry.value;
        bestId = entry.key;
      }
    }
    return _blendSpace.samples.where((s) => s.id == bestId).firstOrNull;
  }

  Future<void> load() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      if (initialAsset != null) {
        _asset = initialAsset;
      } else {
        final file = File(assetPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          try {
            _asset = LuminaAsset.fromBytes(bytes);
          } catch (_) {}
        }
      }

      if (_asset?.rawPayload != null && _asset!.rawPayload!.isNotEmpty) {
        _glbMesh = await GlbParserService.parseGlb(_asset!.rawPayload!);
      } else {
        // A clip asset that references the skeletal mesh holding its clip (the
        // Third Person template's character) instead of embedding another copy
        // of it: the clips come from that mesh.
        final sourceMesh = _asset?.metadata['source_mesh'];
        final projectDir = _findProjectDir(assetPath);
        if (sourceMesh != null && sourceMesh.isNotEmpty && projectDir != null) {
          _glbMesh = await AssetRepository.loadMeshFromDisk('$projectDir/$sourceMesh');
        }
      }

      if (_glbMesh != null) {
        _clips = List<GlbAnimationClip>.from(_glbMesh!.animations);
        if (_clips.isEmpty) {
          _clips = [
            const GlbAnimationClip(name: 'Default', duration: 1.0),
          ];
        }
      } else {
        _clips = [
          const GlbAnimationClip(name: 'Default', duration: 1.0),
        ];
      }

      // Discover available skeletal meshes in the project
      final projectDir = _findProjectDir(assetPath);
      if (projectDir != null) {
        try {
          final allAssets = AssetRepository().scanProjectContents(projectDir);
          _availableSkeletalMeshes = allAssets.where((a) {
            final lower = a.relativePath.toLowerCase();
            final nameLower = a.fileName.toLowerCase();
            // Strictly reject materials, textures, animations, static meshes
            if (a.type == AssetType.filamat || a.type == AssetType.texture || a.type == AssetType.animation) return false;
            if (lower.contains('/materials/') || lower.contains('/textures/') || lower.contains('/animations/')) return false;
            if (nameLower.startsWith('m_') || nameLower.startsWith('mi_') || nameLower.startsWith('t_') || nameLower.startsWith('sm_')) return false;
            return a.type == AssetType.filameshSk ||
                nameLower.startsWith('skm_') ||
                lower.contains('/skeletal') ||
                lower.contains('/skm');
          }).toList();
        } catch (_) {}
      }

      // Restore metadata
      final animPropsJson = _asset?.metadata['anim_properties'];
      if (animPropsJson != null && animPropsJson.isNotEmpty) {
        try {
          final animProps = jsonDecode(animPropsJson) as Map<String, dynamic>;
          _rateScale = (animProps['rate_scale'] as num?)?.toDouble() ?? 1.0;
          _interpolation = animProps['interpolation'] as String? ?? 'Linear';
          _additiveType = animProps['additive_type'] as String? ?? 'No Additive';
          _frameRate = (animProps['frame_rate'] as num?)?.toDouble() ?? 30.0;
          _previewMeshPath = animProps['preview_mesh_path'] as String?;
          final defClip = animProps['default_clip'] as int?;
          if (defClip != null && defClip >= 0 && defClip < _clips.length) {
            _selectedClip = defClip;
          }
        } catch (_) {}
      }

      // If a preview mesh path is configured, bind it
      if (_previewMeshPath != null && _availableSkeletalMeshes.isNotEmpty) {
        final match = _availableSkeletalMeshes.where((m) => m.relativePath == _previewMeshPath).firstOrNull;
        if (match != null) {
          await setPreviewMesh(match, markDirty: false);
        }
      }

      // Restore notifies
      final notifiesJson = _asset?.metadata['notifies'];
      if (notifiesJson != null && notifiesJson.isNotEmpty) {
        try {
          final rawList = jsonDecode(notifiesJson) as List;
          _notifies = rawList.map((j) => EditorAnimNotify.fromJson(j as Map<String, dynamic>)).toList();
        } catch (_) {}
      }

      // Restore curves
      final curvesJson = _asset?.metadata['curves'];
      if (curvesJson != null && curvesJson.isNotEmpty) {
        try {
          final rawList = jsonDecode(curvesJson) as List;
          _curves = rawList.map((j) => AnimCurveData.fromJson(j as Map<String, dynamic>)).toList();
        } catch (_) {}
      }

      // Restore blendSpace
      final blendSpaceJson = _asset?.metadata['blend_space'];
      if (blendSpaceJson != null && blendSpaceJson.isNotEmpty) {
        try {
          final rawMap = jsonDecode(blendSpaceJson) as Map<String, dynamic>;
          _blendSpace = BlendSpaceData.fromJson(rawMap);
        } catch (_) {}
      }

      // Restore root motion
      final rootMotionStr = _asset?.metadata['root_motion'];
      if (rootMotionStr != null) {
        _enableRootMotion = rootMotionStr == 'true';
      }

      _positionSeconds = 0.0;
      _recentlyFiredNotifies.clear();
      _updatePlaybackController();
      _isLoading = false;
      _isDirty = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _hasError = true;
      notifyListeners();
    }
  }

  static String? _findProjectDir(String filePath) {
    Directory current = File(filePath).parent;
    while (current.path != current.parent.path) {
      if (Directory('${current.path}/contents').existsSync()) {
        return current.path;
      }
      current = current.parent;
    }
    return null;
  }

  static String formatTimecode(double seconds) {
    final totalMs = (seconds * 1000).round();
    final mins = (totalMs ~/ 60000).toString().padLeft(2, '0');
    final secs = ((totalMs % 60000) ~/ 1000).toString().padLeft(2, '0');
    final ms = (totalMs % 1000).toString().padLeft(3, '0');
    return '$mins:$secs:$ms';
  }

  @override
  Future<bool> save() async {
    final file = File(assetPath);
    final updatedMetadata = Map<String, String>.from(_asset?.metadata ?? {});

    updatedMetadata['last_modified'] = DateTime.now().toIso8601String();
    final animProps = {
      'rate_scale': _rateScale,
      'interpolation': _interpolation,
      'additive_type': _additiveType,
      'frame_rate': _frameRate,
      'default_clip': _selectedClip,
      'preview_mesh_path': _previewMeshPath,
    };
    updatedMetadata['anim_properties'] = jsonEncode(animProps);
    updatedMetadata['notifies'] = jsonEncode(_notifies.map((n) => n.toJson()).toList());
    updatedMetadata['curves'] = jsonEncode(_curves.map((c) => c.toJson()).toList());
    updatedMetadata['blend_space'] = jsonEncode(_blendSpace.toJson());
    updatedMetadata['root_motion'] = _enableRootMotion.toString();

    // References for blend samples
    final List<AssetReference> refs = [];
    for (final s in _blendSpace.samples) {
      if (s.assetPath.isNotEmpty) {
        refs.add(AssetReference(
          slotName: 'blend_sample_${s.id}',
          assetId: s.assetName,
          assetPath: s.assetPath,
        ));
      }
    }

    final updatedAsset = LuminaAsset(
      assetId: _asset?.assetId ?? fileBasename,
      name: _asset?.name ?? fileBasename,
      type: AssetType.animation,
      rawPayload: _asset?.rawPayload,
      rawMatSource: _asset?.rawMatSource ?? '',
      metadata: updatedMetadata,
      references: refs,
    );

    try {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(updatedAsset.toProtoBufferBytes());
      _asset = updatedAsset;
      _isDirty = false;
      EngineLoggerService().log('Saved Animation asset to $assetPath', level: 'info');
      AssetRepository.notifyAssetsChanged();
      notifyListeners();
      return true;
    } catch (e, st) {
      EngineLoggerService().log('Failed to save Animation asset: $e\n$st', level: 'error');
      return false;
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    playbackController.dispose();
    super.dispose();
  }
}
