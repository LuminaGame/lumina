/// The umbrella library for editor code (Lumina Studio and editor plugins):
/// the pure foundation (`lumina_core`), the engine (`lumina`), the game's
/// Flutter side (`lumina_widgets`: game widget, HUD, UMG, media), the editor
/// data layer (`lumina_editor_data`) and the native importers it drives
/// (Assimp, RigLogic).
///
/// It replaces `package:lumina/lumina.dart` in editor code: since the data
/// layer left the engine, `lumina.dart` exports the engine only. Generated
/// games import `package:lumina_widgets/lumina_game.dart`.
library;

export 'package:flutter_assimp/flutter_assimp.dart';
export 'package:flutter_riglogic/flutter_riglogic.dart';
export 'package:lumina/lumina.dart';
export 'package:lumina_core/lumina_core.dart';
export 'package:lumina_editor_data/lumina_editor_data.dart';
export 'package:lumina_widgets/lumina_widgets.dart';
