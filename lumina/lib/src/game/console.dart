import 'dart:developer' as developer;

import '../world/world.dart';
import 'lumina_game.dart';

/// A console command: the arguments after the command name and the world it
/// runs against (null outside play).
typedef LuminaConsoleCommand = void Function(List<String> args, LuminaWorld? world);

/// The tiny console registry `Execute Console Command` routes to:
/// `stat fps`, `quit`, `slomo <x>`, `open <level>` are built
/// in; a project registers its own with [register].
abstract final class LuminaConsole {
  static final Map<String, LuminaConsoleCommand> _registered = {};

  /// Whether `stat fps` turned the frame-rate readout on.
  static bool showFps = false;

  /// Adds (or replaces) the project command [name].
  static void register(String name, LuminaConsoleCommand command) => _registered[name.toLowerCase()] = command;

  static void unregister(String name) => _registered.remove(name.toLowerCase());

  /// Drops every project command; the built-ins stay.
  static void clearRegistered() {
    _registered.clear();
    showFps = false;
  }

  /// The built-in and registered command names.
  static List<String> get commandNames => ['stat', 'quit', 'slomo', 'open', ..._registered.keys];

  /// Runs [line] (`slomo 0.5`); true when a command handled it. Unknown
  /// commands are logged and return false.
  static bool execute(LuminaWorld? world, String line) {
    final parts = line.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return false;
    final name = parts.first.toLowerCase();
    final args = parts.sublist(1);
    final custom = _registered[name];
    if (custom != null) {
      custom(args, world);
      return true;
    }
    switch (name) {
      case 'stat':
        if (args.isNotEmpty && args.first.toLowerCase() == 'fps') {
          showFps = !showFps;
          if (world != null) {
            if (showFps) {
              world.addScreenMessage('stat fps', 'FPS ${world.frameRate.toStringAsFixed(0)}', duration: double.infinity);
            } else {
              world.screenMessages.remove('stat fps');
            }
          }
          return true;
        }
        developer.log("stat: unknown group '${args.join(' ')}'.", name: 'LuminaConsole');
        return false;
      case 'quit':
      case 'exit':
        LuminaGame.requestQuit();
        return true;
      case 'slomo':
        final factor = args.isEmpty ? 1.0 : double.tryParse(args.first);
        if (factor == null || factor < 0.0) {
          developer.log("slomo: '${args.join(' ')}' is not a time dilation.", name: 'LuminaConsole');
          return false;
        }
        world?.timeDilation = factor;
        return true;
      case 'open':
        if (args.isEmpty) return false;
        final target = args.join(' ');
        final q = target.indexOf('?');
        LuminaGame.requestOpenLevel(q < 0 ? target : target.substring(0, q), q < 0 ? '' : target.substring(q + 1));
        return true;
    }
    developer.log("Unknown console command '$name'.", name: 'LuminaConsole');
    return false;
  }
}
