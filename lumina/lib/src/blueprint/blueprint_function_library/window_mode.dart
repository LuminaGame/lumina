part of '../blueprint_function_library.dart';

/// [LuminaBlueprintFunctionLibrary.callShapes]: the game window's mode.
const Map<String, LuminaBlueprintCallShape> _windowModeCallShapes = <String, LuminaBlueprintCallShape>{
  'set_fullscreen_mode': LuminaBlueprintCallShape('setFullscreenMode', ['mode'], self: true),
  'get_fullscreen_mode':
      LuminaBlueprintCallShape('getFullscreenMode', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'toggle_fullscreen': LuminaBlueprintCallShape('toggleFullscreen', [], self: true),
};

/// [LuminaBlueprintFunctionLibrary.builtInFunctions]: the game window's mode.
final Map<String, LuminaBlueprintFunction> _windowModeFunctions = <String, LuminaBlueprintFunction>{
  'set_fullscreen_mode': (c, i) {
    LuminaBlueprintFunctionLibrary.setFullscreenMode(c.self, i['mode']?.toString() ?? 'Borderless Fullscreen');
    return const {};
  },
  'get_fullscreen_mode': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getFullscreenMode(c.self)),
  'toggle_fullscreen': (c, i) {
    LuminaBlueprintFunctionLibrary.toggleFullscreen(c.self);
    return const {};
  },
};

/// `Set Fullscreen Mode`: `Windowed` or `Borderless Fullscreen` (also
/// `Fullscreen`); anything else is logged and ignored.
void _setFullscreenMode(LuminaActor self, [String mode = 'Borderless Fullscreen']) {
  final parsed = LuminaWindowMode.parse(mode);
  if (parsed == null) {
    developer.log('Set Fullscreen Mode: unknown mode "$mode" (Windowed, Borderless Fullscreen).', name: 'Blueprint');
    return;
  }
  unawaited(LuminaGameWindow.setMode(parsed));
}

String _getFullscreenMode(LuminaActor self) => LuminaGameWindow.mode.value.label;

void _toggleFullscreen(LuminaActor self) => unawaited(LuminaGameWindow.toggle());
