import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_debugger.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/property_editors/collision_section_editor.dart';
import 'package:lumina_ui/ui/core/property_editors/color_field.dart';
import 'package:lumina_ui/ui/core/property_editors/physics_section_editor.dart';
import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/core/property_editors/lumina_transform_widget.dart';
import 'package:lumina_ui/ui/core/property_editors/vector_row.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_component_registry.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_editor_nodes.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_graph_ref.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_palette.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_pin_style.dart';
import 'package:lumina_ui/ui/features/sub_editors/sub_editor_binding.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_graph_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/services/transform_gizmo.dart' show AuthoringRotation, TransformGizmoModel, TransformGizmoSnap;
import 'package:lumina_ui/ui/features/sub_editors/models/sub_editor_transform_gizmo.dart';
import 'package:vector_math/vector_math_64.dart' show Quaternion, Vector3;
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/compile_results.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/component_tree.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/graph_canvas.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/my_blueprint_panel.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/pin_literal_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/signature_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/timeline/timeline.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';

part 'sub_editor/state.dart';
part 'sub_editor/viewport_gizmo.dart';
part 'sub_editor/navigation.dart';
part 'sub_editor/layout.dart';
part 'sub_editor/graph_details.dart';
part 'sub_editor/component_details.dart';

/// The main editor's gizmo settings a Blueprint editor opens with.
class BlueprintGizmoDefaults {
  final GizmoMode mode;
  final GizmoSpace space;
  final TransformGizmoSnap snap;

  const BlueprintGizmoDefaults({
    this.mode = GizmoMode.translate,
    this.space = GizmoSpace.world,
    this.snap = TransformGizmoSnap.none,
  });
}

class BlueprintSubEditor extends StatefulWidget {
  final String assetName;
  final String? assetPath;
  final LuminaAsset? asset;
  final VoidCallback? onClose;
  final SubEditorBindCallback? onBind;
  final BlueprintEditorViewModel? viewModel;

  /// False replaces the 3D Viewport's Filament view with its summary; the
  /// preview still runs, in a world without a renderer (widget tests).
  final bool showPreviewViewport;

  /// What the 3D Viewport's component gizmo starts with:
  /// the level editor's tool, space and snap settings when opened from it.
  final BlueprintGizmoDefaults? gizmoDefaults;

  const BlueprintSubEditor({
    super.key,
    required this.assetName,
    this.assetPath,
    this.asset,
    this.onClose,
    this.onBind,
    this.viewModel,
    this.showPreviewViewport = true,
    this.gizmoDefaults,
  });

  @override
  State<BlueprintSubEditor> createState() => BlueprintSubEditorState();
}

