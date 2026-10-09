/// Web builds: the browser's screen and viewport in physical pixels. Only
/// compiled for the web (conditional import in `web_display_backend.dart`).
library;

import 'dart:js_interop';

extension type _Screen._(JSObject _) implements JSObject {
  external JSNumber get width;
  external JSNumber get height;
}

@JS('screen')
external _Screen? get _screen;

@JS('devicePixelRatio')
external JSNumber? get _devicePixelRatio;

@JS('innerWidth')
external JSNumber? get _innerWidth;

@JS('innerHeight')
external JSNumber? get _innerHeight;

double devicePixelRatio() {
  final r = _devicePixelRatio?.toDartDouble ?? 1.0;
  return r > 0 ? r : 1.0;
}

(int, int)? screenSize() {
  final s = _screen;
  if (s == null) return null;
  final r = devicePixelRatio();
  return ((s.width.toDartDouble * r).round(), (s.height.toDartDouble * r).round());
}

(int, int)? viewportSize() {
  final w = _innerWidth, h = _innerHeight;
  if (w == null || h == null) return null;
  final r = devicePixelRatio();
  return ((w.toDartDouble * r).round(), (h.toDartDouble * r).round());
}
