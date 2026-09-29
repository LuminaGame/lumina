import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show IconData;

import 'editor_command.dart';

/// A named place in the editor chrome a plugin button goes.
enum EditorSlot {
  /// The level toolbar, right of the Blueprints ▾ dropdown.
  levelToolbarAfterBlueprints,

  /// The level toolbar's right block, left of the Quality button.
  levelToolbarEnd,

  /// The status bar, after the actor counts.
  statusBarLeft,

  /// The status bar, before the "Shaders compiled · Quality · … · RHI" text.
  statusBarRight,
}

/// A button's colour as a theme role, never a hex value: the host maps it to
/// the active editor theme (`foreground`, `primary`, `logSuccess`,
/// `logWarning`, `destructive`).
enum EditorTone { neutral, primary, success, warning, destructive }

/// What a slot button shows right now. The plugin replaces it through the
/// button's [EditorSlotButton.state] notifier; only that button repaints.
@immutable
class EditorButtonState {
  /// Text beside the icon; null shows the icon only.
  final String? label;
  final IconData icon;
  final String tooltip;
  final EditorTone tone;

  /// False disables the button (so does the command's `canExecute`).
  final bool enabled;

  /// The pressed / toggled-on look, e.g. while the plugin's panel is open.
  final bool active;

  /// A short pill at the top-right ("3", "●"); null shows none.
  final String? badge;

  /// A spinner in place of the icon, e.g. while a model loads. The button
  /// stays clickable.
  final bool busy;

  const EditorButtonState({
    required this.icon,
    required this.tooltip,
    this.label,
    this.tone = EditorTone.neutral,
    this.enabled = true,
    this.active = false,
    this.badge,
    this.busy = false,
  });

  /// A copy with the given fields replaced. [label] and [badge] cannot be
  /// cleared here; use [withoutLabel] / [withoutBadge].
  EditorButtonState copyWith({
    String? label,
    IconData? icon,
    String? tooltip,
    EditorTone? tone,
    bool? enabled,
    bool? active,
    String? badge,
    bool? busy,
  }) =>
      EditorButtonState(
        label: label ?? this.label,
        icon: icon ?? this.icon,
        tooltip: tooltip ?? this.tooltip,
        tone: tone ?? this.tone,
        enabled: enabled ?? this.enabled,
        active: active ?? this.active,
        badge: badge ?? this.badge,
        busy: busy ?? this.busy,
      );

  EditorButtonState get withoutLabel => EditorButtonState(
      icon: icon, tooltip: tooltip, tone: tone, enabled: enabled, active: active, badge: badge, busy: busy);

  EditorButtonState get withoutBadge => EditorButtonState(
      label: label, icon: icon, tooltip: tooltip, tone: tone, enabled: enabled, active: active, busy: busy);

  @override
  bool operator ==(Object other) =>
      other is EditorButtonState &&
      other.label == label &&
      other.icon == icon &&
      other.tooltip == tooltip &&
      other.tone == tone &&
      other.enabled == enabled &&
      other.active == active &&
      other.badge == badge &&
      other.busy == busy;

  @override
  int get hashCode => Object.hash(label, icon, tooltip, tone, enabled, active, badge, busy);
}

/// A plugin button in a named [slot], registered with
/// `LuminaEditorContext.registerSlotButton`. The host namespaces [id] as
/// `<pluginName>.<id>` and refuses a second button with the same one.
class EditorSlotButton {
  final String id;
  final EditorSlot slot;

  /// Sorts buttons within the slot; lower first, ties keep registration
  /// order.
  final int order;

  /// The live look; the plugin keeps the notifier and updates it.
  final ValueListenable<EditorButtonState> state;

  /// Runs on click, unless [menu] is given.
  final EditorCommand command;

  /// When set, a click opens a dropdown of these commands instead.
  final List<EditorCommand>? menu;

  const EditorSlotButton({
    required this.id,
    required this.slot,
    required this.state,
    required this.command,
    this.order = 0,
    this.menu,
  });
}
