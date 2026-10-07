# Extension points — minimal working code and how the host routes each

All from `package:lumina_editor_api/lumina_editor_api.dart`; the worked example is `lumina_plugin_pcg/lib/src/lumina_plugin_pcg_plugin.dart`. Host routing lives in lumina_ui: `lib/ui/core/plugin_extension_registry.dart` (the registry implementing `LuminaEditorHostContext`), `views/menu_bar_widget.dart` (menu), `views/details_widget.dart` (`_buildPluginSections`), `views/content_browser_widget.dart` + `sub_editors/views/sub_editor_modal.dart` (plugin asset tabs), `lib/ui/core/editor_level_access.dart` (level).

## Menu command
```dart
context.registerMenuItem('Plugins/PCG/Generate All', EditorCommand(
  id: 'tools.lumina_plugin_pcg.generateAll',   // unique across all plugins
  label: 'Generate All', icon: LucideIcons.sprout,
  canExecute: () => _level != null,
  execute: (BuildContext? ctx) => _service?.generateAll(),   // ctx is null from tests / console
), options: const EditorMenuItemOptions(section: 'run'));   // order / section / checked: all optional
```
Shows under **Plugins ▸ PCG** (paths nest to any depth; items sort by `order`, a divider separates `section`s, `checked` draws a live check mark) (menu_bar registers it into `EditorCommandRegistry` on first build, so `vm.commands.execute(id, ctx)` also works). Dialogs: `showOverlay(ctx, DialogConfiguration(builder: (c) => AlertDialog(... PrimaryButton(onPressed: () => closeOverlay(c)))))`.

## Own top-level menu
```dart
context.registerMenu(const EditorMenuDescriptor(
  id: 'terrain', title: 'Terrain', placement: EditorMenuPlacement.beforeWindow));   // or beforeHelp
context.registerMenuItem('Terrain/Sculpt/Raise', EditorCommand(
  id: 'terrain_tools.raise', label: 'Raise', canExecute: () => true, execute: (_) => _raise()));
```
The menu bar reads `File … Tools, Plugins, Terrain, Window, Help`. Register the menu before its items. Titles of built-in menus or of another plugin's menu are refused (`menuConflict`); a plugin's fourth menu (the title bar holds 3) folds into `Plugins ▸ Terrain` (`tooManyMenus`). Both issues show on the plugin's Plugin Manager row and in the Output Log.

## Slot button (toolbar / status bar, live state)
```dart
final aiState = ValueNotifier(const EditorButtonState(icon: LucideIcons.sparkles, tooltip: 'MiniAI', label: 'AI'));
context.registerSlotButton(EditorSlotButton(
  id: 'ai', slot: EditorSlot.levelToolbarAfterBlueprints, order: 0, state: aiState,
  command: EditorCommand(id: 'miniai.toggle', label: 'AI', canExecute: () => true, execute: (_) => _toggle()),
  // menu: [cmdA, cmdB],   // a click opens a dropdown of these instead
));
// Later — only this button repaints:
aiState.value = aiState.value.copyWith(busy: true);   // spinner in place of the icon
aiState.value = aiState.value.copyWith(busy: false, active: true, badge: '2', tone: EditorTone.primary);
```
Slots:
- `levelToolbarAfterBlueprints`: right of Blueprints ▾;
- `levelToolbarEnd`: left of Quality;
- `statusBarLeft`: after the actor counts;
- `statusBarRight`: before the Shaders / Quality / RHI text.

Tones (`neutral`, `primary`, `success`, `warning`, `destructive`) follow the editor theme; never pass a colour. The host namespaces the id as `<pluginName>.<id>` and refuses a duplicate. `order` sorts buttons within a slot.

The older static `registerToolbarButton(EditorToolbarButton(..., group:))` still works: a `group` that names a slot puts the button there, and any other group goes to `levelToolbarEnd`.

## Panel
```dart
context.registerPanel(EditorPanelDescriptor(
  id: 'panel.my_tools', title: 'My Tools', icon: LucideIcons.layoutGrid,
  builder: (ctx) => const MyPanelWidget(), defaultDock: PanelDefaultDock.right));
```
Registered and listed in `allPanels`; docking into the shell is a planned follow-up, so today put interactive UI in a Details section or an asset editor instead.

## Asset type (custom `.lmas`) + sub-editor tab
```dart
// Writing the asset
final asset = LuminaAsset(assetId: 'pcg_$name', name: name, type: AssetType.unknown,
  rawPayload: Uint8List.fromList(utf8.encode(json)),
  metadata: {kCustomAssetTypeKey: 'pcg.graph'});
File(path).writeAsBytesSync(asset.toProtoBufferBytes());
// Registering the editor
context.registerAssetType(EditorAssetTypeHandler(
  customTypeId: 'pcg.graph', displayName: 'PCG Graph', icon: LucideIcons.workflow,
  thumbnailBuilder: (_) async => null,
  editorFactory: (ctx, asset) => PcgGraphEditor(asset: asset /* metadata[kAssetPathMetadataKey] = abs path */, level: _level!, service: _service!),
));
```
Host: `PluginExtensionRegistry.handlerForAsset(RealAssetInfo)` reads `metadata.custom_type` of an `AssetType.unknown` `.lmas` (mtime-cached); the Content Browser double-click and `EditorLevelAccess.openAssetEditor(path)` open the tab `pluginAsset:<customTypeId>`, which `SubEditorWorkspaceWidget` renders with your `editorFactory`. Save by writing the `.lmas` back to `asset.metadata[kAssetPathMetadataKey]`.

