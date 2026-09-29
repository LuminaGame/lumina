/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

/// Zero-cost extension type representing a fast, cached `TransformManager::Instance` handle.
///
/// Instance handles avoid repeated entity-to-component hash map lookups inside high-frequency
/// frame loops. An instance handle is valid within a frame but may be invalidated across
/// component additions / deletions.
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
