import 'package:lumina/lumina.dart' show kUmgWidgetLibraryFlutter;

import '../models/umg_document.dart';

/// Checks a widget document against the project's widget library:
/// a plain-Flutter game cannot import shadcn_flutter, so a
/// shadcn component in such a project is an error naming the element.
abstract final class UmgWidgetValidator {
  /// The shadcn components of [doc], parents before children.
  static List<UmgNode> shadcnNodes(UmgDocument doc) => [for (final n in doc.allNodes) if (n.type.isShadcn) n];

  /// One error per shadcn component when [library] is plain Flutter.
  static List<String> errors(UmgDocument doc, String library) {
    if (library != kUmgWidgetLibraryFlutter) return const [];
    return [
      for (final n in shadcnNodes(doc))
        '"${n.name}" is a shadcn ${n.type.displayName}: it requires the shadcn widget library (Project Settings > User Interface), '
            'or replace it with a plain widget',
    ];
  }
}
