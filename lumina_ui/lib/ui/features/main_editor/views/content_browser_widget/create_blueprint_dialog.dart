part of '../content_browser_widget.dart';

/// The Pick Parent Class dialog for a new Blueprint.
mixin _ContentBrowserCreateBlueprintDialog on _ContentBrowserWidgetStateBase {

  @override
  void _showCreateBlueprintDialog(BuildContext context, EditorViewModel? vm) {
    final nameController = TextEditingController(text: 'BP_NewBlueprint');
    String parentClass = 'LuminaActor';
    String searchQuery = '';
    String selectedCategory = 'All';

    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            final projectBlueprints = vm?.realAssets
                    .where((a) => a.type == AssetType.actor && a.fileName.endsWith('.lmas'))
                    .map((a) {
                      final name = a.fileName.replaceAll('.lmas', '');
                      return _LuminaClassInfo(
                        className: name,
                        category: 'Project Blueprints',
                        description: 'Project Blueprint: ${a.relativePath}',
                        icon: LucideIcons.fileCode,
                      );
                    }).toList() ??
                const <_LuminaClassInfo>[];

            final allClasses = [..._allLuminaClasses, ...projectBlueprints];

            final filteredClasses = allClasses.where((c) {
              final matchesCategory =
                  selectedCategory == 'All' || c.category == selectedCategory;
              final matchesSearch =
                  searchQuery.isEmpty ||
                  c.className.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  ) ||
                  c.description.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  );
              return matchesCategory && matchesSearch;
            }).toList();

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(
                    LucideIcons.gitBranch,
                    size: 16,
                    color: EditorColors.primary,
                  ),
                  SizedBox(width: 8),
                  Text('Create Blueprint Class'),
                ],
              ),
              content: SizedBox(
                width: 540,
                height: 460,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Blueprint Name:',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: EditorColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: EditorColors.background,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: EditorColors.border),
                      ),
                      child: TextField(
                        controller: nameController,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: EditorColors.primary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    const Text(
                      'Select Parent Class:',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: EditorColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Category Tabs & Search Row
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children:
                                  [
                                    'All',
                                    'Project Blueprints',
                                    'Actors & Framework',
                                    'Components',
                                    'World & Subsystems',
                                    'UI & User Interface',
                                  ].map((cat) {
                                    final active = selectedCategory == cat;
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        right: 4,
                                      ),
                                      child: Button(
                                        style: active
                                            ? const ButtonStyle.primary()
                                            : const ButtonStyle.ghost(),
                                        onPressed: () => setStateModal(
                                          () => selectedCategory = cat,
                                        ),
                                        child: Text(
                                          cat,
                                          style: const TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 110,
                          height: 22,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: EditorColors.background,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: EditorColors.border),
                          ),
                          child: TextField(
                            onChanged: (val) =>
                                setStateModal(() => searchQuery = val),
                            style: const TextStyle(
                              fontSize: 9,
                              color: EditorColors.foreground,
                            ),
                            placeholder: const Text(
                              'Search classes...',
                              style: TextStyle(fontSize: 8),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Class List View
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: EditorColors.background,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: EditorColors.border),
                        ),
                        child: filteredClasses.isEmpty
                            ? const Center(
                                child: Text(
                                  'No classes found matching search',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: EditorColors.mutedForeground,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(6),
                                itemCount: filteredClasses.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 4),
                                itemBuilder: (context, index) {
                                  final cls = filteredClasses[index];
                                  final active = parentClass == cls.className;
                                  return GestureDetector(
                                    onTap: () => setStateModal(
                                      () => parentClass = cls.className,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: active
                                            ? EditorColors.primary.withValues(
                                                alpha: 0.18,
                                              )
                                            : EditorColors.cardHeader,
                                        borderRadius: BorderRadius.circular(
                                          4,
                                        ),
                                        border: Border.all(
                                          color: active
                                              ? EditorColors.primary
                                              : EditorColors.border,
                                          width: active ? 1.5 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: active
                                                  ? EditorColors.primary
                                                        .withValues(
                                                          alpha: 0.25,
                                                        )
                                                  : EditorColors.card,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Icon(
                                              cls.icon,
                                              size: 14,
                                              color: active
                                                  ? EditorColors.primary
                                                  : EditorColors
                                                        .mutedForeground,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      cls.className,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: active
                                                            ? EditorColors
                                                                  .primary
                                                            : EditorColors
                                                                  .foreground,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 4,
                                                            vertical: 1,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            EditorColors.card,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              2,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        cls.category,
                                                        style: const TextStyle(
                                                          fontSize: 7,
                                                          color: EditorColors
                                                              .mutedForeground,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  cls.description,
                                                  style: const TextStyle(
                                                    fontSize: 8,
                                                    color: EditorColors
                                                        .mutedForeground,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                OutlineButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                PrimaryButton(
                  onPressed: () {
                    final bpName = nameController.text.trim();
                    if (bpName.isNotEmpty) {
                      // The class lands in the folder the
                      // user is browsing.
                      vm?.createBlueprintWithParent(
                        name: bpName,
                        parentClass: parentClass,
                        folder: vm.selectedFolder,
                      );
                    }
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Create Blueprint',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
