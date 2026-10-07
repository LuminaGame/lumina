/// Web builds: the page's HTML loading screen (`web/loading.js`, generated
/// from the project's Web Loading Style) and flutter_filament's WebAssembly
/// module. Only compiled for the web (conditional import in
/// `web_loading.dart`).
library;

import 'dart:js_interop';

import 'package:flutter_filament/flutter_filament.dart' show FilamentWeb;

const bool isWeb = true;

extension type _LuminaLoadingJs._(JSObject _) implements JSObject {
  external void progress(JSNumber fraction, JSString label);
}

@JS('luminaLoading')
external _LuminaLoadingJs? get _luminaLoading;

/// Reports to `window.luminaLoading.progress`; a page without the loading
/// screen (a hand-written index.html) is left alone.
void progress(double fraction, String label) {
  _luminaLoading?.progress(fraction.toJS, label.toJS);
}

/// Downloads and instantiates the renderer's WebAssembly module.
Future<void> loadRenderer() => FilamentWeb.ensureInitialized();
