import 'package:lumina_editor_data/lumina_editor.dart' show kUmgWidgetLibraryFlutter;

import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';

/// Checks a widget document against the project's widget library:
/// a plain-Flutter game cannot import shadcn_flutter, so a
/// shadcn component in such a project is an error naming the element.
abstract final class UmgWidgetValidator {
  /// The shadcn components of [doc], parents before children.
  static List<UmgNode> shadcnNodes(UmgDocument doc) => [for (final n in doc.allNodes) if (n.type.isShadcn) n];

  /// One error per shadcn component when [library] is plain Flutter, and
  /// one per editor widget (Timeline, Table, Tree View, ...) in a game
  /// widget: those run only in editor panels.
  static List<String> errors(UmgDocument doc, String library) => [
        if (!doc.isEditorPanel)
          for (final n in doc.allNodes)
            if (n.type.isEditor)
              '"${n.name}" is an editor ${n.type.displayName}: it runs only in an editor panel (Class Settings > Editor Panel), '
                  'never in a game widget',
        if (library == kUmgWidgetLibraryFlutter)
          for (final n in shadcnNodes(doc))
            '"${n.name}" is a shadcn ${n.type.displayName}: it requires the shadcn widget library (Project Settings > User Interface), '
                'or replace it with a plain widget',
      ];
}
