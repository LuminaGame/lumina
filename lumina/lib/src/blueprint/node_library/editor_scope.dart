part of '../node_library.dart';

// --- Editor panels: the editor scope -------------------------------------

/// The node categories that act on the game: the player, its pawn, camera
/// and input, level travel and level events, save games, user settings,
/// ragdolls, montages, damage and world queries. An editor panel's scripts
/// live in a private headless world, so these would act on nothing (or on
/// the wrong world); they are never offered in editor scope.
const List<String> _gameOnlyCategoryRoots = [
  'Game',
  'Input',
  'Save Game',
  'Settings',
  'Pawn',
  'Character',
  'Camera',
  'Physics|Ragdoll',
  'Animation|Montage',
  'Actor|Damage',
  'Level Events',
  'Level Actors',
  'Collision|Trace',
  'Self|View',
];

/// Game-only nodes outside those categories.
const Set<String> _gameOnlyIds = {
  'spawn_actor_from_class',
  'get_all_actors_of_class',
  'quit_game',
  'execute_console_command',
  LuminaBlueprintNodeLibrary.enhancedInputAction,
  LuminaBlueprintNodeLibrary.loadStreamLevel,
  LuminaBlueprintNodeLibrary.loadLevel,
  LuminaBlueprintNodeLibrary.changeLevel,
  LuminaBlueprintNodeLibrary.loadAndChangeLevel,
  LuminaBlueprintNodeLibrary.asyncSaveGameToSlot,
  LuminaBlueprintNodeLibrary.createSaveGameObject,
  LuminaBlueprintNodeLibrary.setSaveField,
  LuminaBlueprintNodeLibrary.getSaveField,
  LuminaBlueprintNodeLibrary.getGameMode,
};

bool _isGameOnly(LuminaBlueprintNodeSpec spec) {
  if (_gameOnlyIds.contains(spec.id)) return true;
  for (final root in _gameOnlyCategoryRoots) {
    if (spec.category == root || spec.category.startsWith('$root|')) return true;
  }
  return false;
}

/// Why [node] breaks the editor-scope rules of [context], or null: an
/// editor-only node outside an editor panel, a game-only node inside one, a
/// node needing a capability the panel does not declare, or a game graph
/// creating an editor panel's widget class.
String? _editorScopeError(LuminaBlueprintNode node, LuminaBlueprintNodeSpec spec, LuminaBlueprintTypeContext context) {
  if (!context.isEditorScope) {
    if (spec.editorOnly) return '${spec.title} can only be placed in an editor panel.';
    if (spec.id == 'create_widget') {
      final cls = node.literals['class'];
      final name = cls is String ? (LuminaBlueprintObjectClass.isClassString(cls) ? LuminaBlueprintObjectClass.name(cls) : cls) : null;
      if (name != null && name.isNotEmpty && _isEditorPanelClass(name, context)) {
        return "${node.title}: '$name' is an editor panel; game graphs cannot create it (editor panels never ship in a game).";
      }
    }
    return null;
  }
  if (_isGameOnly(spec)) return '${node.title} acts on the game and cannot be placed in an editor panel.';
  final capability = spec.editorCapability;
  if (capability != null && !context.editorCapabilities!.contains(capability)) {
    return "${node.title} needs the '$capability' capability, which this editor panel does not declare "
        '(Class Settings ▸ Editor Panel ▸ Capabilities).';
  }
  return null;
}

bool _isEditorPanelClass(String name, LuminaBlueprintTypeContext context) {
  for (final c in context.widgetClasses) {
    if (c.name == name) return c.isEditorPanel;
  }
  return LuminaWidgetClassRegistry.lookup(name)?.isEditorPanel ?? false;
}
