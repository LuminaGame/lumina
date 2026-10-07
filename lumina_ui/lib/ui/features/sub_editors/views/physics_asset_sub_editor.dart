import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/physics_asset_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/physics_preview_scene.dart';
import 'package:lumina_ui/ui/features/sub_editors/sub_editor_binding.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/physics_asset_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';

part 'physics_asset/state.dart';
part 'physics_asset/toolbar_workspace.dart';
part 'physics_asset/tree_panel.dart';
part 'physics_asset/inspector.dart';

/// Lumina Studio's Physics Asset editor.
///
/// Authors per-bone bodies, constraints and disabled-collision pairs against a
/// real skeletal mesh, draws them over the live Filament preview, and runs
/// lumina's real narrow phase through `Validate Overlaps`. There is no ragdoll
/// simulation here: the engine has no dynamics solver, so the editor authors
/// data instead of faking a simulation.
class PhysicsAssetSubEditor extends StatefulWidget {
  final String assetName;
  final String? assetPath;
  final RealAssetInfo? asset;

  /// Skeletal meshes offered by the binder when the asset has no mesh link.
  final List<RealAssetInfo> skeletalMeshCandidates;

  final PhysicsAssetEditorViewModel? viewModel;
  final VoidCallback? onClose;
  final SubEditorBindCallback? onBind;

  const PhysicsAssetSubEditor({
    super.key,
    required this.assetName,
    this.assetPath,
    this.asset,
    this.skeletalMeshCandidates = const [],
    this.viewModel,
    this.onClose,
    this.onBind,
  });

  @override
  State<PhysicsAssetSubEditor> createState() => _PhysicsAssetSubEditorState();
}

class _PhysicsAssetSubEditorState extends _PhysicsAssetSubEditorStateBase
    with
        _PhysicsAssetToolbarWorkspace,
        _PhysicsAssetTreePanel,
        _PhysicsAssetInspector {

  /// Exposed for smoke tests that drive the real editor shell.
  PhysicsAssetEditorViewModel get viewModelForTest => _viewModel;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    final path = widget.assetPath ??
        widget.asset?.lmasPath ??
        widget.asset?.relativePath ??
        'contents/physics/${widget.assetName}.lmas';
    _viewModel = widget.viewModel ?? PhysicsAssetEditorViewModel(assetPath: path);
    widget.onBind?.call(_viewModel, _viewModel.save, () => _viewModel.isDirty);
    _viewModel.addListener(_syncOverlay);
    if (_ownsViewModel) {
      _viewModel.load();
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_syncOverlay);
    _previewScene.detach();
    for (final c in _controllers.values) {
      c.dispose();
    }
    _filterController.dispose();
    if (_ownsViewModel) _viewModel.dispose();
    super.dispose();
  }

  @override
  void _syncOverlay() {
    _previewScene.setMesh(_viewModel.skeletalMeshPath, _viewModel.glbMesh?.rawPayload);
    if (!_previewScene.isAttached) return;
    _previewScene.sync(_viewModel.buildOverlay());
    _previewScene.syncSolid(_viewModel.buildSolidBodies());
  }

  /// [onChanged] for a field whose controller [_controller] also writes.
  @override
  ValueChanged<String> _userEdit(ValueChanged<String> onChanged) => (value) {
        if (!_syncingField) onChanged(value);
      };

  /// The controller for inspector field [key], showing [text]. One
  /// controller per field, shared by every body (or constraint) the
  /// inspector shows.
  @override
  TextEditingController _controller(String key, String text) {
    final existing = _controllers[key];
    if (existing == null) {
      final created = TextEditingController(text: text);
      _controllers[key] = created;
      return created;
    }
    final current = double.tryParse(existing.text);
    final wanted = double.tryParse(text);
    final sameNumber = current != null && wanted != null && (current - wanted).abs() < 1e-9;
    if (existing.text != text && !sameNumber) {
      _syncingField = true;
      try {
        existing.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
      } finally {
        _syncingField = false;
      }
    }
    return existing;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        if (_viewModel.isLoading) {
          return const ColoredBox(
            color: EditorColors.background,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Loading physics asset...', style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
                ],
              ),
            ),
          );
        }

        return Container(
          color: EditorColors.background,
          child: Column(
            children: [
              _buildToolbar(),
              const Divider(height: 1),
              Expanded(
                child: _viewModel.hasSkeletalMesh ? _buildWorkspace() : _buildMeshBinder(),
              ),
            ],
          ),
        );
      },
    );
  }
}
