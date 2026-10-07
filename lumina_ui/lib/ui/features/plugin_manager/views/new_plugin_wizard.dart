import 'dart:convert';
import 'dart:io';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/data/services/plugin_template_generator_service.dart';
import 'package:lumina_ui/ui/features/plugin_manager/view_models/plugin_manager_view_model.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Shows the New Plugin Wizard modal dialog.
void showNewPluginWizard(
  BuildContext context, {
  required PluginManagerViewModel viewModel,
  PluginTemplateGeneratorService? generatorService,
  String? configFilePath,
  Directory? projectRoot,
  Directory? editorApiRoot,
}) {
  showOverlay(
    context,
    const DialogConfiguration(),
    builder: (dialogContext) {
      return NewPluginWizardDialog(
        rootContext: context,
        viewModel: viewModel,
        generatorService: generatorService,
        configFilePath: configFilePath,
        projectRoot: projectRoot,
        editorApiRoot: editorApiRoot,
        onClose: () => closeOverlay(dialogContext),
      );
    },
  );
}

class NewPluginWizardDialog extends StatefulWidget {
  final BuildContext rootContext;
  final PluginManagerViewModel viewModel;
  final PluginTemplateGeneratorService? generatorService;
  final String? configFilePath;
  final Directory? projectRoot;
  final Directory? editorApiRoot;
  final VoidCallback onClose;

  const NewPluginWizardDialog({
    super.key,
    required this.rootContext,
    required this.viewModel,
    this.generatorService,
    this.configFilePath,
    this.projectRoot,
    this.editorApiRoot,
    required this.onClose,
  });

  @override
  State<NewPluginWizardDialog> createState() => _NewPluginWizardDialogState();
}

class _NewPluginWizardDialogState extends State<NewPluginWizardDialog> {
  PluginTemplateType _selectedTemplate = PluginTemplateType.blank;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _friendlyNameController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _category = 'Utilities';

  /// "Run in its own process": the plugin is scaffolded isolated (a
  /// process part plus a UI shell; not for content-only plugins).
  bool _isolated = false;

