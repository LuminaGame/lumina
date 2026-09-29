import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/features/plugin_manager/view_models/plugin_manager_view_model.dart';
import 'package:lumina/data/services/plugin_registry_service.dart';
import 'package:lumina/data/models/lumina_plugin_descriptor.dart';
import 'package:lumina/data/repositories/plugin_repository.dart';
import 'package:lumina_ui/ui/features/plugin_manager/views/new_plugin_wizard.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import '../../../core/theme/editor_theme.dart';

class PluginManagerView extends StatelessWidget {
  final PluginManagerViewModel viewModel;

  const PluginManagerView({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return ResizablePanel.horizontal(
          children: [
            ResizablePane(
              initialSize: 220,
              minSize: 180,
              child: _CategorySidebar(viewModel: viewModel),
            ),
            ResizablePane(
              initialSize: 460,
              minSize: 340,
              child: _PluginCardList(viewModel: viewModel),
            ),
            ResizablePane(
              initialSize: 400,
              minSize: 320,
              child: _PluginDetailsPane(viewModel: viewModel),
            ),
          ],
        );
      },
    );
  }
}

class _CategorySidebar extends StatelessWidget {
  final PluginManagerViewModel viewModel;
  const _CategorySidebar({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final categories = vm.categoryCounts;
    
    final sortedCategories = categories.keys.toList()..sort();
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.background,
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          _CategoryRow(
            title: 'ALL PLUGINS',
            count: vm.totalCount,
            isSelected: vm.selectedGroup == 'ALL' && vm.selectedCategory == 'ALL PLUGINS',
            onTap: () => vm.selectCategory('ALL', 'ALL PLUGINS'),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            child: Text('INSTALLED', style: TextStyle(color: theme.colorScheme.mutedForeground, fontWeight: FontWeight.bold)),
          ),
          _CategoryRow(
            title: 'All Installed',
            count: vm.installedCount,
            isSelected: vm.selectedGroup == 'INSTALLED' && vm.selectedCategory == 'ALL PLUGINS',
            onTap: () => vm.selectCategory('INSTALLED', 'ALL PLUGINS'),
          ),
          ...sortedCategories.map((c) {
            final count = vm.registryService.entries.where((e) => e.descriptor.category == c && e.descriptor.origin != PluginOrigin.engine).length;
            if (count == 0) return const SizedBox.shrink();
            return _CategoryRow(
              title: c,
              count: count,
              isSelected: vm.selectedGroup == 'INSTALLED' && vm.selectedCategory == c,
              onTap: () => vm.selectCategory('INSTALLED', c),
            );
          }),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            child: Text('BUILT-IN', style: TextStyle(color: theme.colorScheme.mutedForeground, fontWeight: FontWeight.bold)),
          ),
          _CategoryRow(
            title: 'All Built-in',
            count: vm.builtInCount,
            isSelected: vm.selectedGroup == 'BUILT-IN' && vm.selectedCategory == 'ALL PLUGINS',
            onTap: () => vm.selectCategory('BUILT-IN', 'ALL PLUGINS'),
          ),
          ...sortedCategories.map((c) {
            final count = vm.registryService.entries.where((e) => e.descriptor.category == c && e.descriptor.origin == PluginOrigin.engine).length;
            if (count == 0) return const SizedBox.shrink();
            return _CategoryRow(
              title: c,
              count: count,
              isSelected: vm.selectedGroup == 'BUILT-IN' && vm.selectedCategory == c,
              onTap: () => vm.selectCategory('BUILT-IN', c),
            );
          }),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String title;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryRow({
    required this.title,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Clickable(
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            SecondaryBadge(child: Text('$count')),
          ],
        ),
      ),
    );
  }
}

