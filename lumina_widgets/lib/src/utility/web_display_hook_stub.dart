/// Native builds: there is no browser screen (see `web_display_backend.dart`).
library;

(int, int)? screenSize() => null;

(int, int)? viewportSize() => null;

double devicePixelRatio() => 1.0;
