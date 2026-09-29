/// Operating mode of a [LuminaWorld].
enum LuminaWorldType {
  game,
  editor,
  pie, // Play in Editor
  preview,
}

/// Behavioral capabilities and semantics for [LuminaWorldType].
extension LuminaWorldTypeX on LuminaWorldType {
  /// Whether gameplay lifecycle (e.g. `onBeginPlay`, `onTick` for actors) executes.
  bool get runsGameplay => this == LuminaWorldType.game || this == LuminaWorldType.pie;

  /// Whether world subsystems receive tick notifications during frame updates.
  bool get ticksSubsystems => this != LuminaWorldType.preview;

  /// Whether the post-physics render prep phase is active for scene updates.
  bool get runsRenderPrep => true;

  /// Whether the world is running inside an editor environment (editor or PIE).
  bool get isEditorWorld => this == LuminaWorldType.editor || this == LuminaWorldType.pie;
}
