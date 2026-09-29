import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../core/plugin_extension_registry.dart';
import '../../../core/theme/editor_theme.dart';

/// The plugin buttons of one named [slot]. The row rebuilds
/// when plugins register; each button rebuilds only on its own state.
class EditorSlotBar extends StatelessWidget {
  final PluginExtensionRegistry registry;
  final EditorSlot slot;

  /// The status bar's size: 10 px icons, 9 px labels.
  final bool compact;

  /// Space before and after the buttons, only when the slot has any.
  final double leadingGap;
  final double trailingGap;

  const EditorSlotBar({
    super.key,
    required this.registry,
    required this.slot,
    this.compact = false,
    this.leadingGap = 0,
    this.trailingGap = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: registry,
      builder: (context, _) {
        final buttons = registry.slotButtons(slot);
        if (buttons.isEmpty) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: leadingGap),
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              _SlotButton(entry: buttons[i], compact: compact),
            ],
            SizedBox(width: trailingGap),
          ],
        );
      },
    );
  }
}

/// The theme colour of [tone].
Color editorToneColor(EditorTone tone) => switch (tone) {
      EditorTone.neutral => EditorColors.foreground,
      EditorTone.primary => EditorColors.primary,
      EditorTone.success => EditorColors.logSuccess,
      EditorTone.warning => EditorColors.logWarning,
      EditorTone.destructive => EditorColors.destructive,
    };

class _SlotButton extends StatelessWidget {
  final RegisteredSlotButton entry;
  final bool compact;

  const _SlotButton({required this.entry, required this.compact});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EditorButtonState>(
      valueListenable: entry.button.state,
      builder: (context, state, _) => _build(context, state),
    );
  }

  Widget _build(BuildContext context, EditorButtonState state) {
    final id = entry.effectiveId;
    final button = entry.button;
    final canRun = state.enabled && button.command.canExecute();
    final toneColor = editorToneColor(state.tone);
    final color = canRun ? toneColor : EditorColors.mutedForeground;
    // Active with no tone of its own reads as "on" in the accent colour.
    final activeColor = state.tone == EditorTone.neutral ? EditorColors.primary : toneColor;
    final iconSize = compact ? 10.0 : 13.0;
    final fontSize = compact ? 9.0 : 10.0;

    final frame = Container(
      key: ValueKey('slot_button_frame_$id'),
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: compact ? 0 : 2),
      decoration: BoxDecoration(
        color: state.active ? activeColor.withValues(alpha: 0.18) : null,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: state.active ? activeColor : const Color(0x00000000)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.busy)
            SizedBox(
              width: iconSize,
              height: iconSize,
              child: CircularProgressIndicator(strokeWidth: 1.6, color: toneColor),
            )
          else
            Icon(state.icon, size: iconSize, color: color),
          if (state.label != null) ...[
            const SizedBox(width: 4),
            Text(state.label!, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: color)),
          ],
        ],
      ),
    );

    final badged = state.badge == null
        ? frame
        : Stack(
            clipBehavior: Clip.none,
            children: [
              frame,
              Positioned(
                top: compact ? -3 : -5,
                right: -5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  constraints: const BoxConstraints(minWidth: 10),
                  decoration: BoxDecoration(color: activeColor, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    state.badge!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 7, height: 1.3, fontWeight: FontWeight.bold, color: EditorColors.background),
                  ),
                ),
              ),
            ],
          );

    return Tooltip(
      key: ValueKey('slot_button_$id'),
      tooltip: (_) => TooltipContainer(child: Text(state.tooltip)),
      child: Builder(
        builder: (buttonContext) => GhostButton(
          density: ButtonDensity.compact,
          onPressed: canRun ? () => _press(buttonContext) : null,
          child: badged,
        ),
      ),
    );
  }

  void _press(BuildContext context) {
    final menu = entry.button.menu;
    if (menu == null) {
      entry.button.command.execute(context);
      return;
    }
    showDropdown(
      context: context,
      builder: (_) => DropdownMenu(
        children: [
          for (final command in menu)
            MenuButton(
              key: ValueKey('slot_menu_${command.id}'),
              leading: command.icon != null ? Icon(command.icon, size: 12) : null,
              onPressed: command.canExecute() ? (_) => command.execute(context) : null,
              child: Text(
                command.label,
                style: TextStyle(fontSize: 10, color: command.canExecute() ? null : EditorColors.mutedForeground),
              ),
            ),
        ],
      ),
    );
  }
}
