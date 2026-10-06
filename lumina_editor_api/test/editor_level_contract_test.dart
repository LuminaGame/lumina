import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';

/// The level half of the API. A host context is a
/// plain [LuminaEditorContext] plus [EditorLevelAccess]; a bare context has
/// no level, and a plugin tells the two apart with `is`.
class _Level extends ChangeNotifier implements EditorLevelAccess {
  @override
  String? get undoTopLabel => null;

  @override
  bool undoIfTop(String label) => false;

  final List<EditorActorSnapshot> _actors = [];
  final List<String> logs = [];
  int saves = 0;

  @override
  String get projectDirPath => '/tmp/project';
  @override
  String get activeLevelPath => _active;
  @override
  Listenable get changes => this;
  @override
  List<EditorActorSnapshot> get actors => List.unmodifiable(_actors);
  @override
  List<String> get selectedActorIds => const [];

  @override
  Future<T> runTransaction<T>(String label, Future<T> Function() body) => body();

  @override
  Future<List<String>> addActors(List<EditorActorSpec> specs, {String? label}) async {
    final ids = <String>[];
    for (final s in specs) {
      final id = s.id ?? 'act_${_actors.length + 1}';
      _actors.add(EditorActorSnapshot(
        id: id,
        name: s.name,
        type: s.type,
        parentId: s.parentId,
        location: s.location,
        rotation: s.rotation,
        scale: s.scale,
        meshAssetPath: s.meshAssetPath,
        components: [
          for (final c in s.components)
            EditorComponentSnapshot(id: '${id}_${c.type}', type: c.type, name: c.name, properties: c.properties),
        ],
      ));
      ids.add(id);
    }
    notifyListeners();
    return ids;
  }

  @override
  void removeActors(Iterable<String> ids, {String? label}) {
    final set = ids.toSet();
    _actors.removeWhere((a) => set.contains(a.id) || set.contains(a.parentId));
    notifyListeners();
  }

  @override
  void setComponentProperty(String actorId, String componentType, String propertyId, Object? value, {String? label}) {}
  @override
  void selectActors(Iterable<String> ids) {}
  @override
  Future<void> saveLevel() async => saves++;
  @override
  void openAssetEditor(String assetPath) {}
  final List<(String, bool)> opened = [];
  String _active = 'contents/levels/L_Main.lmas';
  @override
  Future<bool> openLevel(String relativePath, {bool show = true}) async {
    if (!relativePath.startsWith('contents/levels/')) return false;
    opened.add((relativePath, show));
    _active = relativePath;
    return true;
  }

  @override
  void log(String message, {String level = 'info', String source = 'Plugin'}) => logs.add('$level:$source:$message');
}

class _Host implements LuminaEditorHostContext {
  @override
  void reportCrash(Object error, StackTrace? stack, {String? plugin, String? context}) {}
  @override
  PluginProcessChannel processChannel(String pluginName) => PluginProcessChannel.detached(pluginName);
  @override
  final EditorLevelAccess level = _Level();
  final List<String> menuPaths = [];
  @override
  void registerMenuItem(String menuPath, EditorCommand command, {EditorMenuItemOptions options = const EditorMenuItemOptions()}) =>
      menuPaths.add(menuPath);
  @override
  void registerMenu(EditorMenuDescriptor menu) {}
  @override
  void registerToolbarButton(EditorToolbarButton button) {}
  @override
  void registerSlotButton(EditorSlotButton button) {}
  @override
  final EditorPanels panels = EditorPanels.detached();
  @override
  final EditorMcp mcp = EditorMcp.detached();
  @override
  final PluginStorage storage = PluginStorage(userDir: Directory('${Directory.systemTemp.path}/lumina_plugin_test_storage'));
  @override
  void registerProjectSettingsSection(ProjectSettingsSection section) => projectSettingsSections.add(section);
  final List<ProjectSettingsSection> projectSettingsSections = [];
  @override
  final ValueNotifier<Map<String, Object?>> pluginSettings = ValueNotifier(const {});
  @override
  void registerPanel(EditorPanelDescriptor panel) {}
  @override
  void registerTab(EditorTabDescriptor tab) {}
  @override
  void openTab(String tabId, {String? title}) {}
  @override
  Widget build3DViewport(BuildContext context, Plugin3DViewportOptions options) => const SizedBox();
  @override
  Widget buildAssetPicker(
    BuildContext context, {
    required String? selectedPath,
    required ValueChanged<String?> onSelected,
    Set<AssetType>? typeFilter,
    String placeholder = 'None',
    bool allowClear = false,
    bool expand = true,
  }) => const SizedBox();
  @override
  void registerAssetType(EditorAssetTypeHandler handler) {}
  @override
  void registerImporter(EditorImporter importer) {}
  @override
  void registerDetailsCustomization(DetailsCustomization c) {}
  @override
  void registerConsoleCommand(String name, String help, void Function(List<String> args) handler) {}
  @override
  Future<void> saveAsset({
    required String relativePath,
    Uint8List? bytes,
    bool generateThumbnail = true,
  }) async {}
}

