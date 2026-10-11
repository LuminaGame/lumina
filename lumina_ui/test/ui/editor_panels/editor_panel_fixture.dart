import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_library/editor_library.dart';
import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:path/path.dart' as p;

export 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';

/// Builds an editor panel Widget Blueprint as the designer saves it: a
/// vertical box of elements (each `Is Variable`), the `editorPanel` block and
/// a graph placed in the editor scope.
class EpwBuilder {
  EpwBuilder(this.className, this.info) {
    EditorPanelLibrary.ensureRegistered();
    document.editorPanel = info;
  }

  final String className;
  final LuminaEditorPanelInfo info;
  final UmgDocument document = UmgDocument(root: UmgNode.create(UmgWidgetType.verticalBox, name: 'Root', id: 'umg_root'));
  final LuminaBlueprintDocument graph = LuminaWidgetBlueprintDocument.emptyGraph();
  final List<LuminaBlueprintVariable> _vars = [];
  int _wire = 0;

  /// Adds element [name] of [type] under [parent] (the root by default).
  UmgNode element(UmgWidgetType type, String name, {Map<String, dynamic> props = const {}, String? parent}) {
    final node = UmgNode.create(type, name: name, id: 'n_$name')
      ..props.addAll(props)
      ..isVariable = true;
    document.addChild(parent ?? document.root.id, node);
    return node;
  }

  /// A graph member variable.
  void variable(String name, String typeName, [Object? defaultValue]) =>
      _vars.add(LuminaBlueprintVariable(name: name, typeName: typeName, defaultValue: defaultValue));

  LuminaWidgetBlueprintDocument get _widget => LuminaWidgetBlueprintDocument(
        widgetClass: className,
        variables: [
          for (final n in document.variableNodes) LuminaBlueprintWidgetElement(name: n.name, typeName: n.type.name, props: n.props),
        ],
        blueprint: graph,
      );

  LuminaBlueprintTypeContext get context => LuminaBlueprintTypeContext.forEditorPanel(_widget,
      capabilities: {for (final c in info.capabilities) c.name});

  /// Places node [registryId] as [id].
  void node(String registryId, String id, [Map<String, dynamic>? literals]) {
    graph.variables
      ..clear()
      ..addAll(_vars);
    graph.eventGraph.nodes.add(LuminaBlueprintNodeLibrary.place(registryId, nodeId: id, literals: literals, context: context));
  }

  /// `On <event> (<element>)`.
  void onElement(String id, String element, String event) =>
      node(LuminaBlueprintNodeLibrary.eventWidgetElement, id, {'element': element, 'event': event});

  /// A custom event with string parameters.
  void customEvent(String id, String name, [List<String> stringParams = const [], Map<String, dynamic> extra = const {}]) =>
      node(LuminaBlueprintNodeLibrary.customEvent, id, {
        'name': name,
        'parameters': [for (final pName in stringParams) {'name': pName, 'type': 'String', 'default': ''}],
        ...extra,
      });

  void wire(String from, String fromPin, String to, [String toPin = 'exec_in']) => graph.eventGraph.wires
      .add(LuminaBlueprintWire(id: 'w${_wire++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin));

  /// Wires exec through [ids] in order (each node's `exec_out` into the next).
  void chain(List<String> ids, {String firstPin = 'exec_out'}) {
    for (var i = 0; i + 1 < ids.length; i++) {
      wire(ids[i], i == 0 ? firstPin : 'exec_out', ids[i + 1]);
    }
  }

  UmgDocument build() {
    graph.variables
      ..clear()
      ..addAll(_vars);
    document.blueprint = graph;
    return document;
  }

  /// The `.lmas` bytes.
  Uint8List bytes() => LuminaAsset(
        assetId: 'epw_${className.toLowerCase()}',
        name: className,
        type: AssetType.widget,
        rawPayload: Uint8List.fromList(utf8.encode(jsonEncode(build().toJson()))),
        metadata: const {'parent_class': 'LuminaWidget'},
      ).toProtoBufferBytes();

  /// Writes the asset to [path] (atomically: a watcher never reads half).
  Future<File> writeTo(String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final tmp = File('$path.tmp');
    await tmp.writeAsBytes(bytes(), flush: true);
    await tmp.rename(path);
    return file;
  }
}

/// A real temp project (with its level folder) and, when given, plugins in
/// its `plugins/` folder, enabled in the `.lmproject`.
class EditorPanelProject {
  EditorPanelProject._(this.root, this.projectDir, this.project);

  final Directory root;
  final Directory projectDir;
  final LuminaProject project;

  static const String level = 'contents/levels/L_Main.lmas';

  static Future<EditorPanelProject> create(String name, {List<String> plugins = const []}) async {
    final root = await Directory.systemTemp.createTemp('lumina_epw_');
    final dir = Directory(p.join(root.path, name))..createSync();
    Directory(p.join(dir.path, 'contents', 'levels')).createSync(recursive: true);
    final project = LuminaProject(projectName: name, activeLevel: level, enabledPlugins: plugins);
    File(p.join(dir.path, '$name.lmproject')).writeAsStringSync(jsonEncode(project.toMap()));
    // Per-user data (trust decisions, plugin storage, user plugins) in the temp folder.
    LuminaDataDir.override = Directory(p.join(root.path, 'data'));
    UserPluginDir.override = Directory(p.join(root.path, 'data', 'plugins'));
    PluginDataDir.override = Directory(p.join(root.path, 'data', 'plugin_data'));
    return EditorPanelProject._(root, dir, project);
  }

  /// A content plugin `<project>/plugins/<name>` (`can_contain_content`).
  Directory writePlugin(String name, {String? friendlyName}) {
    final dir = Directory(p.join(projectDir.path, 'plugins', name))..createSync(recursive: true);
    File(p.join(dir.path, '$name.lmplugin')).writeAsStringSync(jsonEncode({
      'name': name,
      'friendly_name': ?friendlyName,
      'version': '1.0.0',
      'category': 'Editor',
      'can_contain_content': true,
    }));
    Directory(p.join(dir.path, 'content')).createSync();
    return dir;
  }

  String projectPath(String rel) => p.join(projectDir.path, rel);

  /// The editor on this project (no timers), its plugins scanned.
  Future<EditorViewModel> open() async {
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    await vm.pluginsScanned;
    return vm;
  }

  /// Starts the editor's panels (docking attached) and waits for the scan.
  static Future<void> startPanels(EditorViewModel vm) async {
    vm.editorPanelDocking.attach();
    await vm.editorPanels.start();
  }

  Future<void> dispose() async {
    LuminaDataDir.override = null;
    UserPluginDir.override = null;
    PluginDataDir.override = null;
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (true) {
      try {
        if (root.existsSync()) root.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        if (DateTime.now().isAfter(deadline)) {
          final locked = <String>[];
          for (final e in root.listSync(recursive: true)) {
            try {
              if (e is File) e.deleteSync();
            } on FileSystemException {
              locked.add(e.path);
            }
          }
          throw FileSystemException('Still open after 10 s: ${locked.join(', ')}', root.path);
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  }
}

/// Polls [condition] every 20 ms (real time) until it holds.
Future<void> until(bool Function() condition, {Duration timeout = const Duration(seconds: 15), String? reason}) async {
  final sw = Stopwatch()..start();
  while (!condition()) {
    if (sw.elapsed > timeout) throw TimeoutException('waited ${timeout.inSeconds} s for ${reason ?? 'a condition'}');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

/// The real test-assets folder.
String testAsset(String rel) => p.join(Directory.current.parent.path, 'test-assets', rel);
