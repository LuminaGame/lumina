import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../core/theme/editor_theme.dart';
import '../view_models/launcher_view_model.dart';
import 'installed_template_widgets.dart';

/// The launcher's Templates pane: the built-in templates
/// (`GameTemplateCatalog`) and, below them, the game templates installed
/// from the Marketplace. "Use Template" opens the Create
/// Project dialog with that template selected.
class LauncherTemplatesPane extends StatelessWidget {
  const LauncherTemplatesPane({super.key, required this.viewModel, required this.onUseTemplate});

  final LauncherViewModel viewModel;

  /// Opens the Create Project dialog on the template with this id.
  final void Function(String templateId) onUseTemplate;

  static const double _spacing = 16;

  @override
  Widget build(BuildContext context) {
    final installed = viewModel.installedTemplates;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = ((constraints.maxWidth - 48 - 2 * _spacing) / 3).clamp(160.0, 420.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Project Templates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text(
                'Choose a starting starter template with pre-configured actors, sky lighting, and player pawns.',
                style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: _spacing,
                runSpacing: _spacing,
                children: [
                  for (final tpl in viewModel.templates)
                    SizedBox(width: cardWidth, height: (cardWidth / 1.2).clamp(170.0, 210.0), child: _BuiltInTemplateCard(template: tpl, onUse: () => onUseTemplate(tpl.id))),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  const Icon(LucideIcons.store, size: 15, color: EditorColors.primary),
                  const SizedBox(width: 8),
                  const Text('Marketplace Templates', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('${installed.length}', style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                installed.isEmpty
                    ? 'Game templates you add from Window → Marketplace in the editor appear here.'
                    : 'Installed from the Lumina Marketplace. Each keeps its license notice in the projects you create from it.',
                style: const TextStyle(fontSize: 11, color: EditorColors.mutedForeground),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: _spacing,
                runSpacing: _spacing,
                children: [
                  for (final t in installed)
                    InstalledTemplateCard(
                      template: t,
                      width: cardWidth,
                      onUse: () => onUseTemplate(t.id),
                      onUninstall: () => viewModel.uninstallTemplate(t),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BuiltInTemplateCard extends StatelessWidget {
  const _BuiltInTemplateCard({required this.template, required this.onUse});

  final LauncherTemplate template;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EditorColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: EditorColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: EditorColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(template.icon, size: 20, color: EditorColors.primary),
          ),
          const SizedBox(height: 12),
          Text(template.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              template.description,
              style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
            ),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            density: ButtonDensity.compact,
            onPressed: onUse,
            child: const Text('Use Template', style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }
}
