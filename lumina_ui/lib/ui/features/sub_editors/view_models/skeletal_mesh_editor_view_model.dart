import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_slot_binding.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/skeletal_mesh_socket.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/skeletal_socket_attachment.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_sampler_parser.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';

part 'skeletal_mesh_editor_view_model/state.dart';
part 'skeletal_mesh_editor_view_model/sockets.dart';
part 'skeletal_mesh_editor_view_model/material_slots.dart';
part 'skeletal_mesh_editor_view_model/bones_and_morphs.dart';
part 'skeletal_mesh_editor_view_model/rig_logic.dart';

class SkeletalMeshEditorViewModel extends _SkeletalMeshEditorViewModelState
    with _SkeletalMeshSockets, _SkeletalMeshMaterialSlots, _SkeletalMeshBonesAndMorphs, _SkeletalMeshRigLogic {
  SkeletalMeshEditorViewModel({
    required super.assetPath,
    super.initialAsset,
  });

  String get fileBasename {
    final file = File(assetPath);
    return file.path.split(Platform.pathSeparator).last.replaceAll('.lmas', '');
  }

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

      final bytes = await file.readAsBytes();
      try {
        _asset = LuminaAsset.fromBytes(bytes);
      } catch (_) {}

      try {
        _glbMesh = await AssetRepository.loadMeshFromDisk(assetPath);
      } catch (_) {}

      // Extract geometry and bone statistics
      if (_glbMesh != null) {
        _triangleCount = _glbMesh!.triangleCount;
        _vertexCount = _glbMesh!.vertexCount;
        _boneCount = _glbMesh!.boneCount;

        _allBones = _glbMesh!.allNodes.where((n) => n.type == GlbNodeType.bone).toList();

        // If no explicit skin joints found, treat all non-mesh nodes as potential hierarchy
        if (_allBones.isEmpty && _glbMesh!.allNodes.isNotEmpty) {
          _allBones = _glbMesh!.allNodes.where((n) => n.type != GlbNodeType.mesh).toList();
        }

        // Build filtered root bones
        _rootBones = _glbMesh!.rootNodes.where((n) => _nodeOrChildrenContainBone(n)).toList();
        if (_rootBones.isEmpty && _allBones.isNotEmpty) {
          _rootBones = [_allBones.first];
        }

        // Initialize morph targets
        _morphWeights.clear();
        for (final target in _glbMesh!.morphTargets) {
          _morphWeights[target.name] = 0.0;
        }
      } else if (_asset?.metadata != null) {
        final meta = _asset!.metadata;
        _triangleCount = int.tryParse(meta['triangle_count'] ?? '0') ?? 0;
        _vertexCount = int.tryParse(meta['vertex_count'] ?? '0') ?? 0;
        _boneCount = int.tryParse(meta['bone_count'] ?? '0') ?? 0;

        if (meta.containsKey('bones')) {
          final boneNames = meta['bones']!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          _allBones = List.generate(boneNames.length, (i) => GlbNode(index: i, name: boneNames[i], type: GlbNodeType.bone));
          if (_allBones.isNotEmpty) {
            _rootBones = [_allBones.first];
            for (int i = 0; i < _allBones.length - 1; i++) {
              _allBones[i].children.add(_allBones[i + 1]);
            }
          }
        }
      }

      // Load Sockets
      if (_asset?.metadata.containsKey('sockets') == true) {
        try {
          final socketsRaw = jsonDecode(_asset!.metadata['sockets']!);
          if (socketsRaw is Map && socketsRaw.containsKey('sockets')) {
            final list = socketsRaw['sockets'] as List;
            _sockets = list.map((s) => SkeletalMeshSocket.fromJson(Map<String, dynamic>.from(s as Map))).toList();
          } else if (socketsRaw is List) {
            _sockets = socketsRaw.map((s) => SkeletalMeshSocket.fromJson(Map<String, dynamic>.from(s as Map))).toList();
          }
        } catch (e) {
          _sockets = [];
        }
      } else {
        _sockets = [];
      }

      // Load Retargeting Options
      if (_asset?.metadata.containsKey('bone_retargeting') == true) {
        try {
          final retargetMap = jsonDecode(_asset!.metadata['bone_retargeting']!) as Map;
          _boneRetargeting = Map<String, String>.from(retargetMap);
        } catch (_) {
          _boneRetargeting = {};
        }
      }

      // Load Morph Defaults
      if (_asset?.metadata.containsKey('morph_defaults') == true) {
        try {
          final morphMap = jsonDecode(_asset!.metadata['morph_defaults']!) as Map;
          for (final entry in morphMap.entries) {
            final w = (entry.value as num?)?.toDouble() ?? 0.0;
            _morphWeights[entry.key.toString()] = w;
          }
        } catch (_) {}
      }

      // Load Associated DNA Rig if recorded or auto-detected
      final recordedDna = _asset?.metadata['face_dna_path'] ?? _asset?.metadata['dna_path'];
      if (recordedDna != null && recordedDna.isNotEmpty) {
        if (File(recordedDna).existsSync()) {
          await loadDnaFile(recordedDna);
        } else {
          final siblingName = recordedDna.split(RegExp(r'[\\/]')).last;
          final sibling = File('${file.parent.path}/$siblingName');
          if (sibling.existsSync()) {
            await loadDnaFile(sibling.path);
          }
        }
      }
      if (_rigLogicEvaluator == null) {
        // Auto-detect matching .dna file next to the asset (prefer face DNA, avoid _body.dna)
        final dnaSibling = File(assetPath.replaceAll('.lmas', '.dna'));
        if (dnaSibling.existsSync()) {
          await loadDnaFile(dnaSibling.path);
        } else if (file.parent.existsSync()) {
          for (final entity in file.parent.listSync()) {
            if (entity is File &&
                entity.path.endsWith('.dna') &&
                !entity.path.endsWith('_body.dna') &&
                !entity.path.endsWith('_combined.dna')) {
              await loadDnaFile(entity.path);
              break;
            }
          }
        }
      }

      _initializeMaterialSlots();
      _scanProjectMaterialsAndTextures();
      await refreshSlotSamplers();

      _isDirty = false;
      _isLoading = false;
      notifyListeners();
    } catch (e, st) {
      _hasError = true;
      _isLoading = false;
      EngineLoggerService().log('Failed to load skeletal mesh: $e\n$st', level: 'error');
      notifyListeners();
    }
  }

  Future<bool> save() async {
    final file = File(assetPath);
    final updatedMetadata = Map<String, String>.from(_asset?.metadata ?? {});

    updatedMetadata['last_modified'] = DateTime.now().toIso8601String();
    updatedMetadata['triangle_count'] = _triangleCount.toString();
    updatedMetadata['vertex_count'] = _vertexCount.toString();
    updatedMetadata['bone_count'] = _boneCount.toString();

    // Sockets serialization
    final socketsJson = {
      'v': 1,
      'sockets': _sockets.map((s) => s.toJson()).toList(),
    };
    updatedMetadata['sockets'] = jsonEncode(socketsJson);

    // Bone retargeting serialization
    if (_boneRetargeting.isNotEmpty) {
      updatedMetadata['bone_retargeting'] = jsonEncode(_boneRetargeting);
    } else {
      updatedMetadata.remove('bone_retargeting');
    }

    // Morph defaults serialization
    if (_morphWeights.isNotEmpty) {
      updatedMetadata['morph_defaults'] = jsonEncode(_morphWeights);
    } else {
      updatedMetadata.remove('morph_defaults');
    }

    // DNA Rig Path serialization
    if (_dnaPath != null) {
      updatedMetadata['dna_path'] = _dnaPath!;
      updatedMetadata['face_dna_path'] = _dnaPath!;
    } else {
      updatedMetadata.remove('dna_path');
      updatedMetadata.remove('face_dna_path');
    }

    // Material slot bindings: one AssetReference per bound slot, replacing any
    // element_* references the asset already carried so a re-save cannot
    // accumulate duplicates. References for other slot namespaces pass through.
    final updatedRefs = <AssetReference>[
      ...?_asset?.references.where((r) => !r.slotName.startsWith('element_')),
    ];
    final textureOverrides = <String, dynamic>{};
    for (final slot in _materialSlots) {
      if (slot.assignedMaterialPath != null && slot.assignedMaterialId != null) {
        updatedRefs.add(AssetReference(
          assetId: slot.assignedMaterialId!,
          assetPath: slot.assignedMaterialPath!,
          slotName: slot.slotName,
        ));
      }
      for (final entry in slot.textureBindings.entries) {
        textureOverrides['${slot.slotName}/${entry.key}'] = entry.value.toJson();
      }
    }

    if (textureOverrides.isNotEmpty) {
      updatedMetadata['materialTextures'] = jsonEncode(textureOverrides);
    } else {
      updatedMetadata.remove('materialTextures');
    }

    final updatedAsset = LuminaAsset(
      assetId: _asset?.assetId ?? fileBasename,
      name: _asset?.name ?? fileBasename,
      type: AssetType.filamesh,
      rawPayload: _asset?.rawPayload,
      rawMatSource: _asset?.rawMatSource ?? '',
      metadata: updatedMetadata,
      references: updatedRefs,
    );

    try {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(updatedAsset.toProtoBufferBytes());
      _asset = updatedAsset;
      _isDirty = false;
      EngineLoggerService().log('Saved SkeletalMesh asset to $assetPath', level: 'info');
      notifyListeners();
      return true;
    } catch (e, st) {
      EngineLoggerService().log('Failed to save SkeletalMesh asset: $e\n$st', level: 'error');
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _rigLogicEvaluator?.dispose();
    super.dispose();
  }
}
