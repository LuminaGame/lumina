/// Dart FFI bindings for Google Filament 3D rendering engine.
///
/// This library provides a high-level, idiomatic Dart API for creating
/// 3D scenes and rendering them using the Filament engine on macOS and Linux.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:flutter_filament/flutter_filament.dart';
///
/// void main() {
///   final engine = FilamentEngine.create();
///   final renderer = engine.createRenderer();
///   final scene = engine.createScene();
///   final view = engine.createView();
///
///   view.scene = scene;
///   // ... configure camera, add renderables, etc.
///
///   engine.dispose();
/// }
/// ```
library;

export 'filament.dart';
export 'src/widget.dart';
