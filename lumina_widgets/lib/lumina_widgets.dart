/// The Flutter side of a Lumina game, on top of the engine (`lumina`):
/// - [LuminaGameWidget], which hosts the Filament view and drives the game
///   loop, and [LuminaGameHost], a whole game screen with keyboard, pointer
///   and mouse-capture input bridged into the world;
/// - the HUD overlay and the on-screen `Print String` lines;
/// - UMG: the runtime widgets, their element bindings and the widget layer
///   the Blueprints add widgets to;
/// - media players (media_kit) and the UMG media widgets;
/// - the web build's loading screen glue ([LuminaWebLoading]);
/// - Flutter views of the engine's pure observables (`asValueListenable()`,
///   `asListenable()`) and [LuminaWidgets.ensureInitialized], which hands the
///   engine Flutter's platform, asset bundle and video player.
///
/// Games import `package:lumina_widgets/lumina_game.dart`, which adds the
/// engine runtime.
library;

export 'package:lumina_widgets/src/foundation/observable_adapters.dart';
export 'package:lumina_widgets/src/game/game_host.dart';
export 'package:lumina_widgets/src/game/hud_overlay.dart';
export 'package:lumina_widgets/src/game/lumina_widget.dart';
export 'package:lumina_widgets/src/lumina_widgets_binding.dart';
export 'package:lumina_widgets/src/media/media.dart';
export 'package:lumina_widgets/src/umg/element_binding.dart';
export 'package:lumina_widgets/src/umg/theme_document_colors.dart';
export 'package:lumina_widgets/src/umg/umg_widgets.dart';
export 'package:lumina_widgets/src/umg/widget_layer.dart';
export 'package:lumina_widgets/src/utility/web_loading.dart';
