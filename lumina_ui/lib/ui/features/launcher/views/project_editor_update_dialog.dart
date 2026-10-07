import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// The answers of [ProjectEditorUpdateDialog].
enum ProjectEditorUpdateChoice { update, openWithOldEditor, cancel }

/// What the user chose, and whether "Don't ask again for this version" was
/// ticked (it applies to [ProjectEditorUpdateChoice.openWithOldEditor]).
class ProjectEditorUpdateAnswer {
  final ProjectEditorUpdateChoice choice;
  final bool dontAskAgain;

  const ProjectEditorUpdateAnswer(this.choice, {this.dontAskAgain = false});

  static const ProjectEditorUpdateAnswer cancel = ProjectEditorUpdateAnswer(ProjectEditorUpdateChoice.cancel);
}

/// A project whose editor was set up with another Lumina than the one
/// opening it: update the project's copy of the engine source and rebuild
/// its editor, or open it with the editor it has.
class ProjectEditorUpdateDialog extends StatefulWidget {
  final String projectName;

  /// The engine the project's editor comes from ("0.0.1-dev.6", "an older
  /// engine").
  final String fromLabel;

  /// This Studio's engine.
  final String toLabel;

  const ProjectEditorUpdateDialog({super.key, required this.projectName, required this.fromLabel, required this.toLabel});

  /// Shows the dialog; closing it without an answer is Cancel.
  static Future<ProjectEditorUpdateAnswer> show(BuildContext context,
      {required String projectName, required String fromLabel, required String toLabel}) async {
    final answer = await showOverlay<ProjectEditorUpdateAnswer>(
      context,
      const DialogConfiguration(),
      builder: (_) => ProjectEditorUpdateDialog(projectName: projectName, fromLabel: fromLabel, toLabel: toLabel),
    ).future;
    return answer ?? ProjectEditorUpdateAnswer.cancel;
  }

  /// "Lumina 0.0.1-dev.6", or "an older engine" as it is.
  static String lumina(String label) => label.startsWith('an ') ? label : 'Lumina $label';

  @override
  State<ProjectEditorUpdateDialog> createState() => _ProjectEditorUpdateDialogState();
}

class _ProjectEditorUpdateDialogState extends State<ProjectEditorUpdateDialog> {
  bool _dontAskAgain = false;

  void _answer(ProjectEditorUpdateChoice choice) =>
      Navigator.of(context).pop(ProjectEditorUpdateAnswer(choice, dontAskAgain: _dontAskAgain));

  @override
  Widget build(BuildContext context) {
    final from = ProjectEditorUpdateDialog.lumina(widget.fromLabel);
    final to = ProjectEditorUpdateDialog.lumina(widget.toLabel);
    return AlertDialog(
      key: const Key('project_editor_update_dialog'),
      title: const Text("Update this project's editor?"),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.projectName} was set up with $from; this Studio is $to. '
              "Update the project's editor to $to?",
              key: const Key('project_editor_update_text'),
              style: const TextStyle(fontSize: 12, color: EditorColors.foreground),
            ),
            const SizedBox(height: 8),
            const Text(
              "Its copy of the engine source is replaced and the editor is rebuilt; edits made inside .lumina/editor are lost.",
              key: Key('project_editor_update_warning'),
              style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _dontAskAgain = !_dontAskAgain),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Checkbox(
                  key: const Key('project_editor_update_dont_ask'),
                  state: _dontAskAgain ? CheckboxState.checked : CheckboxState.unchecked,
                  onChanged: (s) => setState(() => _dontAskAgain = s == CheckboxState.checked),
                ),
                const SizedBox(width: 8),
                const Text("Don't ask again for this version",
                    style: TextStyle(fontSize: 11, color: EditorColors.foreground)),
              ]),
            ),
          ],
        ),
      ),
      actions: [
        GhostButton(
          key: const Key('project_editor_update_cancel'),
          onPressed: () => _answer(ProjectEditorUpdateChoice.cancel),
          child: const Text('Cancel'),
        ),
        OutlineButton(
          key: const Key('project_editor_update_open_old'),
          onPressed: () => _answer(ProjectEditorUpdateChoice.openWithOldEditor),
          child: const Text('Open with the old editor'),
        ),
        PrimaryButton(
          key: const Key('project_editor_update_update'),
          // "Don't ask again" is about not updating; Update never stores it.
          onPressed: () => Navigator.of(context).pop(const ProjectEditorUpdateAnswer(ProjectEditorUpdateChoice.update)),
          child: const Text('Update'),
        ),
      ],
    );
  }
}
