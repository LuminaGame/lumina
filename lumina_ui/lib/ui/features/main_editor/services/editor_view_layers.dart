import 'package:flutter_filament/flutter_filament.dart' show FilamentEngine, FilamentRenderableManager, FilamentView;

/// Filament visibility layers of the level's scene, so each view of it draws
/// only what belongs in that view: the level viewport draws the editor's
/// helpers, a camera preview (or a Sequencer view locked to a camera) shows
/// what the camera sees and nothing else.
///
/// A renderable is drawn by a view when its layer mask and the view's visible
/// layers share a bit. Everything nobody tags (sky, landscape, the Play
/// world's meshes) stays on Filament's default layer, [content].
class EditorViewLayers {
  const EditorViewLayers._();

  /// The level's content nobody tags: sky, landscape, environment.
  static const int content = 0x01;

  /// The editor's helpers: grid, transform gizmo, selection boxes, light /
  /// capsule / volume wires and the Wireframe mode's edge lines.
  static const int helpers = 0x02;

  /// The level viewport's actor meshes (the filled surfaces). The Wireframe
  /// view mode hides this layer from the level viewport only, so another
  /// view of the scene still draws the solids.
  static const int solids = 0x04;

  /// The level viewport's own transform gizmo (sized for the level
  /// viewport's camera): another editor view of the scene (the Sequencer's)
  /// draws a gizmo of its own instead.
  static const int gizmo = 0x08;

  /// Every layer this class assigns.
  static const int all = content | helpers | solids | gizmo;

  /// The level viewport in Lit and Unlit.
  static const int levelViewport = content | helpers | solids | gizmo;

  /// The level viewport in Wireframe: the edge lines stand in for the solids.
  static const int levelViewportWireframe = content | helpers | gizmo;

  /// Another editor view of the level (the Sequencer's viewport): the
  /// helpers without the level viewport's gizmo.
  static const int editorView = content | helpers | solids;

  /// What a camera sees: no editor helpers.
  static const int cameraView = content | solids;

  /// Shows [layers] in [view] (the others of [all] hidden).
  static void show(FilamentView view, int layers) => view.setVisibleLayers(all, layers);

  /// Puts each renderable of [entities] on [layer] alone; entities without a
  /// renderable component (a glTF's transform nodes) are skipped.
  static void tag(FilamentEngine engine, Iterable<int> entities, int layer) {
    final rm = FilamentRenderableManager(engine);
    for (final e in entities) {
      if (rm.hasComponent(e)) rm.setLayerMask(e, all, layer);
    }
  }
}
