/// A declarative panel: a tree of controls the host renders with its own
/// widgets. A plugin process cannot send widgets; it sends this, receives
/// [PluginViewEvent]s and answers with a new spec or a [PluginViewPatch].
class PluginViewSpec {
  const PluginViewSpec({required this.id, this.children = const []});

  /// Unique per plugin; events and patches name it.
  final String id;
  final List<PluginControl> children;

  Map<String, Object?> toJson() => {'id': id, 'children': [for (final c in children) c.toJson()]};

  static PluginViewSpec fromJson(Map<String, Object?> json) => PluginViewSpec(
        id: json['id'] as String,
        children: [for (final c in (json['children'] as List?) ?? const []) PluginControl.fromJson((c as Map).cast())],
      );

  /// The control with [controlId] anywhere in the tree, or null.
  PluginControl? find(String controlId) {
    PluginControl? walk(List<PluginControl> list) {
      for (final c in list) {
        if (c.id == controlId) return c;
        final inner = walk(c.children);
        if (inner != null) return inner;
      }
      return null;
    }

    return walk(children);
  }

  /// This spec with [patch] applied (unknown ids are ignored).
  PluginViewSpec apply(PluginViewPatch patch) {
    PluginControl update(PluginControl c) {
      var out = c;
      for (final op in patch.ops) {
        if (op.controlId != c.id) continue;
        out = op.replace ?? out.copyWith(props: {...out.props, ...op.set});
      }
      return out.children.isEmpty ? out : out.copyWith(children: [for (final k in out.children) update(k)]);
    }

    return PluginViewSpec(id: id, children: [for (final c in children) update(c)]);
  }
}

/// The control kinds the host renders. Props per kind (all optional unless
/// noted; `label` and `tooltip` work on every kind, `enabled` on inputs and
/// buttons):
/// - [section]: `title`, `collapsed` (bool); has children.
/// - [row]: children laid out horizontally; `gap` (px).
/// - [text]: `value` (string, required), `style` (`body`|`muted`|`heading`|`code`|`error`).
/// - [textField]: `value`, `placeholder`, `multiline` (bool); events `changed` (on submit) with the string.
/// - [numberField]: `value`, `min`, `max`, `step`, `unit`; event `changed` with the number.
/// - [boolField]: `value`; event `changed` with the bool.
/// - [enumField]: `value`, `options` (list of `{"value","label"}`); event `changed` with the value.
/// - [assetRefField]: `value` (project-relative path or null), `assetTypes` (list of
///   `AssetType.name`), event `changed` with the path (picked through the host's asset picker).
/// - [colorField]: `value` (`#RRGGBB` or `#AARRGGBB`); event `changed`.
/// - [button]: `text` (required), `tone` (`EditorTone.name`), `icon` (PluginIconSpec json); event `pressed`.
/// - [progress]: `value` (0..1, null = indeterminate), `text`.
/// - [log]: `lines` (list of strings, newest last), `maxLines` (default 200).
/// - [image]: `path` (absolute file) or `base64` (PNG/JPEG bytes), `height`.
/// - [preview3d]: `scene` ([PluginSceneSpec] json), `height`; the host renders it with its own
///   viewport. Event `picked` with `{"node": <name>}` when the user clicks a node.
/// - [divider].
abstract final class PluginControlKind {
  static const String section = 'section';
  static const String row = 'row';
  static const String text = 'text';
  static const String textField = 'textField';
  static const String numberField = 'numberField';
  static const String boolField = 'boolField';
  static const String enumField = 'enumField';
  static const String assetRefField = 'assetRefField';
  static const String colorField = 'colorField';
  static const String button = 'button';
  static const String progress = 'progress';
  static const String log = 'log';
  static const String image = 'image';
  static const String preview3d = 'preview3d';
  static const String divider = 'divider';

  static const List<String> all = [
    section, row, text, textField, numberField, boolField, enumField, assetRefField, colorField, button, progress, log,
    image, preview3d, divider,
  ];
}

