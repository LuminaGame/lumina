import 'package:flutter/foundation.dart';

/// Invoked by a sub-editor once its view model exists, so the editor shell
/// can bind the hosting workspace tab to the view model's dirty state and
/// save routine (see `EditorViewModel.bindTabSession`).
typedef SubEditorBindCallback = void Function(
  Listenable notifier,
  Future<bool> Function() save,
  bool Function() isDirty,
);
