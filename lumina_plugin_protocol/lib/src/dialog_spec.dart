import 'package:lumina_plugin_protocol/src/view_spec.dart';

/// What a plugin process asks the host to show: `dialog` (a form of
/// [body] controls with [actions]) or `confirm` (a message with confirm /
/// cancel actions).
abstract final class PluginDialogKind {
  static const String dialog = 'dialog';
  static const String confirm = 'confirm';

  static const List<String> all = [dialog, confirm];
}

/// The look of a dialog button: `primary`, `destructive` or `secondary`.
abstract final class PluginDialogTone {
  static const String primary = 'primary';
  static const String destructive = 'destructive';
  static const String secondary = 'secondary';

  static const List<String> all = [primary, destructive, secondary];
}

/// One button of a [PluginDialogSpec]; pressing it closes the dialog and
/// answers its [id].
class PluginDialogAction {
  const PluginDialogAction({required this.id, required this.label, this.tone = PluginDialogTone.secondary});

  final String id;
  final String label;

  /// [PluginDialogTone]; an unknown tone reads as `secondary`.
  final String tone;

  Map<String, Object?> toJson() => {'id': id, 'label': label, 'tone': tone};

  static PluginDialogAction fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final label = json['label'];
    if (id is! String || id.isEmpty) throw const FormatException('plugin dialog action: "id" must be a non-empty string');
    if (label is! String) throw const FormatException('plugin dialog action: "label" must be a string');
    final tone = json['tone'];
    return PluginDialogAction(
      id: id,
      label: label,
      tone: tone is String && PluginDialogTone.all.contains(tone) ? tone : PluginDialogTone.secondary,
    );
  }
}

/// A modal dialog a plugin process opens over the editor
/// (`host.showDialog`). [body] holds the same controls a declarative panel
/// does; their values come back in [PluginDialogResult.values] by control
/// id. The host shows at most one dialog per plugin at a time (a second
/// request waits) and answers when the user closes it.
class PluginDialogSpec {
  const PluginDialogSpec({
    required this.id,
    required this.title,
    this.kind = PluginDialogKind.dialog,
    this.body = const [],
    this.actions = const [],
    this.dismissible = true,
  });

  /// A `confirm` dialog: [message], then Cancel and [confirmLabel]
  /// (destructive when [destructive]). Its answer's action is `confirm` or
  /// `cancel` (null when dismissed).
  factory PluginDialogSpec.confirm({
    required String id,
    required String title,
    required String message,
    String confirmLabel = 'OK',
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) =>
      PluginDialogSpec(
        id: id,
        title: title,
        kind: PluginDialogKind.confirm,
        body: [PluginControl.text('message', message)],
        actions: [
          PluginDialogAction(id: 'cancel', label: cancelLabel),
          PluginDialogAction(
            id: 'confirm',
            label: confirmLabel,
            tone: destructive ? PluginDialogTone.destructive : PluginDialogTone.primary,
          ),
        ],
      );

  /// Unique per plugin while it is open; `host.closeDialog` names it.
  final String id;
  final String title;

  /// [PluginDialogKind].
  final String kind;
  final List<PluginControl> body;

  /// The buttons, left to right; none shows a single Close.
  final List<PluginDialogAction> actions;

  /// Escape (and a click outside) closes it, answered with a null action.
  final bool dismissible;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'kind': kind,
        'body': [for (final c in body) c.toJson()],
        'actions': [for (final a in actions) a.toJson()],
        'dismissible': dismissible,
      };

  /// Throws a [FormatException] naming the field that is missing or wrong.
  static PluginDialogSpec fromJson(Map<String, Object?> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) throw const FormatException('plugin dialog: "id" must be a non-empty string');
    final kind = json['kind'] ?? PluginDialogKind.dialog;
    if (kind is! String || !PluginDialogKind.all.contains(kind)) {
      throw FormatException('plugin dialog: "kind" must be one of ${PluginDialogKind.all.join(', ')}, got "$kind"');
    }
    final title = json['title'];
    if (title is! String) throw const FormatException('plugin dialog: "title" must be a string');
    final body = json['body'] ?? const [];
    final actions = json['actions'] ?? const [];
    if (body is! List) throw const FormatException('plugin dialog: "body" must be a list of controls');
    if (actions is! List) throw const FormatException('plugin dialog: "actions" must be a list');
    return PluginDialogSpec(
      id: id,
      title: title,
      kind: kind,
      body: [for (final c in body) PluginControl.fromJson((c as Map).cast())],
      actions: [for (final a in actions) PluginDialogAction.fromJson((a as Map).cast())],
      dismissible: json['dismissible'] != false,
    );
  }
}

/// The answer to `host.showDialog`: the pressed action's id (null when the
/// dialog was dismissed, closed by `host.closeDialog`, or its plugin
/// process stopped) and the body controls' values by control id.
class PluginDialogResult {
  const PluginDialogResult({this.action, this.values = const {}});

  /// Dismissed: no action, no values.
  static const PluginDialogResult dismissed = PluginDialogResult();

  final String? action;
  final Map<String, Object?> values;

  bool get isDismissed => action == null;

  Map<String, Object?> toJson() => {'action': action, 'values': values};

  static PluginDialogResult fromJson(Object? json) {
    if (json is! Map) return dismissed;
    final action = json['action'];
    final values = json['values'];
    return PluginDialogResult(
      action: action is String ? action : null,
      values: values is Map ? values.cast<String, Object?>() : const {},
    );
  }
}
