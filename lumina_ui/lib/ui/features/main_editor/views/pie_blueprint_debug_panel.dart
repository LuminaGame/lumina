import 'dart:io';

import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_debugger.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/level_blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/graph_canvas.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/play_blocked_dialog.dart' show openBlueprintAtNode;

/// The level editor's docked Blueprint tab: during
/// Play it shows the event graph of the Blueprint the debugger follows (the
/// possessed pawn, or the selected placed Blueprint) with its nodes and exec
/// wires lighting up as they run; hovering a data pin shows its last value.
/// Every debugged Blueprint — the level's own script too
/// — is listed above the graph to switch to.
class PieBlueprintDebugPanel extends StatefulWidget {
  final EditorViewModel viewModel;

  const PieBlueprintDebugPanel({super.key, required this.viewModel});

  @override
  State<PieBlueprintDebugPanel> createState() => PieBlueprintDebugPanelState();
}

class PieBlueprintDebugPanelState extends State<PieBlueprintDebugPanel> {
  String? _path;
  BlueprintEditorViewModel? _graphVm;

  /// The Blueprint the user picked from the list; null follows the default
  /// (a selected placed instance, else the pawn, else the level script).
  String? _picked;

  /// Shows [path]'s graph (one of the debugged Blueprints).
  void pick(String path) {
    _picked = path;
    _sync();
  }

  /// The class shown, for tests.
  String? get debuggedPath => _path;
  BlueprintEditorViewModel? get graphViewModel => _graphVm;

  @override
  void initState() {
    super.initState();
    BlueprintPieDebugger.instance.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    BlueprintPieDebugger.instance.removeListener(_sync);
    _graphVm?.dispose();
    super.dispose();
  }

  void _sync() {
    final targets = BlueprintPieDebugger.instance.targets.keys.toList();
    // A selected placed instance wins over the pawn, the pawn over the level
    // script: they are added in that order, reversed. A picked one wins.
    if (_picked != null && !targets.contains(_picked)) _picked = null;
    final path = _picked ?? (targets.isEmpty ? null : targets.last);
    if (path == _path) {
      if (path != null) _graphVm?.eventGraph.debug = BlueprintPieDebugger.instance.recorderFor(path);
      return;
    }
    _graphVm?.dispose();
    _graphVm = null;
    _path = path;
    if (path != null) {
      final file = '${widget.viewModel.projectDirPath}/$path';
      if (File(file).existsSync()) {
        final vm = path.startsWith('contents/levels/')
            ? LevelBlueprintEditorViewModel(projectDirectory: widget.viewModel.projectDirPath, levelPath: path)
            : BlueprintEditorViewModel(assetPath: file);
        _graphVm = vm;
        vm.load().then((_) {
          if (!mounted || !identical(_graphVm, vm)) return;
          vm.eventGraph.debug = BlueprintPieDebugger.instance.recorderFor(path);
          setState(() {});
        });
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;
    final vm = _graphVm;
    if (path == null || vm == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Press Play: the possessed Blueprint pawn\'s event graph shows here and lights up as it runs '
            '(select a placed Blueprint actor to follow it instead).',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
          ),
        ),
      );
    }
    final name = path.split('/').last.replaceAll('.lmas', '');
    final targets = BlueprintPieDebugger.instance.targets.keys.toList();
    String label(String p) {
      final n = p.split('/').last.replaceAll('.lmas', '');
      return p.startsWith('contents/levels/') ? '$n (Level Blueprint)' : n;
    }

    return Column(
      children: [
        if (targets.length > 1)
          Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: EditorColors.card,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final t in targets)
                  Padding(
                    padding: const EdgeInsets.only(right: 4, top: 2, bottom: 2),
                    child: t == path
                        ? SecondaryButton(
                            key: ValueKey('pie_debug_target_$t'),
                            size: ButtonSize.xSmall,
                            onPressed: () => pick(t),
                            child: Text(label(t), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                          )
                        : GhostButton(
                            key: ValueKey('pie_debug_target_$t'),
                            size: ButtonSize.xSmall,
                            onPressed: () => pick(t),
                            child: Text(label(t), style: const TextStyle(fontSize: 9)),
                          ),
                  ),
              ],
            ),
          ),
        Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: EditorColors.cardHeader,
          child: Row(
            children: [
              const Icon(LucideIcons.bug, size: 12, color: Color(0xFFFFB300)), // the debugger amber, as the executed-node glow
              const SizedBox(width: 6),
              Text('Debugging ${label(path)}', key: const ValueKey('pie_debug_title'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              const Text('edits apply on the next Play', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
              const Spacer(),
              GhostButton(
                size: ButtonSize.xSmall,
                onPressed: () => openBlueprintAtNode(widget.viewModel, path, null),
                child: const Text('Open in Blueprint Editor', style: TextStyle(fontSize: 9)),
              ),
            ],
          ),
        ),
        Expanded(child: BlueprintGraphCanvas(key: ValueKey('pie_debug_canvas_$path'), editor: vm.eventGraph, graphLabel: name)),
      ],
    );
  }
}
