import 'package:lumina_editor_api/lumina_editor_api.dart' show EditorIslandDividers, EditorIslandThemeData;
import 'package:shadcn_flutter/shadcn_flutter.dart' show BuildContext, Widget;

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

// The islands are the plugin API's (lumina_editor_api), so Lumina Studio's
// panels and plugin panels are one component.
export 'package:lumina_editor_api/lumina_editor_api.dart'
    show
        EditorIsland,
        EditorIslandDividers,
        EditorIslandGround,
        EditorIslandHeader,
        EditorIslandSectionLabel,
        EditorIslandStyle,
        EditorIslandTabHeader,
        EditorIslandThemeData,
        EditorTreeRowStyle;

/// The islands' theme in the editor: its live tokens, so every island (a
/// plugin's too) follows a theme switch. [luminaEditorTheme] installs it.
const EditorIslandThemeData luminaIslandTheme = EditorIslandThemeData(
  island: EditorColors.sidebar,
  ground: EditorColors.background,
  border: EditorColors.border,
  fieldBorder: EditorColors.fieldBorder,
  foreground: EditorColors.foreground,
  secondaryForeground: EditorColors.secondaryForeground,
  mutedForeground: EditorColors.mutedForeground,
  muted: EditorColors.muted,
  primary: EditorColors.primary,
  primaryForeground: EditorColors.primaryForeground,
  rowHover: EditorColors.rowHover,
  uiFamily: EditorTypography.uiFamily,
  monoFamily: EditorTypography.monoFamily,
);

/// The grip under a pane that brings its own ground gutter.
Widget? editorIslandGroundGrip(BuildContext context) => EditorIslandDividers.groundGrip(context);
