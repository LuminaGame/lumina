import 'dart:io';

import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/launcher/services/installed_template_repository.dart';

/// The pieces the launcher shows an installed game template
/// with — its screenshot, license badge and the "publisher · version" line —
/// in the Create Project dialog ([InstalledTemplateOption]) and the Templates
/// pane ([InstalledTemplateCard]).

/// The template's screenshot, or a placeholder icon when it has none.
class InstalledTemplateThumbnail extends StatelessWidget {
  const InstalledTemplateThumbnail({super.key, required this.template, required this.width, required this.height, this.radius = 4});

  final InstalledGameTemplate template;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final path = template.thumbnailPath;
    Widget placeholder() => Container(
          width: width,
          height: height,
          color: EditorColors.background,
          alignment: Alignment.center,
          child: Icon(LucideIcons.layoutTemplate, size: height * 0.4, color: EditorColors.mutedForeground),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: path == null
          ? placeholder()
          : Image.file(
              File(path),
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder(),
            ),
    );
  }
}

/// The listing's licenses (`CC-BY-4.0 + MIT`); the tooltip names them and
/// says when attribution is required.
class InstalledTemplateLicenseBadge extends StatelessWidget {
  const InstalledTemplateLicenseBadge({super.key, required this.template});

  final InstalledGameTemplate template;

  @override
  Widget build(BuildContext context) {
    final record = template.record;
    final label = template.licenseLabel.isEmpty ? 'No license record' : template.licenseLabel;
    final lines = [
      if (record == null) 'Copied in by hand: no Marketplace license record.',
      ...?record?.licenses.map((l) => '${l.kind.label}: ${l.name}'),
      if (record?.attributionRequired ?? false) 'Attribution required: credit ${template.publisher}.',
    ];
    return Tooltip(
      tooltip: (context) => TooltipContainer(child: Text(lines.join('\n')).small()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: EditorColors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: EditorColors.accent.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.accent),
        ),
      ),
    );
  }
}

/// `by <publisher> · v<version>`, leaving out what is unknown.
String installedTemplateByline(InstalledGameTemplate t) => [
      if (t.publisher.isNotEmpty) 'by ${t.publisher}',
      if (t.version.isNotEmpty) 'v${t.version}',
      if (t.engineVersion.isNotEmpty) 'Lumina ${t.engineVersion}',
    ].join(' · ');

/// A selectable installed template row in the Create Project dialog, with
/// Uninstall for Marketplace installs.
class InstalledTemplateOption extends StatelessWidget {
  const InstalledTemplateOption({
    super.key,
    required this.template,
    required this.selected,
    required this.onTap,
    required this.onUninstall,
  });

  final InstalledGameTemplate template;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onUninstall;

  @override
  Widget build(BuildContext context) {
    final t = template;
    return Padding(
      key: ValueKey('installed_template_${t.folderName}'),
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selected ? EditorColors.primary.withValues(alpha: 0.15) : EditorColors.card,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: selected ? EditorColors.primary : EditorColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InstalledTemplateThumbnail(
                key: ValueKey('installed_template_thumbnail_${t.folderName}'),
                template: t,
                width: 96,
                height: 54,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            t.title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                              color: selected ? EditorColors.primary : EditorColors.foreground,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InstalledTemplateLicenseBadge(template: t),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(installedTemplateByline(t), style: const TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
                    if (t.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        t.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
                      ),
                    ],
                  ],
                ),
              ),
              if (t.canUninstall)
                Tooltip(
                  tooltip: (context) => const TooltipContainer(child: Text('Uninstall this template')),
                  child: GhostButton(
                    key: ValueKey('installed_template_uninstall_${t.folderName}'),
                    density: ButtonDensity.icon,
                    onPressed: onUninstall,
                    child: const Icon(LucideIcons.trash2, size: 13, color: EditorColors.mutedForeground),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An installed template's card in the launcher's Templates pane.
class InstalledTemplateCard extends StatelessWidget {
  const InstalledTemplateCard({
    super.key,
    required this.template,
    required this.width,
    required this.onUse,
    required this.onUninstall,
  });

  final InstalledGameTemplate template;
  final double width;
  final VoidCallback onUse;
  final VoidCallback onUninstall;

  @override
  Widget build(BuildContext context) {
    final t = template;
    return Container(
      key: ValueKey('launcher_installed_template_${t.folderName}'),
      width: width,
      decoration: BoxDecoration(
        color: EditorColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: EditorColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InstalledTemplateThumbnail(template: t, width: width, height: width * 9 / 16, radius: 8),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                    InstalledTemplateLicenseBadge(template: t),
                  ],
                ),
                const SizedBox(height: 4),
                Text(installedTemplateByline(t), style: const TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
                const SizedBox(height: 6),
                Text(
                  t.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        density: ButtonDensity.compact,
                        onPressed: onUse,
                        child: const Text('Use Template', style: TextStyle(fontSize: 10)),
                      ),
                    ),
                    if (t.canUninstall) ...[
                      const SizedBox(width: 6),
                      OutlineButton(
                        key: ValueKey('launcher_installed_template_uninstall_${t.folderName}'),
                        density: ButtonDensity.compact,
                        onPressed: onUninstall,
                        child: const Text('Uninstall', style: TextStyle(fontSize: 10)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
