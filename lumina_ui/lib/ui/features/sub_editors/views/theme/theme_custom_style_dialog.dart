import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/theme_editor_view_model.dart';

/// Modal dialog for authoring a new custom style.
class ThemeCustomStyleDialog extends StatefulWidget {
  final ThemeEditorViewModel viewModel;

  const ThemeCustomStyleDialog({super.key, required this.viewModel});

  static Future<void> show(BuildContext context, ThemeEditorViewModel viewModel) {
    return showOverlay(
      context,
      const DialogConfiguration(),
      builder: (_) => ThemeCustomStyleDialog(viewModel: viewModel),
    ).future;
  }

  @override
  State<ThemeCustomStyleDialog> createState() => _ThemeCustomStyleDialogState();
}

class _ThemeCustomStyleDialogState extends State<ThemeCustomStyleDialog> {
  final TextEditingController _nameController = TextEditingController(text: 'CustomStyle');
  String _selectedComponent = 'button';

  static const List<String> kAvailableComponents = [
    'button',
    'card',
    'badge',
    'input',
    'switch',
    'slider',
    'checkbox',
    'tabs',
    'progress',
    'dialog',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      widget.viewModel.createCustomStyle(name, _selectedComponent);
      closeOverlay(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Custom Style'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Style Name:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              autofocus: true,
              placeholder: const Text('e.g. HeroButton, GoldCard'),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),
            const Text('Target Component:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Select<String>(
              value: _selectedComponent,
              onChanged: (v) {
                if (v != null) setState(() => _selectedComponent = v);
              },
              itemBuilder: (context, item) => Text(item[0].toUpperCase() + item.substring(1)),
              popup: SelectPopup<String>(
                items: SelectItemList(
                  children: [
                    for (final comp in kAvailableComponents)
                      SelectItemButton(
                        value: comp,
                        child: Text(comp[0].toUpperCase() + comp.substring(1)),
                      ),
                  ],
                ),
              ).call,
            ),
          ],
        ),
      ),
      actions: [
        GhostButton(
          onPressed: () => closeOverlay(context),
          child: const Text('Cancel'),
        ),
        PrimaryButton(
          onPressed: _submit,
          child: const Text('Create Style'),
        ),
      ],
    );
  }
}
