[Türkçe](../../../tr/lumina_ui/sub-editors/garment.md)

# Garment editor

A garment asset (`.lmas`, `AssetType.garment`) makes any mesh wearable: it names the **source mesh** the garment is made of (a static or skeletal mesh), the **reference body** it is authored on (a skeletal mesh), where the source mesh sits on that body (location in cm, rotation in degrees applied X then Y then Z, scale; in the body mesh's own space: Y up, cm), named **landmarks** (a point on the garment and its point on the body), the **thickness** the fitted garment keeps from the skin, the **slot** it fills (`Torso`, `Legs`, `Feet`, …) and whether it is worn as a **skinned cloth** with a Cloth Settings asset. Its payload is a `LuminaGarmentDocument` (lumina_core) as JSON. Fitting it to other bodies is done by the engine (see [Character slots](../../lumina/character-slots.md)).

| Topic | Files |
| :--- | :--- |
| Document | `lumina_core/lib/src/formats/lumina_garment_document.dart` |
| Picking and alignment math | `lumina_core/lib/src/garment/garment_math.dart` (`LuminaGarmentMath.raycast`, `fitSimilarity`, Euler ↔ quaternion) |
| View model | `lib/ui/features/sub_editors/view_models/garment_editor_view_model.dart` |
| View | `lib/ui/features/sub_editors/views/garment/` (`garment_sub_editor.dart`, details, landmarks and viewport parts; barrel `garment.dart`) |
| 3D scene | `lib/ui/features/sub_editors/services/garment_preview_scene.dart` |

## Creating one

Content Browser → New Asset → **Character → Garment (.lmas)** writes `contents/characters/NewAsset_N.lmas` (Torso, 0.5 cm, no meshes yet) and lists it with the shirt icon. Double-clicking it opens the editor (sub-editor category `Garment`).

## The editor

- **Toolbar**: the asset's name (`*` while unsaved), **Move / Rotate / Resize** (the gizmo's modes), **Pick on garment / Pick on body** (where a click in the viewport places the selected landmark), **Align**, **Revert**, **Save**. Errors (an unreadable mesh) show in the toolbar.
- **Left panel** (resizable, 200 to 460 px): Source Mesh, Reference Body and Preview On (another body: the garment is shown fitted to it, refitted 0.4 s after each edit settles, the fit's depth inside and time in the viewport's stats; not saved; landmarks are placed on the reference body only) pickers with thumbnails; Slot; Thickness; Simulate as cloth and its Cloth Settings; Settle After Fit (cloth settle steps run with every fit, 0 = none); the placement as Location / Rotation / Scale rows.
- **Viewport**: the body at the origin and the garment at its placement in an editor world; the gizmo moves, turns and resizes the garment (its drag writes the placement); landmark crosses are drawn over the scene (garment points amber, body points cyan, a line between each pair, the selected one larger). In a pick mode the gizmo hides and a click casts the camera's ray (`SubEditor3DViewport.onRayTap`): on the placed garment it sets the selected landmark's garment point (stored back in the source mesh's space, so it stays put when the garment moves), on the body its body point.
- **Right panel** (resizable, 180 to 420 px): **Add a landmark…** lists the presets not placed yet (Neck, Shoulder L/R, Elbow L/R, Wrist L/R, Chest, Waist, Hip L/R, Knee L/R, Ankle L/R, Foot L/R); a custom name can be added too. Each landmark is a 24 px tree row (chevron, a pin that turns cyan when both points are placed, the distance between them once placed, delete) with its Garment and Body points under it; clicking a point row selects the landmark and switches to that pick mode.
- **Align** places the garment so its landmarks land on the body's: the best similarity (uniform scale, rotation, translation) over the complete pairs; with fewer than three pairs the rotation is kept and only scale and translation are fitted.

Meshes are read and parsed on worker isolates (Draco-compressed sources decode there too) and cached; a pick runs on the cached triangles. The project's mesh and cloth settings lists are scanned on a worker isolate as well. The tab binds to the editor's save prompt like the other asset editors.
