import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/data/services/game_template_service.dart';
import 'package:lumina/data/models/lumina_project.dart' show kUmgWidgetLibraryFlutter, kUmgWidgetLibraryShadcn;
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/editor_theme.dart';
import '../view_models/create_project_view_model.dart';
import 'installed_template_widgets.dart';

class CreateProjectDialog extends StatefulWidget {
  final CreateProjectViewModel viewModel;
  final VoidCallback onSuccess;

  const CreateProjectDialog({super.key, required this.viewModel, required this.onSuccess});

  @override
  State<CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<CreateProjectDialog> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onViewModelChange);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onViewModelChange);
    super.dispose();
  }

  void _onViewModelChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;

    return AlertDialog(
      title: Row(
        children: [
          Image.asset('assets/logo_color.png', height: 24),
          const SizedBox(width: 8),
          const Text('Create New Project'),
        ],
      ),
      content: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (vm.isCreating)
              _buildProgress(context, vm)
            else if (vm.creationError != null)
              _buildError(context, vm)
            else
              // Scrolls when the window is short: templates + library choice.
              Flexible(child: SingleChildScrollView(child: _buildForm(context, vm))),
          ],
        ),
      ),
      actions: [
        if (!vm.isCreating) ...[
          OutlineButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            onPressed: vm.validationError == null
                ? () async {
                    await vm.createProject();
                    if (vm.creationError == null && context.mounted) {
                      Navigator.of(context).pop();
                      widget.onSuccess();
                    }
                  }
                : null,
            child: Text(vm.creationError != null ? 'Retry' : 'Create Project'),
          ),
        ],
      ],
    );
  }

  Widget _buildForm(BuildContext context, CreateProjectViewModel vm) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Project Name').muted(),
        const SizedBox(height: 4),
        TextField(initialValue: vm.name, onChanged: vm.updateName, placeholder: const Text('my_lumina_game')),
        if (vm.validationError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(vm.validationError!, style: TextStyle(color: Theme.of(context).colorScheme.destructive)),
          ),
        const SizedBox(height: 16),
        const Text('Location').muted(),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(initialValue: vm.location, onChanged: vm.updateLocation),
            ),
            const SizedBox(width: 8),
            OutlineButton(
              onPressed: () async {
                final result = await FilePicker.platform.getDirectoryPath();
                if (result != null) {
                  vm.updateLocation(result);
                }
              },
              child: const Text('Browse...'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Template').muted(),
        const SizedBox(height: 4),
        // One row per template, straight from the shared catalog: what the
        // chip says is what the scaffolder writes.
        for (final template in GameTemplateCatalog.all) _buildTemplateOption(context, vm, template),
        // Game templates installed from the Marketplace.
        if (vm.installedTemplates.isNotEmpty) ...[
          const SizedBox(height: 6),
          const Row(
            key: ValueKey('create_project_marketplace_group'),
            children: [
              Icon(LucideIcons.store, size: 12, color: EditorColors.mutedForeground),
              SizedBox(width: 6),
              Text('Marketplace', style: TextStyle(fontSize: 12, color: EditorColors.mutedForeground)),
            ],
          ),
          const SizedBox(height: 4),
          for (final installed in vm.installedTemplates)
            InstalledTemplateOption(
              template: installed,
              selected: vm.template == installed.id,
              onTap: () => vm.updateTemplate(installed.id),
              onUninstall: () => vm.uninstallTemplate(installed),
            ),
        ],
        const SizedBox(height: 10),
        if (vm.selectedInstalledTemplate != null)
          const Text(
            "The project uses the template's own UI widget library and code.",
            style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
          )
        else
          ..._buildWidgetLibraryChoice(context, vm),
      ],
    );
  }

  List<Widget> _buildWidgetLibraryChoice(BuildContext context, CreateProjectViewModel vm) {
    return [
      const Text('UI Widget Library').muted(),
      const SizedBox(height: 4),
      // What generated UMG widgets are built from.
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildChoice(
              context,
              key: const ValueKey('create_project_widget_library_shadcn'),
              title: 'shadcn_flutter',
              description: 'Widgets look like the editor. Adds the shadcn_flutter dependency to the game.',
              selected: vm.widgetLibrary == kUmgWidgetLibraryShadcn,
              onTap: () => vm.updateWidgetLibrary(kUmgWidgetLibraryShadcn),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildChoice(
              context,
              key: const ValueKey('create_project_widget_library_flutter'),
              title: 'Plain Flutter widgets',
              description: "No extra dependency; uses the engine's own LuminaUmg widgets. Smaller web builds.",
              selected: vm.widgetLibrary == kUmgWidgetLibraryFlutter,
              onTap: () => vm.updateWidgetLibrary(kUmgWidgetLibraryFlutter),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildTemplateOption(BuildContext context, CreateProjectViewModel vm, GameTemplate template) => _buildChoice(
    context,
    title: template.title,
    description: template.description,
    selected: vm.template == template.id,
    onTap: () => vm.updateTemplate(template.id),
  );

  Widget _buildChoice(
    BuildContext context, {
    Key? key,
    required String title,
    required String description,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isSelected = selected;
    final theme = Theme.of(context);
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.15) : theme.colorScheme.card,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: isSelected ? theme.colorScheme.primary : theme.colorScheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.foreground,
                ),
              ),
              const SizedBox(height: 2),
              Text(description, style: TextStyle(fontSize: 10, color: theme.colorScheme.mutedForeground)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgress(BuildContext context, CreateProjectViewModel vm) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(vm.progressLabel),
        const SizedBox(height: 12),
        Progress(progress: vm.progress, min: 0.0, max: 1.0),
        const SizedBox(height: 16),
        Container(
          height: 150,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.muted, borderRadius: BorderRadius.circular(4)),
          child: ListView.builder(
            itemCount: vm.processOutput.length,
            itemBuilder: (context, index) => Text(vm.processOutput[index]).muted(),
          ),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, CreateProjectViewModel vm) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Creation Failed', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('${vm.creationError}\n\nRollback complete — nothing left on disk.'),
      ],
    );
  }
}
