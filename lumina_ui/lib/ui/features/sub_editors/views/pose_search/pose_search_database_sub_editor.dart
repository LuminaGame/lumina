import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/sub_editor_binding.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/pose_search_database_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/pose_search/pose_search_clip_tree.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/pose_search/pose_search_database_clip_list.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/pose_search/pose_search_details_panel.dart';

/// The Pose Search Database editor (motion matching): the target mesh's
/// clips on the left, the database's clips and the feature cache's build
/// statistics in the middle, the clip / search / schema Details on the
/// right, and Build (a background isolate writes the `.posedb` cache next to
/// the asset), Save, Undo and Redo in the toolbar.
class PoseSearchDatabaseSubEditor extends StatefulWidget {
  final String assetName;
  final String assetPath;
  final VoidCallback? onClose;
  final SubEditorBindCallback? onBind;
  final PoseSearchDatabaseEditorViewModel? viewModel;

  const PoseSearchDatabaseSubEditor({
    super.key,
    required this.assetName,
    required this.assetPath,
    this.onClose,
    this.onBind,
    this.viewModel,
  });

  @override
  State<PoseSearchDatabaseSubEditor> createState() => PoseSearchDatabaseSubEditorState();
}

class PoseSearchDatabaseSubEditorState extends State<PoseSearchDatabaseSubEditor> {
  late final PoseSearchDatabaseEditorViewModel _vm;
  late final bool _owns;

  PoseSearchDatabaseEditorViewModel get viewModel => _vm;

  @override
  void initState() {
    super.initState();
    _owns = widget.viewModel == null;
    _vm = widget.viewModel ?? PoseSearchDatabaseEditorViewModel(assetPath: widget.assetPath);
    widget.onBind?.call(_vm, _vm.save, () => _vm.isDirty);
    if (_owns) _vm.load();
  }

  @override
  void dispose() {
    if (_owns) _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _vm.undo,
          const SingleActivator(LogicalKeyboardKey.keyY, control: true): _vm.redo,
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): () => _vm.save(),
        },
        child: ListenableBuilder(
          listenable: Listenable.merge([_vm, _vm.transactions]),
          builder: (context, _) => Container(
            color: EditorColors.background,
            child: Column(
              children: [
                _toolbar(),
                const Divider(height: 1),
                Expanded(
                  child: ResizablePanel.horizontal(
                    draggerBuilder: (context) => const HorizontalResizableDragger(),
                    children: [
                      ResizablePane(initialSize: 280, minSize: 180, child: PoseSearchClipTree(viewModel: _vm)),
                      ResizablePane.flex(child: PoseSearchDatabaseClipList(viewModel: _vm)),
                      ResizablePane(initialSize: 300, minSize: 200, child: PoseSearchDetailsPanel(viewModel: _vm)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _toolbar() {
    final tx = _vm.transactions;
    final d = _vm.document;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: EditorColors.card,
      child: Row(
        children: [
          const OutlineBadge(child: Text('POSE SEARCH DATABASE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          Flexible(
            child: Text('${widget.assetName}${_vm.isDirty ? ' *' : ''}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
                '${d.clips.length} clips · Target: ${d.targetMesh.split('/').last.replaceAll('.lmas', '')}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
          ),
          const Spacer(),
          GhostButton(
              key: const ValueKey('psd_undo'),
              size: ButtonSize.small,
              onPressed: tx.canUndo ? _vm.undo : null,
              child: const Icon(LucideIcons.undo2, size: 13)),
          GhostButton(
              key: const ValueKey('psd_redo'),
              size: ButtonSize.small,
              onPressed: tx.canRedo ? _vm.redo : null,
              child: const Icon(LucideIcons.redo2, size: 13)),
          const SizedBox(width: 6),
          OutlineButton(
            key: const ValueKey('psd_build'),
            size: ButtonSize.small,
            onPressed: _vm.isBuilding || d.clips.isEmpty ? null : () => _vm.build(),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(LucideIcons.hammer, size: 12),
              const SizedBox(width: 4),
              Text(_vm.isBuilding ? 'Building…' : 'Build', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(width: 6),
          PrimaryButton(
            key: const ValueKey('psd_save'),
            size: ButtonSize.small,
            onPressed: () => _vm.save(),
            child: const Text('Save', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          GhostButton(size: ButtonSize.small, onPressed: widget.onClose, child: const Icon(LucideIcons.x, size: 14)),
        ],
      ),
    );
  }
}