class _Bare implements LuminaEditorContext {
  @override
  void reportCrash(Object error, StackTrace? stack, {String? plugin, String? context}) {}
  @override
  PluginProcessChannel processChannel(String pluginName) => PluginProcessChannel.detached(pluginName);
  @override
  void registerMenuItem(String menuPath, EditorCommand command, {EditorMenuItemOptions options = const EditorMenuItemOptions()}) {}
  @override
  void registerMenu(EditorMenuDescriptor menu) {}
  @override
  void registerToolbarButton(EditorToolbarButton button) {}
  @override
  void registerSlotButton(EditorSlotButton button) {}
  @override
  final EditorPanels panels = EditorPanels.detached();
  @override
  final EditorMcp mcp = EditorMcp.detached();
  @override
  final PluginStorage storage = PluginStorage(userDir: Directory('${Directory.systemTemp.path}/lumina_plugin_test_storage'));
  @override
  void registerProjectSettingsSection(ProjectSettingsSection section) => projectSettingsSections.add(section);
  final List<ProjectSettingsSection> projectSettingsSections = [];
  @override
  final ValueNotifier<Map<String, Object?>> pluginSettings = ValueNotifier(const {});
  @override
  void registerPanel(EditorPanelDescriptor panel) {}
  @override
  void registerTab(EditorTabDescriptor tab) {}
  @override
  void openTab(String tabId, {String? title}) {}
  @override
  void registerAssetType(EditorAssetTypeHandler handler) {}
  @override
  void registerImporter(EditorImporter importer) {}
  @override
  void registerDetailsCustomization(DetailsCustomization c) {}
  @override
  void registerConsoleCommand(String name, String help, void Function(List<String> args) handler) {}
  @override
  Future<void> saveAsset({
    required String relativePath,
    Uint8List? bytes,
    bool generateThumbnail = true,
  }) async {}
}

class _LevelPlugin extends LuminaEditorPlugin {
  EditorLevelAccess? level;
  @override
  String get pluginName => 'level_plugin';
  @override
  void register(LuminaEditorContext context) {
    if (context is LuminaEditorHostContext) level = context.level;
    context.registerMenuItem('Plugins/Level Plugin/Do', EditorCommand(id: 'x', label: 'Do', canExecute: () => true, execute: (_) {}));
  }
}

void main() {
  test('a host context carries the level; a bare context does not, and both register', () {
    final host = _Host();
    final bare = _Bare();
    final plugin = _LevelPlugin();
    plugin.register(bare);
    expect(plugin.level, isNull, reason: 'a bare LuminaEditorContext has no level');
    plugin.register(host);
    expect(plugin.level, same(host.level));
    expect(host.menuPaths, ['Plugins/Level Plugin/Do']);
  });

  test('EditorActorSpec → snapshot keeps transform, mesh path and components; componentOfType finds by type', () async {
    final level = _Level();
    final ids = await level.addActors([
      const EditorActorSpec(
        name: 'Barrel_1',
        type: 'StaticMesh',
        location: [100.0, -50.0, 12.5],
        rotation: [0.0, 0.0, 90.0],
        scale: [1.2, 1.2, 1.2],
        meshAssetPath: '/tmp/project/contents/meshes/barrel.glb',
        components: [EditorComponentSpec(type: 'LuminaMeshComponent', name: 'Mesh')],
      ),
    ]);
    expect(ids, hasLength(1));
    final a = level.actors.single;
    expect(a.location, [100.0, -50.0, 12.5]);
    expect(a.rotation, [0.0, 0.0, 90.0]);
    expect(a.scale, [1.2, 1.2, 1.2]);
    expect(a.meshAssetPath, endsWith('barrel.glb'));
    expect(a.componentOfType('LuminaMeshComponent')?.name, 'Mesh');
    expect(a.componentOfType('Nope'), isNull);
    level.removeActors(ids);
    expect(level.actors, isEmpty);
  });

  test('openLevel opens a level by its project-relative path and shows it unless asked not to', () async {
    final level = _Level();
    expect(await level.openLevel('contents/levels/L_Generated.lmas'), isTrue);
    expect(level.activeLevelPath, 'contents/levels/L_Generated.lmas');
    expect(await level.openLevel('contents/levels/L_Main.lmas', show: false), isTrue);
    expect(level.opened, [('contents/levels/L_Generated.lmas', true), ('contents/levels/L_Main.lmas', false)]);
    expect(await level.openLevel('contents/maps/x.lmas'), isFalse);
  });

  testWidgets('EditorAssetPicker delegates to hostContext.buildAssetPicker', (tester) async {
    final host = _Host();
    String? picked;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: EditorAssetPicker(
          hostContext: host,
          selectedPath: 'contents/meshes/test.lmas',
          typeFilter: const {AssetType.filameshSk},
          onSelected: (p) => picked = p,
        ),
      ),
    );
    expect(find.byType(EditorAssetPicker), findsOneWidget);
    expect(picked, isNull);
  });
}