class BlueprintSubEditorState extends _BlueprintSubEditorStateBase
    with
        _BlueprintSubEditorViewportGizmo,
        _BlueprintSubEditorNavigation,
        _BlueprintSubEditorLayout,
        _BlueprintSubEditorGraphDetails,
        _BlueprintSubEditorComponentDetails {

  @override
  BlueprintEditorViewModel get viewModel => _viewModel;

  /// A level's Blueprint: the same editor with only the
  /// Event Graph (and function / macro / timeline tabs), My Blueprint without
  /// Components, and Details without Class Defaults.
  @override
  bool get _isLevel => _viewModel.isLevelBlueprint;

  /// A widget's own graph: the Level Blueprint's
  /// configuration, embedded in the UMG designer under its toolbar.
  @override
  bool get _isWidget => _viewModel.isWidgetBlueprint;

  @override
  SubEditorTransformGizmo get transformGizmo => _gizmo;

  static List<double> _vec(dynamic v, double fallback) {
    final out = [fallback, fallback, fallback];
    if (v is List) {
      for (var i = 0; i < 3 && i < v.length; i++) {
        out[i] = (v[i] as num).toDouble();
      }
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ??
        BlueprintEditorViewModel(
          assetPath: widget.assetPath ?? 'contents/blueprints/${widget.assetName}.lmas',
          initialAsset: widget.asset,
        );
    widget.onBind?.call(_viewModel, _viewModel.save, () => _viewModel.isDirty);
    if (_isLevel || _isWidget) _activeLeftTab = 1;

    BlueprintNavigation.instance.addListener(_takeNavigation);
    BlueprintPieDebugger.instance.addListener(_syncDebugger);
    if (_ownsViewModel) {
      _viewModel.load().then((_) {
        if (!mounted) return;
        _takeNavigation();
        _syncDebugger();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _takeNavigation();
        _syncDebugger();
      });
    }
  }

  @override
  void dispose() {
    BlueprintNavigation.instance.removeListener(_takeNavigation);
    BlueprintPieDebugger.instance.removeListener(_syncDebugger);
    if (_viewModel.eventGraph.debug != null) _viewModel.eventGraph.debug = null;
    _gizmo.dispose();
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BlueprintSubEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final defaults = widget.gizmoDefaults;
    if (defaults != null) {
      _gizmo.setMode(defaults.mode);
      _gizmo.setSpace(defaults.space);
      _gizmo.setSnap(defaults.snap);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _viewModel.undo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): _viewModel.redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): _viewModel.redo,
        const SingleActivator(LogicalKeyboardKey.f7): _compile,
      },
      child: ListenableBuilder(
        listenable: Listenable.merge([_viewModel, _viewModel.eventGraph, _viewModel.activeGraphEditor, _viewModel.transactions, _viewModel.preview]),
        builder: (context, _) {
          final isDirty = _viewModel.isDirty;
          return Container(
            color: EditorColors.background,
            child: Column(
              children: [
                if (!_isWidget) ...[
                  _toolbar(isDirty),
                  const Divider(height: 1),
                ],
                Expanded(
                  child: ResizablePanel.horizontal(
                    children: [
                      ResizablePane(
                        initialSize: 250,
                        minSize: 200,
                        child: Container(
                          color: EditorColors.cardHeader,
                          child: Column(
                            children: [
                              Container(
                                height: 30,
                                color: EditorColors.card,
                                child: Row(
                                  children: [
                                    if (!_isLevel && !_isWidget) _buildLeftTabBtn(0, 'Components'),
                                    _buildLeftTabBtn(1, 'My Blueprint'),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              Expanded(
                                child: _activeLeftTab == 0 && !_isLevel && !_isWidget
                                    ? BlueprintComponentTree(viewModel: _viewModel)
                                    : _buildMyBlueprintView(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ResizablePane.flex(
                        child: Column(
                          children: [
                            // The active graph tab joins
                            // the canvas under it (no divider, no bottom edge).
                            Container(
                              height: 30,
                              color: EditorColors.sidebar,
                              padding: const EdgeInsets.only(left: 8, right: 8, top: 4),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  EditorTabStyle.stripBottomLine(),
                                  ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  _buildGraphTabBtn(BlueprintGraphRef.eventGraph, LucideIcons.gitFork),
                                  if (!_isLevel && !_isWidget) ...[
                                    _buildViewportTabBtn(),
                                    _buildGraphTabBtn(BlueprintGraphRef.constructionScript, LucideIcons.wrench),
                                  ],
                                  for (final g in _viewModel.graphs)
                                    if (g.isFunction || g.isMacro)
                                      _buildGraphTabBtn(g, g.isFunction ? LucideIcons.squareFunction : LucideIcons.boxes),
                                  if (_viewModel.activeGraph.isTimeline)
                                    _buildGraphTabBtn(_viewModel.activeGraph, LucideIcons.chartLine,
                                        label: 'Timeline: ${_viewModel.timelineNode(_viewModel.activeGraph.name!)?.title ?? ''}'),
                                ],
                              ),
                                ],
                              ),
                            ),
                            Expanded(child: _buildCenter()),
                            const Divider(height: 1),
                            SizedBox(height: 150, child: _bottomPanel()),
                          ],
                        ),
                      ),
                      ResizablePane(
                        initialSize: 290,
                        minSize: 230,
                        child: Container(
                          color: EditorColors.cardHeader,
                          child: _buildRightPanel(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
