import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart' show Offset;
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/services/widget_blueprint_assets.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';

import 'blueprint_test_project.dart';

/// A `WBP_HUD` designer document: a Text `FPSCounter` and a Progress Bar
/// `Health` on the root canvas, as the UMG editor authors it.
UmgDocument hudDocument() {
  final doc = UmgDocument.createDefault();
  final fps = UmgNode.create(UmgWidgetType.text, name: 'FPSCounter');
  fps.props['text'] = 'FPS: --';
  doc.addChild(doc.root.id, fps, canvasPosition: const Offset(24, 24));
  final health = UmgNode.create(UmgWidgetType.progressBar, name: 'Health');
  health.props['percent'] = 0.75;
  doc.addChild(doc.root.id, health, canvasPosition: const Offset(24, 64));
  return doc;
}

/// A menu widget with one button, so the palette has a second widget class
/// (`Cast To WBP_Menu`) to offer.
UmgDocument menuDocument() {
  final doc = UmgDocument.createDefault();
  doc.addChild(doc.root.id, UmgNode.create(UmgWidgetType.button, name: 'PlayButton'), canvasPosition: const Offset(24, 24));
  return doc;
}

/// Writes [doc] as the widget Blueprint `contents/widgets/<name>.lmas` of
/// [projectDir] through the same asset shape the UMG editor saves, and
/// returns its path relative to the project.
String writeWidgetBlueprint(String projectDir, String name, UmgDocument doc) {
  final json = doc.toFormattedJson();
  final asset = LuminaAsset(
    assetId: 'wbp_$name',
    name: name,
    type: AssetType.widget,
    rawPayload: Uint8List.fromList(utf8.encode(json)),
    metadata: const {'parent_class': kWidgetBlueprintParentClass},
  );
  final file = File('$projectDir/$kWidgetBlueprintFolder/$name.lmas')..parent.createSync(recursive: true);
  file.writeAsBytesSync(asset.toProtoBufferBytes());
  return '$kWidgetBlueprintFolder/$name.lmas';
}

/// A real Third Person project for the typed-pin tests:
/// the template's character Blueprint (CameraBoom, FollowCamera, Mesh,
/// CharacterMovement), `WBP_HUD` and `WBP_Menu` widget Blueprints, and a
/// second actor Blueprint `BP_Door` for Cast To.
class WidgetClassTestProject {
  final BlueprintTestProject project;
  final String characterPath;

  WidgetClassTestProject._(this.project, this.characterPath);

  String get dir => project.dir;

  static WidgetClassTestProject create() {
    final project = BlueprintTestProject.create(name: 'HudProject');
    final actions = ProjectInputBinder.bind(GameTemplateCatalog.byId(kThirdPersonTemplateId).input).actions.values.toList();
    final character = writeBlueprint(project.dir, LuminaThirdPersonContent.characterBlueprintName,
        LuminaThirdPersonContent.characterBlueprint(inputActions: actions, withMesh: true));
    project.createBlueprint('BP_Door', parentClass: 'LuminaActor');
    writeWidgetBlueprint(project.dir, 'WBP_HUD', hudDocument());
    writeWidgetBlueprint(project.dir, 'WBP_Menu', menuDocument());
    return WidgetClassTestProject._(project, character);
  }

  void dispose() => project.dispose();
}