/// One node of a [PluginViewSpec].
class PluginControl {
  const PluginControl({required this.kind, required this.id, this.props = const {}, this.children = const []});

  final String kind;

  /// Unique within its view; the host keys widgets as `<viewId>/<id>`.
  final String id;
  final Map<String, Object?> props;
  final List<PluginControl> children;

  Object? operator [](String prop) => props[prop];

  PluginControl copyWith({Map<String, Object?>? props, List<PluginControl>? children}) =>
      PluginControl(kind: kind, id: id, props: props ?? this.props, children: children ?? this.children);

  Map<String, Object?> toJson() => {
        'kind': kind,
        'id': id,
        if (props.isNotEmpty) 'props': props,
        if (children.isNotEmpty) 'children': [for (final c in children) c.toJson()],
      };

  static PluginControl fromJson(Map<String, Object?> json) => PluginControl(
        kind: json['kind'] as String,
        id: json['id'] as String,
        props: (json['props'] as Map?)?.cast<String, Object?>() ?? const {},
        children: [for (final c in (json['children'] as List?) ?? const []) PluginControl.fromJson((c as Map).cast())],
      );

  // Shorthands for building specs.
  static PluginControl section(String id, String title, List<PluginControl> children, {bool collapsed = false}) =>
      PluginControl(kind: PluginControlKind.section, id: id, props: {'title': title, 'collapsed': collapsed}, children: children);
  static PluginControl row(String id, List<PluginControl> children) =>
      PluginControl(kind: PluginControlKind.row, id: id, children: children);
  static PluginControl text(String id, String value, {String style = 'body'}) =>
      PluginControl(kind: PluginControlKind.text, id: id, props: {'value': value, 'style': style});
  static PluginControl textField(String id, {String? label, String value = '', String? placeholder, bool enabled = true}) =>
      PluginControl(kind: PluginControlKind.textField, id: id, props: {
        'label': ?label,
        'value': value,
        'placeholder': ?placeholder,
        'enabled': enabled,
      });
  static PluginControl numberField(String id, {String? label, required num value, num? min, num? max, num? step, String? unit}) =>
      PluginControl(kind: PluginControlKind.numberField, id: id, props: {
        'label': ?label,
        'value': value,
        'min': ?min,
        'max': ?max,
        'step': ?step,
        'unit': ?unit,
      });
  static PluginControl boolField(String id, {String? label, required bool value}) =>
      PluginControl(kind: PluginControlKind.boolField, id: id, props: {'label': ?label, 'value': value});
  static PluginControl enumField(String id, {String? label, required String value, required List<(String, String)> options}) =>
      PluginControl(kind: PluginControlKind.enumField, id: id, props: {
        'label': ?label,
        'value': value,
        'options': [for (final (v, l) in options) {'value': v, 'label': l}],
      });
  static PluginControl button(String id, String text, {String tone = 'neutral', bool enabled = true}) =>
      PluginControl(kind: PluginControlKind.button, id: id, props: {'text': text, 'tone': tone, 'enabled': enabled});
  static PluginControl progress(String id, {double? value, String? text}) =>
      PluginControl(kind: PluginControlKind.progress, id: id, props: {'value': value, 'text': ?text});
  static PluginControl log(String id, List<String> lines) =>
      PluginControl(kind: PluginControlKind.log, id: id, props: {'lines': lines});
  static PluginControl divider(String id) => PluginControl(kind: PluginControlKind.divider, id: id);
}

/// A user action in a rendered spec. [kind] is `changed`, `pressed`,
/// `submitted` or `picked`.
class PluginViewEvent {
  const PluginViewEvent({required this.viewId, required this.controlId, required this.kind, this.value});

  final String viewId;
  final String controlId;
  final String kind;
  final Object? value;

  Map<String, Object?> toJson() => {'viewId': viewId, 'controlId': controlId, 'kind': kind, 'value': value};

  static PluginViewEvent fromJson(Map<String, Object?> json) => PluginViewEvent(
        viewId: json['viewId'] as String,
        controlId: json['controlId'] as String,
        kind: json['kind'] as String,
        value: json['value'],
      );
}