  bool _isUserFriendlyName = false;
  String? _nameError;
  bool _isGenerating = false;
  final List<String> _logs = [];
  String? _generationError;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _nameError = PluginTemplateGeneratorService.validatePluginName(
      _nameController.text,
      existingPluginNames: _getExistingPluginNames(),
      scanRoots: _getScanRoots(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _friendlyNameController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  File _getConfigFile() {
    if (widget.configFilePath != null) {
      return File(widget.configFilePath!);
    }
    return LuminaConfigDir.file('plugin_wizard.json');
  }

  void _loadConfig() {
    try {
      final file = _getConfigFile();
      if (file.existsSync()) {
        final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        if (json.containsKey('author') && (json['author'] as String).isNotEmpty) {
          _authorController.text = json['author'] as String;
        }
      } else {
        final user = Platform.environment['USER'] ?? Platform.environment['USERNAME'] ?? '';
        if (user.isNotEmpty) {
          _authorController.text = user;
        }
      }
    } catch (_) {}
  }

  void _saveConfig() {
    try {
      ConfigJsonFile(_getConfigFile()).write({'author': _authorController.text});
    } catch (_) {}
  }

  List<String> _getExistingPluginNames() {
    return widget.viewModel.registryService.entries
        .map((e) => e.descriptor.name)
        .toList();
  }

  List<Directory> _getScanRoots() {
    return widget.viewModel.registryService.repo.roots.map((r) => r.dir).toList();
  }

  void _onNameChanged(String value) {
    setState(() {
      _nameError = PluginTemplateGeneratorService.validatePluginName(
        value,
        existingPluginNames: _getExistingPluginNames(),
        scanRoots: _getScanRoots(),
      );
      if (!_isUserFriendlyName) {
        _friendlyNameController.text = PluginTemplateGeneratorService.nameToFriendly(value);
      }
    });
  }

  String _getProjectPath() {
    if (widget.projectRoot != null) {
      return widget.projectRoot!.path;
    }
    final roots = widget.viewModel.registryService.repo.roots
        .where((r) => r.origin == PluginOrigin.project);
    if (roots.isNotEmpty) {
      return roots.first.dir.parent.path;
    }
    return Directory.current.path;
  }

  Future<void> _createPlugin() async {
    if (_nameError != null || _nameController.text.trim().isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isGenerating = true;
      _generationError = null;
      _logs.clear();
    });

    final name = _nameController.text.trim();
    final friendlyName = _friendlyNameController.text.trim().isEmpty
        ? PluginTemplateGeneratorService.nameToFriendly(name)
        : _friendlyNameController.text.trim();

    final spec = PluginTemplateSpec(
      templateType: _selectedTemplate,
      name: name,
      friendlyName: friendlyName,
      author: _authorController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _category,
      isolated: _isolated && _selectedTemplate != PluginTemplateType.contentOnly,
    );

    // The generation lives in the view model, which the MCP
    // server's create_plugin calls too.
    PluginGenerationResult result;
    try {
      result = await widget.viewModel.createPlugin(
        spec,
        projectRoot: widget.projectRoot ?? Directory(_getProjectPath()),
        editorApiRoot: widget.editorApiRoot,
        generator: widget.generatorService,
        onLog: (msg) {
          if (mounted) {
            setState(() => _logs.add(msg));
          }
        },
      );
    } on StateError catch (e) {
      result = PluginGenerationResult.failure(failureOutput: e.message);
    }

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _isGenerating = false;
        _generationError = result.failureOutput ?? 'Plugin generation failed.';
      });
      return;
    }

    final rootContext = widget.rootContext;
    setState(() {
      _isGenerating = false;
    });
    _saveConfig();
    widget.onClose();

    // Show Enable confirmation overlay
    if (rootContext.mounted) {
      _showEnableDialog(rootContext, name: name, friendlyName: friendlyName);
    }
  }

  void _showEnableDialog(BuildContext context, {required String name, required String friendlyName}) {
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (c) => AlertDialog(
        title: const Text('Plugin Created'),
        content: Text(
            'Successfully created plugin "$friendlyName". Would you like to enable it now?'),
        actions: [
          GhostButton(
            child: const Text('Later'),
            onPressed: () => closeOverlay(c),
          ),
          PrimaryButton(
            child: const Text('Enable now'),
            onPressed: () async {
              closeOverlay(c);
              await widget.viewModel.setEnabled(name, true);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isValid = _nameError == null && _nameController.text.trim().isNotEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 780,
          maxHeight: 560,
        ),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('New Plugin Wizard').h2(),
                        const SizedBox(height: 2),
                        const Text('Create a new compiling Dart plugin package from a template.').muted(),
                      ],
                    ),
                    GhostButton(
                      onPressed: widget.onClose,
                      child: const Icon(LucideIcons.x, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                // Two-pane body
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Template list
                      SizedBox(
                        width: 250,
                        child: ListView(
                          children: [
                            const Text('TEMPLATES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)).muted(),
                            const SizedBox(height: 8),
                            _TemplateTile(
                              title: 'Blank editor plugin',
                              description: 'Editor module with one menu item',
                              icon: LucideIcons.puzzle,
                              isSelected: _selectedTemplate == PluginTemplateType.blank,
                              onTap: () => setState(() => _selectedTemplate = PluginTemplateType.blank),
                            ),
                            const SizedBox(height: 8),
                            _TemplateTile(
                              title: 'Content-only',
                              description: 'Assets only — no code, no restart',
                              icon: LucideIcons.folderArchive,
                              isSelected: _selectedTemplate == PluginTemplateType.contentOnly,
                              onTap: () => setState(() => _selectedTemplate = PluginTemplateType.contentOnly),
                            ),
                            const SizedBox(height: 8),
                            _TemplateTile(
                              title: 'Editor panel',
                              description: 'Adds a dockable panel with stateful widget',
                              icon: LucideIcons.layoutGrid,
                              isSelected: _selectedTemplate == PluginTemplateType.editorPanel,
                              onTap: () => setState(() => _selectedTemplate = PluginTemplateType.editorPanel),
                            ),
                            const SizedBox(height: 8),
                            _TemplateTile(
                              title: 'Importer',
                              description: 'Adds a file importer writing real .lmas assets',
                              icon: LucideIcons.fileInput,
                              isSelected: _selectedTemplate == PluginTemplateType.importer,
                              onTap: () => setState(() => _selectedTemplate = PluginTemplateType.importer),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      const VerticalDivider(),
                      const SizedBox(width: 16),

                      // Right: Form
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Template summary / file preview
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.muted.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(_getTemplateSummary(_selectedTemplate)).muted(),
                              ),
                              const SizedBox(height: 14),

                              // Plugin Name
                              const Text('Plugin Name (package)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 4),
                              TextField(
                                key: const Key('plugin_name_field'),
                                controller: _nameController,
                                placeholder: const Text('e.g. water_system'),
                                onChanged: _onNameChanged,
                              ),
                              if (_nameError != null && _nameController.text.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(_nameError!, style: TextStyle(color: theme.colorScheme.destructive, fontSize: 12)),
                                ),
                              const SizedBox(height: 12),

                              // Friendly Name
                              const Text('Friendly Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 4),
                              TextField(
                                key: const Key('friendly_name_field'),
                                controller: _friendlyNameController,
                                placeholder: const Text('e.g. Water System'),
                                onChanged: (v) {
                                  _isUserFriendlyName = true;
                                },
                              ),
                              const SizedBox(height: 12),

                              // Author & Category Row
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Author', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        const SizedBox(height: 4),
                                        TextField(
                                          key: const Key('author_field'),
                                          controller: _authorController,
                                          placeholder: const Text('Author / Organization'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        const SizedBox(height: 4),
                                        _buildCategorySelect(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Description
                              const Text('Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 4),
                              TextField(
                                key: const Key('description_field'),
                                controller: _descriptionController,
                                placeholder: const Text('Describe the tools and features provided by this plugin...'),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 12),

                              // Isolation
                              if (_selectedTemplate != PluginTemplateType.contentOnly) ...[
                                Row(
                                  children: [
                                    Switch(
                                      key: const Key('plugin_isolated_switch'),
                                      value: _isolated,
                                      onChanged: (v) => setState(() => _isolated = v),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Run in its own process', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                          Text(
                                            'Native libraries, child processes and heavy work go in a process part the editor '
                                            'supervises: a crash or hang there never takes the editor down.',
                                            style: TextStyle(fontSize: 11, color: theme.colorScheme.mutedForeground),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Path preview
                              Text(
                                'Location: ${_getProjectPath()}/plugins/${_nameController.text.trim().isEmpty ? '<name>' : _nameController.text.trim()}/',
                                style: const TextStyle(fontFamily: EditorTypography.monoFamily, fontSize: 11),
                              ).muted(),

                              // Generation error display
                              if (_generationError != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.destructive.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(_generationError!, style: TextStyle(color: theme.colorScheme.destructive, fontSize: 12)),
                                ),
                              ],

                              // Logs display during generation
                              if (_isGenerating && _logs.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  height: 80,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.muted.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: ListView.builder(
                                    itemCount: _logs.length,
                                    itemBuilder: (c, i) => Text(_logs[i], style: const TextStyle(fontSize: 11, fontFamily: EditorTypography.monoFamily)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),

                // Footer Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GhostButton(
                      onPressed: _isGenerating ? null : widget.onClose,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    PrimaryButton(
                      onPressed: (isValid && !_isGenerating) ? _createPlugin : null,
                      child: _isGenerating
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text('Creating Plugin...'),
                              ],
                            )
                          : const Text('Create Plugin'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelect() {
    final categories = <String>{
      'Utilities',
      'Physics',
      'Rendering',
      'Pipeline',
      'Content',
      'Profiling',
      'Other',
      ...widget.viewModel.registryService.entries.map((e) => e.descriptor.category),
    }.toList()
      ..sort();

    return Select<String>(
      value: _category,
      onChanged: (val) {
        if (val != null) setState(() => _category = val);
      },
      itemBuilder: (context, val) => Text(val),
      popup: SelectPopup(
        items: SelectItemList(
          children: categories.map<Widget>((c) => SelectItemButton(value: c, child: Text(c))).toList(),
        ),
      ).call,
    );
  }

  String _getTemplateSummary(PluginTemplateType type) {
    switch (type) {
      case PluginTemplateType.blank:
        return 'Generates: <name>.lmplugin, pubspec.yaml, lib/<name>.dart, lib/src/<name>_plugin.dart (Tools menu item), resources/icon128.png, README.md, test.';
      case PluginTemplateType.contentOnly:
        return 'Generates: <name>.lmplugin, content/materials/, content/meshes/, content/textures/, resources/icon128.png, README.md (No Dart code, no editor restart).';
      case PluginTemplateType.editorPanel:
        return 'Generates: <name>.lmplugin, pubspec.yaml, lib/src/<name>_plugin.dart with dockable Card panel widget containing an interactive counter button.';
      case PluginTemplateType.importer:
        return 'Generates: <name>.lmplugin, pubspec.yaml, lib/src/<name>_plugin.dart with a working .txt file importer writing binary LuminaAsset (.lmas) files.';
    }
  }
}

class _TemplateTile extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TemplateTile({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Clickable(
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.colorScheme.card,
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.border,
            width: isSelected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.foreground,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 13,
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(description, style: const TextStyle(fontSize: 11)).muted(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
