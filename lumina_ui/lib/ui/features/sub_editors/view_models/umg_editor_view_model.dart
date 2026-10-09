import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show ThemeData;
import 'package:lumina_ui/ui/features/sub_editors/views/umg/umg_theme_helper.dart';

import 'package:lumina_ui/ui/features/main_editor/commands/editor_transaction.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/umg_widget_codegen.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/umg_widget_validator.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/widget_blueprint_editor_view_model.dart';

part 'umg_editor_view_model/state.dart';
part 'umg_editor_view_model/persistence.dart';
part 'umg_editor_view_model/editing.dart';

/// Designer mode of the center panel.
enum UmgEditorMode { designer, graph }

/// View model of the UMG designer: one persisted [UmgDocument] inside a real
/// WIDGET `.lmas`, every mutation recorded on its own [TransactionManager],
/// `save()` through `LuminaAsset.toProtoBufferBytes()`, `compile()` through
/// [UmgWidgetCodegen] into the project's `lib/widgets/`.
class UmgEditorViewModel extends _UmgEditorViewModelState with _UmgEditorPersistence, _UmgEditorEditing {
  UmgEditorViewModel({required super.assetPath, LuminaAsset? initialAsset, super.projectDirPathOverride}) : super(initialAsset) {
    if (initialAsset != null) {
      _applyAsset(initialAsset);
      _loaded = true;
    }
    _initThemes();
  }

  void _initThemes() {
    refreshAvailableThemes().then((_) => loadThemeForDocument());
  }

  /// The prop holding a texture path: an Image's brush, a Container's
  /// background image; null for other types.
  static String? textureKeyOf(UmgWidgetType type) => switch (type) {
        UmgWidgetType.image => 'texture',
        UmgWidgetType.container => 'backgroundImage',
        _ => null,
      };
}
