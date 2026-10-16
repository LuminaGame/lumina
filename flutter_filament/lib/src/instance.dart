/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

/// Zero-cost extension type representing a fast `TransformManager::Instance` handle.
///
/// Instance handles avoid repeated entity-to-component hash map lookups inside a burst of
/// calls. Since Filament 1.78 the TransformManager reorders its components during
/// `Renderer.endFrame` / `skipFrame`, so a handle is valid only until the end of the current
/// frame and until the next `create`, `destroy` or `setParent`: keep the entity and call
/// `FilamentTransformManager.getInstance` again instead of storing the handle.
extension type const TransformInstance(int handle) {
  /// Whether this handle references a valid transform component (non-zero).
  bool get isValid => handle != 0;
}

/// Zero-cost extension type representing a fast `RenderableManager::Instance` handle.
extension type const RenderableInstance(int handle) {
  /// Whether this handle references a valid renderable component (non-zero).
  bool get isValid => handle != 0;
}

/// Zero-cost extension type representing a fast `LightManager::Instance` handle.
extension type const LightInstance(int handle) {
  /// Whether this handle references a valid light component (non-zero).
  bool get isValid => handle != 0;
}
