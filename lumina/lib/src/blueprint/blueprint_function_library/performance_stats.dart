part of '../blueprint_function_library.dart';

/// [LuminaBlueprintFunctionLibrary.callShapes]: GPU memory, render
/// resolution, and the player controller's cursor and input mode.
const Map<String, LuminaBlueprintCallShape> _performanceStatsCallShapes = <String, LuminaBlueprintCallShape>{
  'get_gpu_memory_usage':
      LuminaBlueprintCallShape('getGpuMemoryUsage', [], self: true, outputs: ['used_mb', 'budget_mb', 'available']),
  'get_render_resolution': LuminaBlueprintCallShape('getRenderResolution', [], self: true, outputs: ['width', 'height']),
  'get_show_mouse_cursor':
      LuminaBlueprintCallShape('getShowMouseCursor', ['target'], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'get_input_mode': LuminaBlueprintCallShape('getInputMode', ['target'], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
};

/// [LuminaBlueprintFunctionLibrary.builtInFunctions]: GPU memory, render
/// resolution, and the player controller's cursor and input mode.
final Map<String, LuminaBlueprintFunction> _performanceStatsFunctions = <String, LuminaBlueprintFunction>{
  'get_gpu_memory_usage': (c, i) {
    final r = _getGpuMemoryUsage(c.self);
    return {'used_mb': r.usedMb, 'budget_mb': r.budgetMb, 'available': r.available};
  },
  'get_render_resolution': (c, i) {
    final r = _getRenderResolution(c.self);
    return {'width': r.width, 'height': r.height};
  },
  'get_show_mouse_cursor': (c, i) => LuminaBlueprintFunctionLibrary._ret(_getShowMouseCursor(c.self, i['target'])),
  'get_input_mode': (c, i) => LuminaBlueprintFunctionLibrary._ret(_getInputMode(c.self, i['target'])),
};

/// The device-local GPU memory this process uses and the budget the driver
/// grants it, in MiB, as `VK_EXT_memory_budget` reports it for the GPU the
/// world renders on. `available` is false without a native engine, on
/// OpenGL, the noop backend and the web, and on a device without the
/// extension (both numbers are 0 then).
({double usedMb, double budgetMb, bool available}) _getGpuMemoryUsage(LuminaActor self) {
  final engine = self.world?.filamentEngineOrNull;
  if (engine == null) return (usedMb: 0.0, budgetMb: 0.0, available: false);
  try {
    final memory = engine.gpuMemory;
    if (memory == null) return (usedMb: 0.0, budgetMb: 0.0, available: false);
    return (usedMb: memory.usageMiB, budgetMb: memory.budgetMiB, available: true);
  } on StateError {
    // The engine was disposed while the world still refers to it.
    return (usedMb: 0.0, budgetMb: 0.0, available: false);
  }
}

/// What the GPU renders the scene at, in physical pixels: the screen
/// resolution (Get Screen Resolution) times the view's dynamic resolution
/// scale of the last frame (the upscaler's quality and the resolution
/// scale), rounded; the screen resolution when no view is bound.
({int width, int height}) _getRenderResolution(LuminaActor self) {
  final screen = _getScreenResolution(self);
  final view = self.world?.filamentViewOrNull;
  if (view == null) return screen;
  try {
    final (sx, sy) = view.lastDynamicResolutionScale;
    if (!(sx > 0.0) || !(sy > 0.0)) return screen;
    return (width: (screen.width * sx).round(), height: (screen.height * sy).round());
  } on StateError {
    return screen;
  }
}

/// The controller a getter reads: resolved like the setters' Target, but
/// silently (a getter has nothing to undo, so no warning).
LuminaPlayerController? _readControllerTarget(LuminaActor self, Object? target) {
  final resolved = target ?? _getPlayerController(self);
  if (resolved is LuminaPlayerController) return resolved;
  if (resolved is LuminaPawn && resolved.controller is LuminaPlayerController) {
    return resolved.controller! as LuminaPlayerController;
  }
  return null;
}

/// Whether the player controller shows the mouse cursor; false without one.
bool _getShowMouseCursor(LuminaActor self, [Object? target]) =>
    _readControllerTarget(self, target)?.bShowMouseCursor ?? false;

/// `GameOnly`, `GameAndUI` or `UIOnly`; `GameOnly` without a player
/// controller.
String _getInputMode(LuminaActor self, [Object? target]) => _readControllerTarget(self, target)?.inputMode ?? 'GameOnly';
