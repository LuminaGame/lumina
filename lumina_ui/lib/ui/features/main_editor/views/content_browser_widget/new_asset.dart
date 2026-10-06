part of '../content_browser_widget.dart';

/// The Add/New asset modal, its per-type buttons, Blueprint creation
/// and opening the new asset's sub-editor.
mixin _ContentBrowserNewAsset on _ContentBrowserWidgetStateBase {

  void _showNewAssetModal(BuildContext context, EditorViewModel? vm) {
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (context) {
        final pluginAssetTypes = vm?.extensionRegistry.allAssetTypes
                .where((h) => h.customTypeId != null)
                .toList() ??
            [];
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AlertDialog(
            title: const Text('Create New Lumina Asset'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 460),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _newAssetTypeBtn(
                      context,
                      vm,
                      'New Static Mesh (.lmas)',
                      AssetType.filamesh,
                      LucideIcons.box,
                      'meshes',
                    ),
                    _newAssetTypeBtn(
                      context,
                      vm,
                      'New Material (.lmas)',
                      AssetType.filamat,
                      LucideIcons.palette,
                      'materials',
                    ),
                    _newAssetTypeBtn(
                      context,
                      vm,
                      'New Texture (.lmas)',
                      AssetType.texture,
                      LucideIcons.image,
                      'textures',
                    ),
                    _newAssetTypeBtn(
                      context,
                      vm,
                      'New Blueprint / Actor (.lmas)',
                      AssetType.actor,
                      LucideIcons.gitBranch,
                      'blueprints',
                    ),
                    _newBlueprintAssetBtn(context, vm, isEnum: true),
                    _newBlueprintAssetBtn(context, vm, isEnum: false),
                    _newAssetTypeBtn(
                      context,
                      vm,
                      'User Interface → Widget Blueprint (.lmas)',
                      AssetType.widget,
                      LucideIcons.layoutTemplate,
                      'widgets',
                    ),
                    _newAssetTypeBtn(
                      context,
                      vm,
                      'User Interface → UI Theme (.lmas)',
                      AssetType.theme,
                      LucideIcons.palette,
                      'themes',
                    ),
                    _newAssetTypeBtn(
                      context,
                      vm,
                      'Animation → Animation Sequence (.lmas)',
                      AssetType.animation,
                      LucideIcons.clapperboard,
                      'animations',
                    ),
                    _newAssetTypeBtn(
                      context,
                      vm,
                      'Animation → Animation Blueprint (.lmas)',
                      AssetType.animBlueprint,
                      LucideIcons.workflow,
                      'animations',
                    ),
                    _newAssetTypeBtn(
                      context,
                      vm,
                      'Animation → Blend Space (.lmas)',
                      AssetType.blendSpace,
                      LucideIcons.grid2x2,
                      'animations',
                    ),
                    _newAssetTypeBtn(
                      context,
                      vm,
                      'New Sequencer (.lmas)',
                      AssetType.sequencer,
                      LucideIcons.film,
                      'cinematics',
                    ),
                    _newAssetTypeBtn(
                      context,
                      vm,
                      'New Particle System (.lmas)',
                      AssetType.particle,
                      LucideIcons.sparkles,
                      'effects',
                    ),
                    _newAssetTypeBtn(
                      context,
                      vm,
                      'New Landscape (.lmas)',
                      AssetType.landscape,
                      LucideIcons.mountain,
                      'landscapes',
                    ),
                    _newAssetTypeBtn(
                      context,
                      vm,
                      'New Level (.lmas)',
                      AssetType.level,
                      LucideIcons.map,
                      'levels',
                    ),
                    if (pluginAssetTypes.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(),
                      ),
                      ...pluginAssetTypes.map(
                        (handler) => _newPluginAssetTypeBtn(context, vm, handler),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              OutlineButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _newPluginAssetTypeBtn(
    BuildContext context,
    EditorViewModel? vm,
    EditorAssetTypeHandler handler,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
        width: double.infinity,
        child: OutlineButton(
          onPressed: () async {
            Navigator.of(context).pop();
            final cmd = vm?.extensionRegistry.allMenuCommands.where((e) {
              final label = e.value.label.toLowerCase();
              final id = e.value.id.toLowerCase();
              final dName = handler.displayName.toLowerCase();
              final customId = handler.customTypeId?.toLowerCase().replaceAll('.', '') ?? '';
              return label == 'new $dName' ||
                  (id.contains(customId) && id.contains('new')) ||
                  (label.contains(dName) && label.contains('new'));
            }).firstOrNull?.value;

            if (cmd != null && cmd.canExecute()) {
              final res = cmd.execute(context);
              if (res is Future) {
                await res;
              }
              vm?.refreshAssets();
            } else {
              final subFolder = handler.customTypeId?.split('.').first ?? 'assets';
              await vm?.createCustomAsset(
                customTypeId: handler.customTypeId!,
                displayName: handler.displayName,
                subFolder: subFolder,
              );
            }
          },
          child: Row(
            children: [
              Icon(handler.icon, size: 14, color: Colors.teal),
              const SizedBox(width: 8),
              Text('New ${handler.displayName} (.lmas)', style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  /// New Asset → Enumeration / Blueprint Interface:
  /// asks for a name, writes the `.lmas` under `contents/enums/` or
  /// `contents/interfaces/` and opens its editor.
  Widget _newBlueprintAssetBtn(BuildContext context, EditorViewModel? vm, {required bool isEnum}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
        width: double.infinity,
        child: OutlineButton(
          key: ValueKey(isEnum ? 'new_asset_enum' : 'new_asset_interface'),
          onPressed: () {
            Navigator.of(context).pop();
            final projectDir = vm?.projectDirPath;
            if (projectDir == null || vm == null) return;
            final controller = TextEditingController(text: isEnum ? 'E_NewEnum' : 'BPI_NewInterface');
            showOverlay(
              this.context,
              const DialogConfiguration(),
              builder: (dialogContext) => AlertDialog(
                title: Text(isEnum ? 'New Enumeration' : 'New Blueprint Interface'),
                content: SizedBox(
                  width: 300,
                  child: TextField(
                    key: const ValueKey('new_blueprint_asset_name'),
                    controller: controller,
                    autofocus: true,
                    placeholder: Text(isEnum ? 'E_DoorState' : 'BPI_Interactable'),
                    onSubmitted: (_) => _createBlueprintAsset(dialogContext, vm, controller.text, isEnum: isEnum),
                  ),
                ),
                actions: [
                  GhostButton(onPressed: () => closeOverlay(dialogContext), child: const Text('Cancel')),
                  PrimaryButton(
                    key: const ValueKey('new_blueprint_asset_create'),
                    onPressed: () => _createBlueprintAsset(dialogContext, vm, controller.text, isEnum: isEnum),
                    child: const Text('Create'),
                  ),
                ],
              ),
            );
          },
          child: Row(
            children: [
              Icon(isEnum ? LucideIcons.list : LucideIcons.plug, size: 14, color: Colors.blue),
              const SizedBox(width: 8),
              Text(isEnum ? 'Blueprints → Enumeration (.lmas)' : 'Blueprints → Blueprint Interface (.lmas)', style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  void _createBlueprintAsset(BuildContext dialogContext, EditorViewModel vm, String rawName, {required bool isEnum}) {
    final name = rawName.trim();
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name)) return;
    closeOverlay(dialogContext);
    final projectDir = vm.projectDirPath;
    final folder = isEnum ? BlueprintAssetCatalog.enumsFolder : BlueprintAssetCatalog.interfacesFolder;
    final unique = BlueprintAssetCatalog.uniqueName(projectDir, folder, name);
    final rel = isEnum
        ? BlueprintAssetCatalog.writeEnum(projectDir, LuminaBlueprintEnumDocument(name: unique))
        : BlueprintAssetCatalog.writeInterface(projectDir, LuminaBlueprintInterfaceDocument(name: unique));
    vm.logger.log('Created ${isEnum ? 'Enumeration' : 'Blueprint Interface'} "$unique" at $folder/', level: 'success', source: 'ContentBrowser');
    vm.refreshAssets();
    final created = vm.realAssets.where((a) => a.relativePath == rel).firstOrNull;
    if (created != null) _openSubEditor(context, created);
  }

  Widget _newAssetTypeBtn(
    BuildContext context,
    EditorViewModel? vm,
    String title,
    AssetType type,
    IconData icon,
    String folder,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
        width: double.infinity,
        child: OutlineButton(
          onPressed: () {
            if (type == AssetType.actor) {
              Navigator.of(context).pop();
              _showCreateBlueprintDialog(context, vm);
            } else if (type == AssetType.widget) {
              // A Widget Blueprint opens as a designer canvas, not an empty
              // shell.
              Navigator.of(context).pop();
              vm?.createWidgetBlueprint(folder: vm.selectedFolder);
            } else if (type == AssetType.animBlueprint || type == AssetType.blendSpace || type == AssetType.animation) {
              // Animation → Animation Sequence / Animation Blueprint / Blend
              // Space: pick the target skeletal mesh, create the asset, open
              // its editor.
              final projectDir = vm?.projectDirPath;
              Navigator.of(context).pop();
              if (projectDir != null && vm != null) {
                // The files the dialog writes are one undo step (an authored
                // sequence's clip leaves its mesh with them).
                final before = vm.contentsSnapshot();
                showCreateAnimAssetDialog(
                  this.context,
                  projectDir: projectDir,
                  kind: switch (type) {
                    AssetType.animBlueprint => AnimAssetKind.animBlueprint,
                    AssetType.blendSpace => AnimAssetKind.blendSpace,
                    _ => AnimAssetKind.animationSequence,
                  },
                  onCreated: (path) {
                    vm.recordCreatedFilesUndo(vm.filesCreatedSince(before), 'Create ${path.split('/').last.replaceAll('.lmas', '')}');
                    vm.refreshAssets();
                    final created = vm.realAssets.where((a) => a.relativePath == path).firstOrNull;
                    if (created != null) _openSubEditor(this.context, created);
                  },
                );
              }
            } else if (type == AssetType.landscape) {
              // A landscape must open as a real terrain, so it is created with
              // a valid flat heightmap payload rather than an empty shell.
              final projectDir = vm?.projectDirPath;
              Navigator.of(context).pop();
              if (projectDir != null) {
                LandscapeAssetService.createFlatAsset(projectDirPath: projectDir)
                    .then((_) => vm?.refreshAssets());
              }
            } else {
              vm?.createNewAsset(type: type, subFolder: folder);
              Navigator.of(context).pop();
            }
          },
          child: Row(
            children: [
              Icon(icon, size: 14, color: _getAssetColor(type)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  void _openSubEditor(BuildContext context, RealAssetInfo asset) {
    final vm = widget.viewModel;
    // One asset-type → editor mapping for the Content Browser, File → New
    // Asset and the MCP `open_asset_editor` tool.
    final category = subEditorCategoryFor(asset, extensions: vm?.extensionRegistry);
    if (category == null) {
      // Double-clicking a level opens it in the level editor (File → Open
      // Level does the same), not a sub-editor.
      vm?.openLevelGuarded(asset.relativePath, context: context);
      return;
    }
    vm?.openSubEditorTab(category, asset: asset);
  }
}
