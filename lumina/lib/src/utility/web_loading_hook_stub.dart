/// Native builds: there is no HTML loading screen (see `web_loading.dart`).
library;

const bool isWeb = false;

void progress(double fraction, String label) {}

Future<void> loadRenderer() async {}
