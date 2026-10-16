part of '../component_tree.dart';

/// The Add Component dialog: the registered component types, searchable;
/// types the engine cannot build yet are shown locked with the reason.
class _AddComponentDialog extends StatefulWidget {
  final BlueprintEditorViewModel viewModel;
  final VoidCallback onClose;

  const _AddComponentDialog({required this.viewModel, required this.onClose});

  @override
  State<_AddComponentDialog> createState() => _AddComponentDialogState();
}

class _AddComponentDialogState extends State<_AddComponentDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = BlueprintComponentRegistry.registeredComponents
        .where((d) => d.displayName.toLowerCase().contains(_filter.toLowerCase()) || d.typeName.toLowerCase().contains(_filter.toLowerCase()))
        .toList();

    return AlertDialog(
      title: const Text('Add Component'),
      content: SizedBox(
        width: 320,
        height: 360,
        child: Column(
          children: [
            TextField(
              key: const ValueKey('add_component_search'),
              controller: _searchController,
              placeholder: const Text('Search Components...').small(),
              onChanged: (val) => setState(() => _filter = val),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final comp = filtered[index];
                  if (!comp.isAvailable) {
                    return Tooltip(
                      tooltip: (context) => TooltipContainer(child: Text(comp.gapReason ?? 'Not supported in engine yet').small()),
                      child: Opacity(
                        opacity: 0.45,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.lock, size: 12, color: EditorColors.mutedForeground),
                              const SizedBox(width: 8),
                              Text(comp.displayName, style: const TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return Clickable(
                    key: ValueKey('add_component_${comp.typeName}'),
                    onPressed: () {
                      widget.viewModel.addComponent(comp.typeName);
                      widget.onClose();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            comp.icon ?? (comp.isSceneComponent ? LucideIcons.box : LucideIcons.cpu),
                            size: 13,
                            color: EditorColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              comp.displayName,
                              style: const TextStyle(fontSize: 11, color: EditorColors.foreground),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        GhostButton(
          onPressed: widget.onClose,
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
