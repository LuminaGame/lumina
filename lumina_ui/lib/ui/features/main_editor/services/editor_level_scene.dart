import 'package:flutter/foundation.dart';
import 'package:flutter_filament/flutter_filament.dart' show FilamentCamera, FilamentEngine, FilamentScene;

/// The level viewport's Filament scene, published so another view can draw
/// the same level (the Sequencer's viewport renders it through a camera of
/// its own) instead of building a second copy of it.
///
/// Valid only while it is the current value of
/// `EditorViewModel.levelScene`: the level viewport clears that before it
/// frees the scene, and a view drawing it must stop then.
@immutable
class EditorLevelScene {
  const EditorLevelScene({required this.engine, required this.scene, required this.camera});

  /// The shared engine the scene lives on.
  final FilamentEngine engine;

  final FilamentScene scene;

  /// The level viewport's camera. Its exposure is metered from the level's
  /// lights, so another view of the level renders at the same exposure.
  final FilamentCamera camera;
}