class _PluginCardList extends StatelessWidget {
  final PluginManagerViewModel viewModel; const _PluginCardList({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final entries = vm.entries;
    final total = vm.totalCount;
    final enabled = vm.enabledCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  placeholder: const Text('Search plugins...'),
                  initialValue: vm.searchQuery,
                  onChanged: (v) => vm.searchQuery = v,
                ),
              ),
              const SizedBox(width: 8),
              Text('$total plugins · $enabled enabled').muted(),
              const SizedBox(width: 8),
              PrimaryButton(
                child: const Text('New Plugin'),
                onPressed: () {
                  showNewPluginWizard(context, viewModel: vm);
                },
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: entries.length + (vm.scanErrors.isNotEmpty ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < entries.length) {
                return _PluginCard(entry: entries[index], viewModel: viewModel);
              } else {
                return _ScanErrorsSection(errors: vm.scanErrors);
              }
            },
          ),
        ),
      ],
    );
  }
}

class _PluginCard extends StatelessWidget {
  final PluginEntry entry;
  final PluginManagerViewModel viewModel;

  const _PluginCard({required this.entry, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final desc = entry.descriptor;
    
    final hasIssues = entry.issues.isNotEmpty;

    return Clickable(
      onPressed: () => vm.selectedEntry = entry,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PluginIcon(iconFile: desc.iconFile, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(desc.friendlyName ?? desc.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Text(desc.version.toString()).muted(),
                        const SizedBox(width: 8),
                        SecondaryBadge(child: Text(desc.origin.name.toUpperCase())),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (desc.category != 'Other')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(desc.category, style: const TextStyle(fontSize: 11)).muted(),
                      ),
                    if (desc.description != null && desc.description!.isNotEmpty)
                      Text(desc.description!, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Column(
                children: [
                  Row(
                    children: [
                      if (entry.restartPending)
                        const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: OutlineBadge(child: Text('Restart required')),
                        ),
                      Switch(
                        value: entry.enabled,
                        onChanged: (v) async {
                          if (desc.origin == PluginOrigin.engine) {
                            showOverlay(
                              context,
                              const DialogConfiguration(),
                              builder: (c) => AlertDialog(
                                title: const Text('Built-in Plugin'),
                                content: const Text('Built-in plugins cannot be modified in project settings.'),
                                actions: [
                                  PrimaryButton(
                                    child: const Text('OK'),
                                    onPressed: () => closeOverlay(c),
                                  )
                                ],
                              ),
                            );
                            return;
                          }
                          if (!v) {
                            final res = await vm.setEnabled(desc.name, v);
                            if (res.issues.isNotEmpty && context.mounted) {
                              if (res.issues.first.type == PluginIssueType.requiredBy) {
                                showOverlay(
                                  context,
                                  const DialogConfiguration(),
                                  builder: (c) => AlertDialog(
                                    title: const Text('Confirm Disable'),
                                    content: Text('${res.issues.first.message}. Disable all?'),
                                    actions: [
                                      GhostButton(child: const Text('Cancel'), onPressed: () => closeOverlay(c)),
                                      DestructiveButton(
                                        child: const Text('Disable all'),
                                        onPressed: () {
                                          closeOverlay(c);
                                          vm.setEnabled(desc.name, v, cascade: true);
                                        },
                                      )
                                    ],
                                  ),
                                );
                              }
                            }
                          } else {
                            await vm.setEnabled(desc.name, v);
                          }
                        },
                      ),
                    ],
                  ),
                  if (hasIssues)
                    Tooltip(
                      tooltip: (context) => TooltipContainer(child: Text(entry.issues.map((e) => e.message).join('\n'))),
                      child: const DestructiveBadge(
                        child: Text('Issue'),
                      ),
                    ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanErrorsSection extends StatelessWidget {
  final List<PluginScanError> errors;

  const _ScanErrorsSection({required this.errors});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text('Errors (${errors.length})', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.destructive)),
        ),
        ...errors.map((e) => Card(
          child: Container(
            color: theme.colorScheme.destructive.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(8),
            child: Text('${e.filePath}\n${e.message}', style: TextStyle(color: theme.colorScheme.destructive)),
          ),
        )),
      ],
    );
  }
}

class _PluginDetailsPane extends StatelessWidget {
  final PluginManagerViewModel viewModel;
  const _PluginDetailsPane({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final entry = vm.selectedEntry;

    if (entry == null) {
      return Center(child: Text('Select a plugin').muted());
    }

    final desc = entry.descriptor;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PluginIcon(iconFile: desc.iconFile, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    desc.friendlyName ?? desc.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        desc.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.mutedForeground,
                          fontFamily: EditorTypography.monoFamily,
                        ),
                      ),
                      const SizedBox(width: 6),
                      OutlineBadge(
                        child: Text(
                          'v${desc.version}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      SecondaryBadge(
                        child: Text(desc.category, style: const TextStyle(fontSize: 10)),
                      ),
                      OutlineBadge(
                        child: Text(desc.origin.name.toUpperCase(), style: const TextStyle(fontSize: 10)),
                      ),
                      if (desc.canContainContent)
                        const OutlineBadge(
                          child: Text('CONTENT', style: TextStyle(fontSize: 10)),
                        ),
                    ],
                  ),
                  if (desc.authors.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'By ${desc.authors.join(', ')}',
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.mutedForeground),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.muted.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.colorScheme.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  desc.pluginDir.path,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: EditorTypography.monoFamily,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GhostButton(
                density: ButtonDensity.compact,
                child: const Icon(LucideIcons.copy, size: 14),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: desc.pluginDir.path));
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (desc.description != null && desc.description!.isNotEmpty) ...[
          Text(
            desc.description!,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
        ],
        if (desc.engineVersion != null) ...[
          Row(
            children: [
              Text(
                'Engine Version: ',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.mutedForeground),
              ),
              SecondaryBadge(
                child: Text(desc.engineVersion.toString(), style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        const Divider(),
        const SizedBox(height: 8),
        Text('Dependencies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.foreground)),
        const SizedBox(height: 6),
        if (desc.dependencies.isEmpty)
          Text('No dependencies', style: TextStyle(fontSize: 12, color: theme.colorScheme.mutedForeground))
        else
          ...desc.dependencies.map((d) {
            final isOk = vm.registryService.entries.any((e) => e.descriptor.name == d.name && e.enabled);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${d.name} ${d.version}', style: const TextStyle(fontSize: 12)),
                  isOk
                      ? const OutlineBadge(child: Text('OK', style: TextStyle(fontSize: 10, color: Colors.green)))
                      : const DestructiveBadge(child: Text('Missing', style: TextStyle(fontSize: 10))),
                ],
              ),
            );
          }),
        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 8),
        Text('Modules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.foreground)),
        const SizedBox(height: 6),
        if (desc.isContentOnly)
          Text('Content only — takes effect without restart', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: theme.colorScheme.mutedForeground))
        else
          ...desc.modules.map((m) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.muted.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(width: 6),
                          OutlineBadge(child: Text(m.type.name, style: const TextStyle(fontSize: 9))),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${m.entryLibrary} → ${m.registrationClass}',
                        style: TextStyle(
                          fontFamily: EditorTypography.monoFamily,
                          fontSize: 10,
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }
}

class _PluginIcon extends StatelessWidget {
  final File? iconFile;
  final double size;

  const _PluginIcon({this.iconFile, this.size = 40});

  @override
  Widget build(BuildContext context) {
    if (iconFile != null && iconFile!.existsSync()) {
      return Image.memory(
        iconFile!.readAsBytesSync(),
        width: size,
        height: size,
        errorBuilder: (c, e, s) => _defaultIcon(context),
      );
    }
    return _defaultIcon(context);
  }

  Widget _defaultIcon(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: Theme.of(context).colorScheme.muted,
      child: const Icon(LucideIcons.puzzle),
    );
  }
}
