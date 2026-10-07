import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';

/// Utilities for converting and resolving [LuminaThemeDocument] styles
/// within the UMG Designer canvas, inspector, and runtime views.
class UmgThemeHelper {
  const UmgThemeHelper._();

  /// Converts a [LuminaThemeDocument] into a shadcn_flutter [ThemeData].
  static ThemeData themeDataFromLuminaDoc(LuminaThemeDocument doc) {
    final bg = doc.colorOf('background', fallback: const Color(0xFF0F172A));
    final fg = doc.colorOf('foreground', fallback: const Color(0xFFF8FAFC));
    final cardBg = doc.colorOf('card', fallback: const Color(0xFF1E293B));
    final cardFg = doc.colorOf('cardForeground', fallback: fg);
    final popBg = doc.colorOf('popover', fallback: const Color(0xFF1E293B));
    final popFg = doc.colorOf('popoverForeground', fallback: fg);
    final pri = doc.colorOf('primary', fallback: const Color(0xFF3B82F6));
    final priFg = doc.colorOf('primaryForeground', fallback: const Color(0xFFFFFFFF));
    final sec = doc.colorOf('secondary', fallback: const Color(0xFF334155));
    final secFg = doc.colorOf('secondaryForeground', fallback: const Color(0xFFF8FAFC));
    final mut = doc.colorOf('muted', fallback: const Color(0xFF1E293B));
    final mutFg = doc.colorOf('mutedForeground', fallback: const Color(0xFF94A3B8));
    final acc = doc.colorOf('accent', fallback: sec);
    final accFg = doc.colorOf('accentForeground', fallback: secFg);
    final des = doc.colorOf('destructive', fallback: const Color(0xFFEF4444));
    final desFg = doc.colorOf('destructiveForeground', fallback: const Color(0xFFFFFFFF));
    final bdr = doc.colorOf('border', fallback: const Color(0xFF334155));
    final inp = doc.colorOf('input', fallback: const Color(0xFF334155));
    final rng = doc.colorOf('ring', fallback: pri);

    return ThemeData(
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        background: bg,
        foreground: fg,
        card: cardBg,
        cardForeground: cardFg,
        popover: popBg,
        popoverForeground: popFg,
        primary: pri,
        primaryForeground: priFg,
        secondary: sec,
        secondaryForeground: secFg,
        muted: mut,
        mutedForeground: mutFg,
        accent: acc,
        accentForeground: accFg,
        destructive: des,
        destructiveForeground: desFg,
        border: bdr,
        input: inp,
        ring: rng,
        chart1: EditorColors.chart1,
        chart2: EditorColors.chart2,
        chart3: EditorColors.chart3,
        chart4: EditorColors.chart4,
        chart5: EditorColors.chart5,
      ),
      radius: doc.radius,
    );
  }

  /// Resolves the active [LuminaThemeDocument] for a specific [UmgNode].
  /// If the node has an explicit `theme` property, that theme is looked up
  /// in [loadedThemes]. Otherwise, it falls back to [documentTheme] or [fallbackTheme].
  static LuminaThemeDocument resolveThemeForNode({
    required UmgNode node,
    required LuminaThemeDocument documentTheme,
    required Map<String, LuminaThemeDocument> loadedThemes,
    LuminaThemeDocument? fallbackTheme,
  }) {
    final overridePath = node.props['theme']?.toString();
    if (overridePath != null && overridePath.isNotEmpty) {
      final norm = overridePath.replaceAll('\\', '/');
      if (loadedThemes.containsKey(norm)) {
        return loadedThemes[norm]!;
      }
      for (final entry in loadedThemes.entries) {
        final k = entry.key.replaceAll('\\', '/');
        if (k == norm || k.endsWith(norm) || norm.endsWith(k.split('/').last)) {
          return entry.value;
        }
      }
    }
    return documentTheme;
  }

  /// Builds a themed [Button] for a UMG button node according to [theme].
  static Widget buildThemedButton({
    required UmgNode node,
    required LuminaThemeDocument theme,
    required VoidCallback? onPressed,
    required Widget child,
    ValueChanged<bool>? onHover,
  }) {
    final styleKey = node.props['style']?.toString() ?? 'primary';
    final customStyle = theme.customStyles[styleKey]?.style;
    final compStyle = theme.componentStyles['button'];

    Color bg;
    Color fg;
    double radius = customStyle?.borderRadius ?? compStyle?.borderRadius ?? theme.radius;
    Border? border;

    if (customStyle != null) {
      bg = customStyle.bgColor ?? theme.colorOf('primary');
      fg = customStyle.fgColor ?? theme.colorOf('primaryForeground');
      if (customStyle.borderColor != null) {
        border = Border.all(color: customStyle.bColor!, width: customStyle.borderWidth ?? 1.0);
      }
    } else {
      switch (styleKey) {
        case 'secondary':
          bg = theme.colorOf('secondary');
          fg = theme.colorOf('secondaryForeground');
          break;
        case 'outline':
          bg = const Color(0x00000000);
          fg = theme.colorOf('foreground');
          border = Border.all(color: theme.colorOf('border'));
          break;
        case 'ghost':
          bg = const Color(0x00000000);
          fg = theme.colorOf('foreground');
          break;
        case 'destructive':
          bg = theme.colorOf('destructive');
          fg = theme.colorOf('destructiveForeground');
          break;
        case 'primary':
        default:
          bg = compStyle?.bgColor ?? theme.colorOf('primary');
          fg = compStyle?.fgColor ?? theme.colorOf('primaryForeground');
          break;
      }
    }

    // Explicit color override on the node itself
    final propColorStr = node.props['color']?.toString();
    if (propColorStr != null && propColorStr.isNotEmpty && propColorStr != '#FFFFFF' && propColorStr != '#ffffff') {
      try {
        final parsed = Color(int.parse(propColorStr.replaceFirst('#', '0xFF')));
        fg = parsed;
      } catch (_) {}
    }

    final padding = EdgeInsets.symmetric(
      horizontal: customStyle?.paddingHorizontal ?? compStyle?.paddingHorizontal ?? 16.0,
      vertical: customStyle?.paddingVertical ?? compStyle?.paddingVertical ?? 8.0,
    );

    // Build specialized ThemeData for this button variant
    final buttonTheme = ThemeData(
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        background: theme.colorOf('background'),
        foreground: fg,
        card: theme.colorOf('card'),
        cardForeground: fg,
        popover: theme.colorOf('popover'),
        popoverForeground: fg,
        primary: bg,
        primaryForeground: fg,
        secondary: theme.colorOf('secondary'),
        secondaryForeground: theme.colorOf('secondaryForeground'),
        muted: theme.colorOf('muted'),
        mutedForeground: theme.colorOf('mutedForeground'),
        accent: bg,
        accentForeground: fg,
        destructive: theme.colorOf('destructive'),
        destructiveForeground: theme.colorOf('destructiveForeground'),
        border: border?.top.color ?? theme.colorOf('border'),
        input: theme.colorOf('input'),
        ring: bg,
        chart1: EditorColors.chart1,
        chart2: EditorColors.chart2,
        chart3: EditorColors.chart3,
        chart4: EditorColors.chart4,
        chart5: EditorColors.chart5,
      ),
      radius: radius,
    );

    // Map styleKey to appropriate ButtonStyle variance
    ButtonStyle bStyle;
    switch (styleKey) {
      case 'secondary':
        bStyle = const ButtonStyle.secondary();
        break;
      case 'outline':
        bStyle = const ButtonStyle.outline();
        break;
      case 'ghost':
        bStyle = const ButtonStyle.ghost();
        break;
      case 'destructive':
        bStyle = const ButtonStyle.destructive();
        break;
      case 'primary':
      default:
        bStyle = const ButtonStyle.primary();
        break;
    }

    return Theme(
      data: buttonTheme,
      child: Container(
        decoration: border != null
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: border,
              )
            : null,
        child: Button(
          style: bStyle,
          onPressed: onPressed,
          onHover: onHover,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: (padding.horizontal - 32.0).clamp(0.0, 100.0),
              vertical: (padding.vertical - 16.0).clamp(0.0, 100.0),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  /// Builds a widget for picking the active document theme.
  static Widget buildDocumentThemePicker({
    required UmgEditorViewModel vm,
    bool compact = false,
  }) {
    return Builder(
      builder: (context) {
        final currentPath = vm.activeThemePath;
        final currentName = (currentPath == null || currentPath.isEmpty)
            ? vm.activeTheme.name
            : currentPath.split('/').last.replaceAll('.lmas', '');

        final availablePaths = vm.availableThemePaths.toList();
        if (availablePaths.isEmpty) {
          availablePaths.add('contents/themes/DefaultTheme.lmas');
        }

        final buttonContent = Row(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            const Icon(LucideIcons.palette, size: 11, color: EditorColors.assetTypeTheme),
            const SizedBox(width: 5),
            if (compact)
              Text(currentName, style: const TextStyle(fontSize: 9))
            else
              Expanded(child: Text(currentName, style: const TextStyle(fontSize: 9.5))),
            const SizedBox(width: 4),
            const Icon(LucideIcons.chevronDown, size: 9, color: EditorColors.mutedForeground),
          ],
        );

        return OutlineButton(
          key: const ValueKey('umg_document_theme_picker'),
          density: compact ? ButtonDensity.compact : ButtonDensity.normal,
          onPressed: () {
            showOverlay(
              context,
              const DialogConfiguration(),
              builder: (dialogContext) {
                return AlertDialog(
                  title: const Text('Select Widget Theme', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  content: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300, minWidth: 260),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: availablePaths.map((p) {
                          final name = p.split('/').last.replaceAll('.lmas', '');
                          final isSelected = (currentPath == p) ||
                              (currentPath == null && name == vm.activeTheme.name);
                          return GhostButton(
                            onPressed: () {
                              vm.setDocumentTheme(p);
                              closeOverlay(dialogContext);
                            },
                            child: Row(
                              children: [
                                Icon(
                                  LucideIcons.palette,
                                  size: 11,
                                  color: isSelected ? EditorColors.primary : EditorColors.mutedForeground,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? EditorColors.primary : EditorColors.foreground,
                                    ),
                                  ),
                                ),
                                if (isSelected) const Icon(LucideIcons.check, size: 12, color: EditorColors.primary),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  actions: [
                    GhostButton(
                      onPressed: () => closeOverlay(dialogContext),
                      child: const Text('Cancel', style: TextStyle(fontSize: 9)),
                    ),
                  ],
                );
              },
            );
          },
          child: buttonContent,
        );
      },
    );
  }

  /// Builds a widget for overriding the theme of a specific [node].
  static Widget buildNodeThemePicker({
    required UmgEditorViewModel vm,
    required UmgNode node,
  }) {
    return Builder(
      builder: (context) {
        final currentOverride = node.props['theme']?.toString();
        final hasOverride = currentOverride != null && currentOverride.isNotEmpty;
        final displayText = hasOverride
            ? currentOverride.split('/').last.replaceAll('.lmas', '')
            : '(Inherit: ${vm.activeTheme.name})';

        final availablePaths = vm.availableThemePaths.toList();
        if (availablePaths.isEmpty) {
          availablePaths.add('contents/themes/DefaultTheme.lmas');
        }

        return OutlineButton(
          key: ValueKey('umg_node_theme_picker_${node.id}'),
          onPressed: () {
            showOverlay(
              context,
              const DialogConfiguration(),
              builder: (dialogContext) {
                return AlertDialog(
                  title: const Text('Component Theme Override', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  content: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320, minWidth: 260),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Inherit option
                          GhostButton(
                            onPressed: () {
                              vm.setNodeTheme(node.id, null);
                              closeOverlay(dialogContext);
                            },
                            child: Row(
                              children: [
                                Icon(
                                  LucideIcons.undo,
                                  size: 11,
                                  color: !hasOverride ? EditorColors.primary : EditorColors.mutedForeground,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '(Inherit from Widget: ${vm.activeTheme.name})',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic,
                                      fontWeight: !hasOverride ? FontWeight.bold : FontWeight.normal,
                                      color: !hasOverride ? EditorColors.primary : EditorColors.foreground,
                                    ),
                                  ),
                                ),
                                if (!hasOverride) const Icon(LucideIcons.check, size: 12, color: EditorColors.primary),
                              ],
                            ),
                          ),
                          const Divider(),
                          ...availablePaths.map((p) {
                            final name = p.split('/').last.replaceAll('.lmas', '');
                            final isSelected = hasOverride && (currentOverride == p || currentOverride.endsWith(name) || p.endsWith(currentOverride));
                            return GhostButton(
                              onPressed: () {
                                vm.setNodeTheme(node.id, p);
                                closeOverlay(dialogContext);
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.palette,
                                    size: 11,
                                    color: isSelected ? EditorColors.primary : EditorColors.mutedForeground,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? EditorColors.primary : EditorColors.foreground,
                                      ),
                                    ),
                                  ),
                                  if (isSelected) const Icon(LucideIcons.check, size: 12, color: EditorColors.primary),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    GhostButton(
                      onPressed: () => closeOverlay(dialogContext),
                      child: const Text('Cancel', style: TextStyle(fontSize: 9)),
                    ),
                  ],
                );
              },
            );
          },
          child: Row(
            children: [
              Icon(
                LucideIcons.palette,
                size: 11,
                color: hasOverride ? EditorColors.assetTypeTheme : EditorColors.mutedForeground,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  displayText,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontStyle: hasOverride ? FontStyle.normal : FontStyle.italic,
                    color: hasOverride ? EditorColors.foreground : EditorColors.mutedForeground,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(LucideIcons.chevronDown, size: 9, color: EditorColors.mutedForeground),
            ],
          ),
        );
      },
    );
  }

  /// Builds a widget for picking the style of a button [node],
  /// including standard shadcn variants and custom styles from the active/overridden theme.
  static Widget buildButtonStylePicker({
    required UmgEditorViewModel vm,
    required UmgNode node,
  }) {
    return Builder(
      builder: (context) {
        final currentStyle = node.props['style']?.toString() ?? 'primary';
        final nodeTheme = vm.themeForNode(node);

        const standardStyles = ['primary', 'secondary', 'outline', 'ghost', 'destructive'];
        final customStyles = nodeTheme.customStyles.entries
            .where((e) => e.value.targetComponent == 'button' || e.value.targetComponent.isEmpty)
            .map((e) => e.key)
            .toList();

        final isCustom = customStyles.contains(currentStyle);

        return OutlineButton(
          key: ValueKey('umg_button_style_picker_${node.id}'),
          onPressed: () {
            showOverlay(
              context,
              const DialogConfiguration(),
              builder: (dialogContext) {
                return AlertDialog(
                  title: const Text('Select Button Style', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  content: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 340, minWidth: 260),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Text('Standard Styles', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
                          ),
                          ...standardStyles.map((s) {
                            final isSelected = currentStyle == s;
                            return GhostButton(
                              onPressed: () {
                                vm.setProp(node.id, 'style', s);
                                closeOverlay(dialogContext);
                              },
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      s,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? EditorColors.primary : EditorColors.foreground,
                                      ),
                                    ),
                                  ),
                                  if (isSelected) const Icon(LucideIcons.check, size: 12, color: EditorColors.primary),
                                ],
                              ),
                            );
                          }),
                          if (customStyles.isNotEmpty) ...[
                            const Divider(),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Text('Custom Styles (${nodeTheme.name})', style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
                            ),
                            ...customStyles.map((s) {
                              final isSelected = currentStyle == s;
                              return GhostButton(
                                onPressed: () {
                                  vm.setProp(node.id, 'style', s);
                                  closeOverlay(dialogContext);
                                },
                                child: Row(
                                  children: [
                                    const Icon(LucideIcons.sparkles, size: 11, color: EditorColors.assetTypeTheme),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        s,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected ? EditorColors.primary : EditorColors.foreground,
                                        ),
                                      ),
                                    ),
                                    if (isSelected) const Icon(LucideIcons.check, size: 12, color: EditorColors.primary),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    GhostButton(
                      onPressed: () => closeOverlay(dialogContext),
                      child: const Text('Cancel', style: TextStyle(fontSize: 9)),
                    ),
                  ],
                );
              },
            );
          },
          child: Row(
            children: [
              if (isCustom) ...[
                const Icon(LucideIcons.sparkles, size: 11, color: EditorColors.assetTypeTheme),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  currentStyle,
                  style: const TextStyle(fontSize: 9.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(LucideIcons.chevronDown, size: 9, color: EditorColors.mutedForeground),
            ],
          ),
        );
      },
    );
  }
}