## Importer
```dart
context.registerImporter(EditorImporter(
  extensions: const ['.pcggraph'], description: 'PCG Graph (JSON) Importer',
  import: (File source, ImportContext ctx) async {
    final target = '${ctx.targetDirectory}/${basename}.lmas';
    await PcgGraphAsset.save(graph, target);
    return ImportResult.success(target);   // or ImportResult.failure(message)
  }));
```

## Details customization
```dart
context.registerDetailsCustomization(DetailsCustomization(
  targetTypeId: 'PcgVolume',          // EditorActorNode.type
  sectionTitle: 'PCG',
  builder: (ctx, DetailsTarget target) {
    final actor = target.target as EditorActorSnapshot;
    final seed = actor.componentOfType('LuminaPcgComponent')?.properties['seed'];
    return PrimaryButton(onPressed: () => target.setProperty('LuminaPcgComponent.seed', 42), child: Text('Seed $seed'));
  }));
```
Host: `DetailsWidget` renders a `_CategoryHeader(sectionTitle)` + your widget for the selected actor of that type (single selection), rebuilt on every view-model change. `setProperty` names: `'<ComponentType>.<propertyId>'` → `setComponentPropertyWithTransaction`; `'name'`, `'location'`, `'rotation'`, `'scale'` → the built-in undoable paths.

## Console command
```dart
context.registerConsoleCommand('pcg.generate', 'Generate every PCG Volume (pcg.generate [volumeId])', (args) { … });
```

## Level access (host context only)
```dart
if (context is LuminaEditorHostContext) _level = context.level;
…
final ids = await _level!.addActors([
  EditorActorSpec(name: 'Barrel_1', type: 'StaticMesh', parentId: volumeId,
    location: [x, y, z] /* cm, Z up */, rotation: [0, 0, yaw], scale: [1, 1, 1],
    meshAssetPath: '${_level!.projectDirPath}/contents/meshes/fuel_barrel_red.glb',   // absolute
    components: const [EditorComponentSpec(type: 'LuminaMeshComponent', name: 'Mesh')]),
], label: 'PCG Generate');            // ONE undo entry, geometry loaded from disk
_level!.removeActors(ids, label: 'PCG Cleanup');
_level!.setComponentProperty(volumeId, 'LuminaPcgComponent', 'instanceCount', ids.length);
await _level!.saveLevel();           // = File → Save Level (level .lmas + generated Dart)
_level!.log('done', level: 'success', source: 'PCG');
```
`actors` are immutable snapshots; `changes` is a `Listenable` (the view model) to rebuild on. Landscape height: find the `Landscape` actor (`meshAssetPath` → `.lmas` → `LuminaAsset.rawPayload` → `LandscapeData.fromBytes`) and map cm/Z-up to its metre/Y-up grid as `PcgLandscapeSurface` does.

## Bare vs host context in tests
```dart
class _Bare implements LuminaEditorContext { /* 7 registrars, record what you need */ }
class _Host extends _Bare implements LuminaEditorHostContext { @override final EditorLevelAccess level; _Host(this.level); }
```
`lumina_plugin_pcg/test/test_support.dart` has `FileLevel`, an `EditorLevelAccess` over a real level file, reusable by copying.

## Process part (isolated plugins)

An isolated plugin (`"isolation": "process"` + `"process_class"`) registers from its `LuminaPluginProcess.register(PluginProcessContext context)`; every contribution is data, its callbacks run in the plugin process.

```dart
context.registerMenuItem('Plugins/My Tools/Bake', PluginProcessCommand(
    id: 'tools.my_tools.bake', label: 'Bake', run: () => _bake(context)));

context.handle('ping', (args) => {'reply': 'pong', 'pid': pid});           // shell: channel.call('ping')
context.emit('baked', {'path': out});                                        // shell: channel.events('baked')
context.progress('bake', step: 'meshes', done: 3, total: 10);               // shell: channel.progress

context.registerViewPanel(PluginProcessViewPanel(
  id: 'panel.my_tools.status', title: 'My Tools Status',
  initial: const PluginViewSpec(id: 'my_tools.status', children: [
    PluginControl(kind: PluginControlKind.text, id: 'status', props: {'value': 'Idle'}),
    PluginControl(kind: PluginControlKind.button, id: 'run', props: {'text': 'Run'}),
  ]),
  onEvent: (event, view) {
    if (event.controlId == 'run' && event.kind == 'pressed') {
      view.patch(PluginViewPatch([PluginViewPatchOp.set('status', {'value': 'Running'})]));
    }
  },
));

context.registerImporter(PluginProcessImporter(id: 'my_tools.txt', extensions: const ['.txt'],
    description: 'Text', import: (source, targetDirectory) async => '$targetDirectory/x.lmas'));
```

Routing: the editor shows the menu item / slot button / panel / importer as if registered in process and sends the action to the process; while the process is not running, the items are unavailable and the panels show the stop with Restart. The level (`context.level`) is a proxy: each edit is an undoable editor transaction and `runTransaction` groups proxied edits into one undo step.

The types above come from the pure-Dart `package:lumina_plugin_process` (re-exported by `lumina_editor_api`). A slot button with live state takes an `ObservableValue`:

```dart
final status = ObservableValue(const PluginButtonStateSpec(icon: PluginIconSpec(0xe88e), tooltip: 'Idle'));
context.registerSlotButton(PluginProcessSlotButton(id: 'my_tools.status', slot: 'statusBarRight', state: status,
    command: PluginProcessCommand(id: 'my_tools.status', label: 'Status', run: () {})));
status.value = const PluginButtonStateSpec(icon: PluginIconSpec(0xe88e), tooltip: 'Baking', busy: true); // sent to the editor
```
