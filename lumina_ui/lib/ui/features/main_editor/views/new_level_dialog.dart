import 'package:lumina_core/lumina_core.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// `File → New Level…` — a name plus the template the level starts from.
///
/// Every entry is honest about what it seeds (including `Empty`, which seeds
/// nothing on purpose), and the chosen template's actors and world-partition
/// section are written into the new `.lmas` before the editor switches to it,
/// so the level opens populated.
class NewLevelDialog extends StatefulWidget {
  final EditorViewModel viewModel;

  const NewLevelDialog({super.key, required this.viewModel});

  /// Opens the dialog over [ctx].
  static void show(BuildContext ctx, EditorViewModel viewModel) {
    showOverlay(
      ctx,
      const DialogConfiguration(),
      builder: (c) => NewLevelDialog(viewModel: viewModel),
    );
  }

  @override
  State<NewLevelDialog> createState() => _NewLevelDialogState();
}

class _NewLevelDialogState extends State<NewLevelDialog> {
  final TextEditingController _name = TextEditingController();
  String _templateId = kDefaultLevelTemplateId;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    // Re-evaluate [_nameTaken] on every edit, whatever changed the text.
    _name.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _name.removeListener(_onNameChanged);
    _name.dispose();
    super.dispose();
  }

  /// The name is already a level on disk: New Level must never
  /// overwrite it, so Create is disabled and the field says why.
  bool get _nameTaken => widget.viewModel.levelNameTaken(_name.text);

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty || _creating || _nameTaken) return;
    setState(() => _creating = true);
    final navigator = Navigator.of(context);
    // The new level replaces the open one, so its unsaved changes
    // are saved or dropped on the user's say, never silently.
    if (!await widget.viewModel.confirmLeavingLevel(context: context)) {
      if (mounted) setState(() => _creating = false);
      return;
    }
    final created = await widget.viewModel.createLevelFromTemplate(name, _templateId);
    if (!created) {
      if (mounted) setState(() => _creating = false);
      return;
    }
    if (navigator.mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Level'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('new_level_name'),
              controller: _name,
              placeholder: const Text('Level Name (e.g. L_Dungeon)'),
              onSubmitted: (_) => _create(),
            ),
            if (_nameTaken) ...[
              const SizedBox(height: 6),
              Text(
                'A level named ${_name.text.trim()} already exists.',
                key: const ValueKey('new_level_name_taken'),
                style: const TextStyle(fontSize: 10, color: EditorColors.destructive),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'TEMPLATE',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: EditorColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 6),
            for (final template in LevelTemplateCatalog.all)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _TemplateTile(
                  key: ValueKey('new_level_template_${template.id}'),
                  template: template,
                  selected: _templateId == template.id,
                  onSelected: () => setState(() => _templateId = template.id),
                ),
              ),
          ],
        ),
      ),
      actions: [
        PrimaryButton(
          key: const ValueKey('new_level_create'),
          onPressed: _creating || _nameTaken ? null : _create,
          child: const Text('Create'),
        ),
        OutlineButton(
          key: const ValueKey('new_level_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// One selectable template row. It is a real focusable button, so the list is
/// keyboard-navigable with Tab / Enter without any custom key handling.
class _TemplateTile extends StatelessWidget {
  final LevelTemplate template;
  final bool selected;
  final VoidCallback onSelected;

  const _TemplateTile({
    super.key,
    required this.template,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          selected ? LucideIcons.circleCheck : LucideIcons.circle,
          size: 14,
          color: selected ? EditorColors.primary : EditorColors.mutedForeground,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                template.title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: selected ? EditorColors.primary : EditorColors.foreground,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                template.description,
                style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
              ),
            ],
          ),
        ),
      ],
    );

    return SizedBox(
      width: double.infinity,
      child: selected
          ? SecondaryButton(onPressed: onSelected, child: body)
          : OutlineButton(onPressed: onSelected, child: body),
    );
  }
}