/// Changes to some controls of a rendered view without resending it.
class PluginViewPatch {
  const PluginViewPatch(this.ops);

  final List<PluginViewPatchOp> ops;

  Map<String, Object?> toJson() => {'ops': [for (final o in ops) o.toJson()]};

  static PluginViewPatch fromJson(Map<String, Object?> json) =>
      PluginViewPatch([for (final o in (json['ops'] as List?) ?? const []) PluginViewPatchOp.fromJson((o as Map).cast())]);
}

/// Sets props of [controlId] (merged), or replaces the control whole.
class PluginViewPatchOp {
  const PluginViewPatchOp.set(this.controlId, this.set) : replace = null;
  const PluginViewPatchOp.replace(this.controlId, PluginControl this.replace) : set = const {};

  final String controlId;
  final Map<String, Object?> set;
  final PluginControl? replace;

  Map<String, Object?> toJson() => {
        'id': controlId,
        if (replace != null) 'replace': replace!.toJson() else 'set': set,
      };

  static PluginViewPatchOp fromJson(Map<String, Object?> json) {
    final id = json['id'] as String;
    final r = json['replace'];
    if (r is Map) return PluginViewPatchOp.replace(id, PluginControl.fromJson(r.cast()));
    return PluginViewPatchOp.set(id, (json['set'] as Map?)?.cast<String, Object?>() ?? const {});
  }
}

/// What a [PluginControlKind.preview3d] shows: meshes by file, their
/// transforms (centimetres, Z up, degrees), a camera and lights. The host
/// renders it in its own viewport; a plugin process never holds an engine.
class PluginSceneSpec {
  const PluginSceneSpec({this.nodes = const [], this.cameraDistance, this.cameraTarget});

  final List<PluginSceneNode> nodes;
  final double? cameraDistance;
  final List<double>? cameraTarget;

  Map<String, Object?> toJson() => {
        'nodes': [for (final n in nodes) n.toJson()],
        'cameraDistance': ?cameraDistance,
        'cameraTarget': ?cameraTarget,
      };

  static PluginSceneSpec fromJson(Map<String, Object?> json) => PluginSceneSpec(
        nodes: [for (final n in (json['nodes'] as List?) ?? const []) PluginSceneNode.fromJson((n as Map).cast())],
        cameraDistance: (json['cameraDistance'] as num?)?.toDouble(),
        cameraTarget: (json['cameraTarget'] as List?)?.map((e) => (e as num).toDouble()).toList(),
      );
}

class PluginSceneNode {
  const PluginSceneNode({
    required this.name,
    required this.meshPath,
    this.location = const [0, 0, 0],
    this.rotation = const [0, 0, 0],
    this.scale = const [1, 1, 1],
    this.jointLocalPose,
  });

  final String name;

  /// Absolute path of a `.glb` / `.lmas` mesh the host can load.
  final String meshPath;
  final List<double> location;
  final List<double> rotation;
  final List<double> scale;

  /// Optional skeleton pose: joint name → local TRS (as `Plugin3DViewportOptions.jointLocalPose`).
  final Map<String, List<double>>? jointLocalPose;

  Map<String, Object?> toJson() => {
        'name': name,
        'meshPath': meshPath,
        'location': location,
        'rotation': rotation,
        'scale': scale,
        'jointLocalPose': ?jointLocalPose,
      };

  static PluginSceneNode fromJson(Map<String, Object?> json) {
    List<double> vec(Object? v, List<double> d) => v is List ? [for (final e in v) (e as num).toDouble()] : d;
    final pose = json['jointLocalPose'];
    return PluginSceneNode(
      name: json['name'] as String,
      meshPath: json['meshPath'] as String,
      location: vec(json['location'], const [0, 0, 0]),
      rotation: vec(json['rotation'], const [0, 0, 0]),
      scale: vec(json['scale'], const [1, 1, 1]),
      jointLocalPose: pose is Map
          ? {for (final e in pose.entries) e.key as String: vec(e.value, const [])}
          : null,
    );
  }
}
