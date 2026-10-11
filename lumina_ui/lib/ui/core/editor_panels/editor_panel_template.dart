import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:path/path.dart' as p;

import 'package:lumina_ui/ui/core/editor_panels/editor_library/editor_library.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';

/// The folder New ▸ Editor Panel Widget writes into by default.
const String kEditorPanelFolder = 'contents/editor';

/// A new editor panel Widget Blueprint: an Editor Section holding a Property
/// Row and a Button whose On Clicked shows a toast — a working panel to
/// start from, docked right.
UmgDocument editorPanelTemplate(String className) {
  EditorPanelLibrary.ensureRegistered();
  final title = className.replaceFirst(RegExp(r'^(EPW_|WBP_)'), '').replaceAll('_', ' ');
  final doc = UmgDocument(
    root: UmgNode.create(UmgWidgetType.verticalBox, name: 'Root', id: 'umg_root'),
    editorPanel: LuminaEditorPanelInfo(title: title.isEmpty ? 'Editor Panel' : title, icon: 'wrench', dock: LuminaEditorPanelDock.right),
  );
  final section = UmgNode.create(UmgWidgetType.editorSection, name: 'Section')..props['title'] = 'Selection';
  doc.addChild(doc.root.id, section);
  final row = UmgNode.create(UmgWidgetType.propertyRow, name: 'NameRow')..props['label'] = 'Name';
  doc.addChild(section.id, row);
  doc.addChild(row.id, UmgNode.create(UmgWidgetType.text, name: 'NameText')..props['text'] = 'Nothing selected');
  final button = UmgNode.create(UmgWidgetType.button, name: 'HelloButton')..props['label'] = 'Say Hello';
  doc.addChild(section.id, button);

  final widget = LuminaWidgetBlueprintDocument(
    widgetClass: className,
    variables: [for (final n in doc.variableNodes) LuminaBlueprintWidgetElement(name: n.name, typeName: n.type.name, props: n.props)],
  );
  final context = LuminaBlueprintTypeContext.forEditorPanel(widget);
  final graph = widget.blueprint;
  graph.eventGraph.nodes.addAll([
    LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.eventWidgetElement,
        nodeId: 'hello_clicked', x: 0, y: 0, literals: {'element': 'HelloButton', 'event': LuminaWidgetEvents.onClicked}, context: context),
    LuminaBlueprintNodeLibrary.place('editor_show_toast',
        nodeId: 'hello_toast',
        x: 320,
        y: 0,
        literals: {'title': 'Hello from $className', 'message': 'This panel runs in the editor\'s Blueprint VM.', 'tone': 'success'},
        context: context),
  ]);
  graph.eventGraph.wires.add(const LuminaBlueprintWire(
      id: 'w_hello', fromNodeId: 'hello_clicked', fromPinId: 'exec_out', toNodeId: 'hello_toast', toPinId: 'exec_in'));
  doc.blueprint = graph;
  return doc;
}

/// Writes a new editor panel asset `<folder>/<name>.lmas` (a free name:
/// `_1`, `_2` … when taken) under [projectDirPath]; returns its
/// project-relative path.
Future<String> createEditorPanelAsset({required String projectDirPath, String name = 'EPW_NewEditorPanel', String folder = kEditorPanelFolder}) async {
  final dir = Directory(p.join(projectDirPath, folder));
  await dir.create(recursive: true);
  var fileName = name;
  for (var n = 1; await File(p.join(dir.path, '$fileName.lmas')).exists(); n++) {
    fileName = '${name}_$n';
  }
  final asset = LuminaAsset(
    assetId: 'epw_${DateTime.now().microsecondsSinceEpoch}',
    name: fileName,
    type: AssetType.widget,
    rawPayload: Uint8List.fromList(utf8.encode(editorPanelTemplate(fileName).toFormattedJson())),
    metadata: const {'parent_class': 'LuminaWidget'},
  );
  await File(p.join(dir.path, '$fileName.lmas')).writeAsBytes(asset.toProtoBufferBytes(), flush: true);
  return '$folder/$fileName.lmas';
}
