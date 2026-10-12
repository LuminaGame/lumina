[Türkçe](../../../tr/lumina_ui/sub-editors/cloth-settings.md)

# Cloth settings editor

A cloth settings asset (`.lmas`, `AssetType.clothSettings`) holds the settings several cloths share: mass, stiffness, bending, damping, friction, thickness, iterations, gravity, wind drag and turbulence, inertia scale and teleport thresholds, and self-collision. Its payload is a `LuminaClothSettingsDocument` (lumina_core) as JSON; the keys are the cloth component's property keys. A Cloth or Skinned Cloth component that names the asset in **Cloth Settings** (`clothSettingsAsset`) takes these values in place of its own when it is built (see [Cloth](../../lumina/cloth.md)).

| Topic | Files |
| :--- | :--- |
| Document | `lumina_core/lib/src/formats/lumina_cloth_settings_document.dart` |
| View model | `lib/ui/features/sub_editors/view_models/cloth_settings_editor_view_model.dart` |
| View | `lib/ui/features/sub_editors/views/cloth_settings/cloth_settings_sub_editor.dart` |

## Creating one

Content Browser → New Asset → **Physics → Cloth Settings (.lmas)** writes `contents/physics/NewAsset_N.lmas` with the cloth component's defaults and lists it with the shirt icon. Double-clicking it opens the editor (sub-editor category `ClothSettings`).

## The editor

- **Toolbar**: the asset's name (a `*` while there are unsaved changes), **Revert** (back to the saved values) and **Save** (writes the `.lmas`, keeping its id, thumbnail and references). A read or write error is shown in the toolbar.
- **Left panel** (resizable, 160 to 360 px): the setting groups: Material, Simulation, Wind, Motion and Self Collision, with how many settings each holds.
- **Right panel**: the selected group's settings. Numbers are a slider plus a typed field (with their unit), clamped to the ranges of `LuminaClothSettingsDocument.ranges`; iterations are whole numbers; self-collision is a switch. Every field resets to its default.

The file is read and written asynchronously; the tab binds to the editor's save prompt like the other asset editors.

## Using it

In the Blueprint editor's Details panel, a Cloth or Skinned Cloth component's **Cloth Settings** field picks the asset (only cloth settings assets are offered). The component mapping passes the reference through in Play-In-Editor and generated games alike. A cloth that cannot read the asset keeps its own settings and logs why.

---

[Up: Sub-editors](index.md)
