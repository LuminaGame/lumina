import 'dart:convert';
import 'dart:ui';

import 'package:lumina_editor_data/lumina_editor.dart' show LuminaBlueprintDocument, LuminaWidgetBlueprintDocument;
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document/layout.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document/node.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document/widget_type.dart';

export 'package:lumina_ui/ui/features/sub_editors/models/umg_document/layout.dart';
export 'package:lumina_ui/ui/features/sub_editors/models/umg_document/node.dart';
export 'package:lumina_ui/ui/features/sub_editors/models/umg_document/widget_type.dart';

/// The persisted designer document (`rawPayload` UTF-8 JSON of the WIDGET `.lmas`).
class UmgDocument {
  UmgNode root;
  UmgResolution designResolution;
  double dpiScale;
  String? themePath;

  /// The widget's own Blueprint graph, stored
  /// under `blueprint`; null for a widget that never had one.
  LuminaBlueprintDocument? blueprint;

  UmgDocument({
    required this.root,
    this.designResolution = const UmgResolution('1920x1080 Full HD', 1920, 1080),
    this.dpiScale = 1.0,
    this.themePath,
    this.blueprint,
  });

  /// A new widget: one root Canvas Panel.
  factory UmgDocument.createDefault({String? themePath}) {
    final root = UmgNode.create(UmgWidgetType.canvasPanel, name: 'Root Canvas', id: 'umg_root');
    return UmgDocument(root: root, themePath: themePath);
  }

  Size get logicalSize => Size(designResolution.width / dpiScale, designResolution.height / dpiScale);

  /// [includeBlueprint] false leaves the graph out: the designer's own undo
  /// snapshots and dirty check, which the graph editor has its own of.
  Map<String, dynamic> toJson({bool includeBlueprint = true}) => {
        'version': 1,
        'designResolution': {'width': designResolution.width, 'height': designResolution.height},
        'dpiScale': dpiScale,
        if (themePath != null && themePath!.isNotEmpty) 'theme': themePath,
        'root': root.toJson(),
        if (includeBlueprint && blueprint != null) LuminaWidgetBlueprintDocument.payloadKey: blueprint!.toJson(),
      };

  String toFormattedJson({bool includeBlueprint = true}) =>
      const JsonEncoder.withIndent('  ').convert(toJson(includeBlueprint: includeBlueprint));

  /// The elements marked `Is Variable`, in tree order (the root is never one).
  List<UmgNode> get variableNodes => [for (final n in allNodes) if (!identical(n, root) && n.isVariable && n.name.isNotEmpty) n];

  factory UmgDocument.fromJson(Map<String, dynamic> map) {
    final res = map['designResolution'];
    UmgResolution resolution = UmgResolution.presets.first;
    if (res is Map) {
      final w = (res['width'] as num?)?.toInt() ?? 1920;
      final h = (res['height'] as num?)?.toInt() ?? 1080;
      resolution = UmgResolution.presets.firstWhere((p) => p.width == w && p.height == h, orElse: () => UmgResolution('Custom ${w}x$h', w, h, isCustom: true));
    }
    final rootMap = map['root'];
    final graph = map[LuminaWidgetBlueprintDocument.payloadKey];
    return UmgDocument(
      root: rootMap is Map ? UmgNode.fromJson(Map<String, dynamic>.from(rootMap)) : UmgDocument.createDefault().root,
      designResolution: resolution,
      dpiScale: (map['dpiScale'] as num?)?.toDouble() ?? 1.0,
      themePath: map['theme'] as String?,
      blueprint: graph is Map ? LuminaBlueprintDocument.fromJson(Map<String, dynamic>.from(graph)) : null,
    );
  }

  UmgDocument deepCopy() => UmgDocument.fromJson(toJson());

  UmgNode? findNode(String id) {
    UmgNode? found;
    root.visit((n, _) {
      if (n.id == id) found = n;
    });
    return found;
  }

  UmgNode? parentOf(String id) {
    UmgNode? found;
    root.visit((n, p) {
      if (n.id == id) found = p;
    });
    return found;
  }

  List<UmgNode> get allNodes {
    final out = <UmgNode>[];
    root.visit((n, _) => out.add(n));
    return out;
  }

  bool isDescendant(String ancestorId, String id) {
    final a = findNode(ancestorId);
    if (a == null) return false;
    var found = false;
    a.visit((n, _) {
      if (n.id == id && n.id != ancestorId) found = true;
    });
    return found;
  }

  /// Why [parent] cannot take another child, or null when it can.
  String? rejectionReasonFor(UmgNode parent, {int extra = 1}) {
    switch (parent.type.capacity) {
      case UmgChildCapacity.none:
        return '${parent.type.displayName} "${parent.name}" is a leaf widget and cannot contain children';
      case UmgChildCapacity.one:
        if (parent.children.length + extra > 1) {
          return '${parent.type.displayName} "${parent.name}" accepts exactly one child';
        }
        return null;
      case UmgChildCapacity.many:
        return null;
    }
  }

  /// Gives [node] a slot matching [parent]'s child slot kind, keeping any
  /// fields that still apply.
  void assignSlotFor(UmgNode node, UmgNode parent, {Offset? canvasPosition}) {
    final kind = parent.type.childSlotKind;
    final slot = node.slot;
    slot.kind = kind;
    if (kind == UmgSlotKind.canvas) {
      if (canvasPosition != null) slot.position = canvasPosition;
      if (slot.size.isEmpty) slot.size = node.type.defaultCanvasSize;
    }
  }

  /// Attaches a detached [node] under [parentId]; returns the node, or null
  /// (with a reason in [lastRejectionReason]) when the parent cannot take it.
  String? lastRejectionReason;

  UmgNode? addChild(String parentId, UmgNode node, {Offset? canvasPosition, int? index}) {
    final parent = findNode(parentId);
    if (parent == null) {
      lastRejectionReason = 'Parent not found';
      return null;
    }
    final reason = rejectionReasonFor(parent);
    if (reason != null) {
      lastRejectionReason = reason;
      return null;
    }
    lastRejectionReason = null;
    if (node.slot.size.isEmpty) node.slot.size = node.type.defaultCanvasSize;
    node.fieldName = uniqueFieldName(node.fieldName.isEmpty ? UmgNaming.toFieldName(node.type.displayName) : node.fieldName, exclude: node.id);
    assignSlotFor(node, parent, canvasPosition: canvasPosition);
    if (index == null || index < 0 || index > parent.children.length) {
      parent.children.add(node);
    } else {
      parent.children.insert(index, node);
    }
    return node;
  }

  bool removeNode(String id) {
    final parent = parentOf(id);
    if (parent == null) return false;
    parent.children.removeWhere((c) => c.id == id);
    return true;
  }

  /// Makes [base] unique across the tree by appending a number.
  String uniqueFieldName(String base, {String? exclude}) {
    final taken = <String>{};
    root.visit((n, _) {
      if (n.id != exclude) taken.add(n.fieldName);
    });
    var candidate = base.isEmpty ? 'widget' : base;
    var i = 2;
    while (taken.contains(candidate)) {
      candidate = '$base${i++}';
    }
    return candidate;
  }

  bool isFieldNameTaken(String fieldName, {String? exclude}) {
    var taken = false;
    root.visit((n, _) {
      if (n.id != exclude && n.fieldName == fieldName) taken = true;
    });
    return taken;
  }
}
