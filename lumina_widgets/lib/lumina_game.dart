/// What a Lumina game imports: the engine runtime
/// (`package:lumina/lumina_runtime.dart`), its Flutter side
/// (`package:lumina_widgets/lumina_widgets.dart`: the game widget and host,
/// input, HUD, UMG, media, web loading) and pointer capture
/// (`package:lumina_mouse_capture`). The code generator writes this import
/// into every generated game file.
library;

export 'package:lumina/lumina_runtime.dart';
export 'package:lumina_mouse_capture/lumina_mouse_capture.dart';
export 'package:lumina_widgets/lumina_widgets.dart';
