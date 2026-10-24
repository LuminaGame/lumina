import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/features/sub_editors/sub_editor_binding.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/tab_bar_actions.dart';
import 'package:lumina_ui/ui/core/widgets/editor_island.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/texture_editor_view_model.dart';

part 'texture_sub_editor/state.dart';
part 'texture_sub_editor/left_sidebar.dart';
part 'texture_sub_editor/canvas.dart';
part 'texture_sub_editor/right_sidebar.dart';
part 'texture_sub_editor/canvas_painter.dart';

class TextureSubEditor extends StatefulWidget {
  final String assetName;
  final String? assetPath;
  final RealAssetInfo? asset;
  final TextureEditorViewModel? viewModel;
  final VoidCallback? onClose;
  final SubEditorBindCallback? onBind;

  const TextureSubEditor({
    super.key,
    required this.assetName,
    this.assetPath,
    this.asset,
    this.viewModel,
    this.onClose,
    this.onBind,
  });

  @override
  State<TextureSubEditor> createState() => _TextureSubEditorState();
}

class _TextureSubEditorState extends _TextureSubEditorStateBase
    with _TextureSubEditorLeftSidebar, _TextureSubEditorCanvas, _TextureSubEditorRightSidebar {
  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    final path = widget.assetPath ?? widget.asset?.lmasPath ?? widget.asset?.relativePath ?? 'contents/textures/${widget.assetName}.lmas';
    _viewModel = widget.viewModel ?? TextureEditorViewModel(assetPath: path);
    widget.onBind?.call(_viewModel, _viewModel.save, () => _viewModel.isDirty);

    if (_ownsViewModel) {
      _viewModel.load();
    }
  }

  @override
  void dispose() {
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final isDirty = _viewModel.isDirty;

        if (_viewModel.isLoading) {
          return Container(
            color: EditorColors.background,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Decoding texture payload & generating MIP chain...', style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
                ],
              ),
            ),
          );
        }

        if (_viewModel.hasError) {
          return Container(
            color: EditorColors.background,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.triangleAlert, size: 28, color: EditorColors.logError),
                  const SizedBox(height: 8),
                  Text('Failed to load texture asset at ${_viewModel.assetPath}', style: const TextStyle(fontSize: 11, color: EditorColors.foreground)),
                  const SizedBox(height: 16),
                  OutlineButton(
                    onPressed: widget.onClose,
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          color: EditorColors.background,
          child: Column(
            children: [
              // 1. Top Toolbar
              _buildToolbar(isDirty),
              const Divider(height: 1),

              // 2. Main 3-Panel Workspace
              Expanded(
                child: EditorIslandGround(child: ResizablePanel.horizontal(
                  dividerBuilder: EditorIslandDividers.gap,
                  children: [
                    // Left Panel: Metadata & Channel Isolation & MIP Selection
                    ResizablePane(
                      initialSize: 260,
                      minSize: 220,
                      child: EditorIsland(key: const ValueKey('texture_island_left'), child: _buildLeftSidebar()),
                    ),

                    // Center Panel: Zoom/Pan Canvas with Pixel Inspector Bar
                    ResizablePane.flex(
                      child: EditorIsland(key: const ValueKey('texture_island_canvas'), color: EditorColors.viewportBackdrop, child: Column(
                        children: [
                          Expanded(
                            child: _buildCanvas(),
                          ),
                          const Divider(height: 1),
                          _buildPixelInspectorBar(),
                        ],
                      )),
                    ),

                    // Right Panel: Compression, MipGen, and Sampler Settings
                    ResizablePane(
                      initialSize: 290,
                      minSize: 240,
                      child: EditorIsland(key: const ValueKey('texture_island_right'), child: _buildRightSidebar()),
                    ),
                  ],
                )),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbar(bool isDirty) {
    final vm = _viewModel;
    return SubEditorToolbar(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: EditorColors.card,
      children: [
          SubEditorToolbarTitle(child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text('TEXTURE 2D', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.teal)),
          ),
const SizedBox(width: 8),
Text(
            '${widget.assetName}${isDirty ? ' *' : ''}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EditorColors.foreground),
          ),
          ])),
          const SizedBox(width: 12),

          OutlineBadge(
            child: Text('${vm.width} × ${vm.height}', style: const TextStyle(fontSize: 9)),
          ),
          const SizedBox(width: 6),

          OutlineBadge(
            child: Text('${vm.mipChain.length} Mips', style: const TextStyle(fontSize: 9)),
          ),
          const Spacer(),

          // Reimport Button
          OutlineButton(
            size: ButtonSize.small,
            onPressed: vm.sourceFilePath != null ? () => vm.reimport() : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.refreshCw, size: 11),
                SizedBox(width: 4),
                Text('Reimport', style: TextStyle(fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Save Button
          PrimaryButton(
            size: ButtonSize.small,
            onPressed: isDirty ? () => vm.save() : null,
            child: const Text('Save', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),

          // Close Button
          SubEditorToolbarClose(child: GhostButton(
            size: ButtonSize.small,
            onPressed: widget.onClose,
            child: const Icon(LucideIcons.x, size: 14),
          ))
      ],
    );
  }

}
