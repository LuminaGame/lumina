import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/plugin_3d_viewport_container.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/plugin_view/plugin_view_scope.dart';

/// [PluginControlKind.preview3d]: `scene` ([PluginSceneSpec] json) and
/// `height` (default 240), drawn with the editor's plugin viewport
/// ([Plugin3DViewportContainer]): orbit camera, the scene's
/// `cameraDistance`, a node's `jointLocalPose` on its skeleton.
///
/// The viewport shows one node at a time: the first, or the one the user
/// picked. Every node is listed under the viewport; clicking one shows it
/// and sends `picked` with `{"node": <name>}`. Node transforms
/// (`location`/`rotation`/`scale`) and `cameraTarget` are not applied: the
/// viewport frames the shown mesh itself.
class PluginPreview3dControl extends StatefulWidget {
  const PluginPreview3dControl({super.key, required this.control});

  final PluginControl control;

  static PluginSceneSpec? sceneOf(PluginControl c) {
    final json = c.map('scene');
    if (json == null) return null;
    try {
      return PluginSceneSpec.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  State<PluginPreview3dControl> createState() => _PluginPreview3dControlState();
}

class _PluginPreview3dControlState extends State<PluginPreview3dControl> {
  String? _shown;

  @override
  Widget build(BuildContext context) {
    final c = widget.control;
    final host = PluginViewScope.of(context);
    final key = host.keyOf(c.id).value;
    final height = c.number('height')?.toDouble() ?? 240;
    final scene = PluginPreview3dControl.sceneOf(c);
    const muted = TextStyle(fontSize: EditorTypography.captionSize, color: EditorColors.mutedForeground);
    if (scene == null || scene.nodes.isEmpty) {
      return PluginFieldRow(
        label: c.label,
        child: Container(
          height: height,
          alignment: Alignment.center,
          color: EditorColors.viewportBackdrop,
          child: Text(scene == null ? 'no scene' : 'empty scene', style: muted),
        ),
      );
    }
    final node = scene.nodes.where((n) => n.name == _shown).firstOrNull ?? scene.nodes.first;
    final viewport = SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Plugin3DViewportContainer(
          key: ValueKey('$key/viewport'),
          projectDir: host.projectDir,
          options: Plugin3DViewportOptions(
            title: c.label ?? node.name,
            meshPath: node.meshPath,
            jointLocalPose: node.jointLocalPose,
            cameraDistance: scene.cameraDistance,
            showGizmo: false,
          ),
        ),
      ),
    );
    final nodes = Wrap(
      spacing: EditorDensity.gap,
      runSpacing: EditorDensity.gap,
      children: [
        for (final n in scene.nodes)
          Button(
            key: ValueKey('$key/node/${n.name}'),
            style: n.name == node.name
                ? const ButtonStyle.secondary(size: ButtonSize.small)
                : const ButtonStyle.ghost(size: ButtonSize.small),
            leading: const Icon(LucideIcons.box, size: 10),
            onPressed: () {
              setState(() => _shown = n.name);
              host.emit(c.id, 'picked', {'node': n.name});
            },
            child: Text(n.name, style: const TextStyle(fontSize: 9)),
          ),
      ],
    );
    return withPluginTooltip(
      c.tooltip,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [viewport, const SizedBox(height: EditorDensity.gap), nodes],
      ),
    );
  }
}
