import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:lumina/lumina.dart';

import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';

/// The parent class that makes a Blueprint a Widget Blueprint (a
/// Blueprint Class whose parent is `UserWidget`).
const String kWidgetBlueprintParentClass = 'LuminaWidget';

/// Where new Widget Blueprints live: the widget designer's own default folder.
const String kWidgetBlueprintFolder = 'contents/widgets';

/// Writes a new Widget Blueprint named [name] (a default designer canvas) under
/// [folder] (default [kWidgetBlueprintFolder]) of [projectDirPath] and returns
/// its path relative to the project. An existing asset is never overwritten: a
/// taken name gets the next free `_<n>` suffix.
String createWidgetBlueprintAsset({required String projectDirPath, required String name, String folder = kWidgetBlueprintFolder}) {
  final dir = Directory('$projectDirPath/$folder');
  dir.createSync(recursive: true);
  var fileName = name;
  for (var n = 1; File('${dir.path}/$fileName.lmas').existsSync(); n++) {
    fileName = '${name}_$n';
  }
  final json = UmgDocument.createDefault().toFormattedJson();
  final asset = LuminaAsset(
    assetId: 'wbp_${DateTime.now().microsecondsSinceEpoch}',
    name: fileName,
    type: AssetType.widget,
    rawPayload: Uint8List.fromList(utf8.encode(json)),
    metadata: const {'parent_class': kWidgetBlueprintParentClass},
  );
  File('${dir.path}/$fileName.lmas').writeAsBytesSync(asset.toProtoBufferBytes());
  return '$folder/$fileName.lmas';
}

/// Whether the `.lmas` at [lmasPath] is a Widget Blueprint: a widget asset, or
/// an actor Blueprint created with the [kWidgetBlueprintParentClass] parent
/// before such Blueprints were written as widgets. The widget
/// designer opens the latter on a fresh canvas and its first Save writes it as
/// a widget asset.
bool isWidgetBlueprintLmas(String? lmasPath) {
  if (lmasPath == null) return false;
  final file = File(lmasPath);
  if (!file.existsSync()) return false;
  try {
    // Type and metadata only: the summary, never the payload.
    return isWidgetBlueprintSummary(LuminaAsset.readSummary(file));
  } catch (_) {
    return false;
  }
}

/// [isWidgetBlueprintLmas] for an asset summary (an asset index entry).
bool isWidgetBlueprintSummary(LuminaAssetSummary summary) =>
    summary.type == AssetType.widget || summary.metadata['parent_class'] == kWidgetBlueprintParentClass;
