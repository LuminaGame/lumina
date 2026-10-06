[Türkçe](../../../tr/lumina_ui/sub-editors/theme.md)

# Theme Sub-Editor

The Theme Sub-Editor allows developers to author, customize, and preview UI Themes (`.lmas` files with `AssetType.theme`).

Lumina decouples the editor's own desktop UI theme from game widget themes. Every project automatically maintains a default theme asset at `contents/themes/DefaultTheme.lmas` (seeded from shadcn dark tokens). Opening any theme `.lmas` from the Content Browser launches the Theme Sub-Editor.

## Layout and Panels

The editor interface consists of two synchronized panels:

1. **Left Panel: Theme Objects Tree & Inspector**
   - **Tree Hierarchy**:
     - *Global Tokens*: Color Palette, Geometry & Radius, Typography.
     - *Component Styles*: Button, Card, Input, Badge, Switch, Slider, Checkbox, Tabs, Progress, Dialog.
     - *Custom Styles*: Named custom style variants authored in the theme.
   - **Property Inspector**: Displays editable properties for whichever object or component is currently selected in the tree (colors with hex preview, numeric sliders, padding, font sizes, etc.).

2. **Right Panel: Live Preview Showcase**
   - Renders a live visual showcase of all UI components inheriting colors and metrics from the theme.
   - **"Create Style" Button**: If a component does not yet have a dedicated style override defined in the theme tree, a prominent "Create [Component] Style" button is shown below its preview card. Clicking this button creates the style override immediately and selects it in the left inspector.
   - **Custom Named Styles**: A dedicated section displays custom authored styles with instant edit buttons.

## Architecture

- **View**: `ThemeSubEditor` (`lib/ui/features/sub_editors/views/theme/theme_sub_editor.dart`), split modularly into `theme_tree_panel.dart`, `theme_property_inspector.dart`, `theme_preview_showcase.dart`, `theme_preview_components.dart`, and `theme_custom_style_dialog.dart`.
- **View Model**: `ThemeEditorViewModel` (`lib/ui/features/sub_editors/view_models/theme_editor_view_model.dart`).
- **Data Layer**: `LuminaThemeDocument` and `LuminaThemeService` in `package:lumina`.

---

[Previous: Widget (UMG) designer](umg.md) | [Up: Sub-editors](index.md)
