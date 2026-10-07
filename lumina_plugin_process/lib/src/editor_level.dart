import 'package:lumina_core/lumina_core.dart' show ChangeSignal;

/// One component of a placed actor, as a plugin sees it.
class EditorComponentSnapshot {
  final String id;
  final String type;
  final String name;
  final bool enabled;
  final Map<String, dynamic> properties;

  const EditorComponentSnapshot({
    required this.id,
    required this.type,
    required this.name,
    this.enabled = true,
    this.properties = const {},
  });
}

/// A placed actor, as a plugin sees it.
///
/// The transform is the stored one, exactly as the Details panel shows it:
/// centimetres, **Z up**. [meshAssetPath]
/// is the absolute path of the mesh the actor renders (null for non-mesh
/// actors). Snapshots are immutable copies: edit through [EditorLevelAccess].
class EditorActorSnapshot {
  final String id;
  final String name;
  final String type;
  final String? parentId;
  final List<double> location;
  final List<double> rotation;
  final List<double> scale;
  final bool isVisible;
  final String? meshAssetPath;
  final List<EditorComponentSnapshot> components;

  const EditorActorSnapshot({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
    required this.location,
    required this.rotation,
    required this.scale,
    this.isVisible = true,
    this.meshAssetPath,
    this.components = const [],
  });

  /// The first component of [type], or null.
  EditorComponentSnapshot? componentOfType(String type) {
    for (final c in components) {
      if (c.type == type) return c;
    }
    return null;
  }
}

/// A component a plugin asks the host to attach to a new actor.
class EditorComponentSpec {
  final String type;
  final String name;
  final Map<String, dynamic> properties;

  const EditorComponentSpec({
    required this.type,
    required this.name,
    this.properties = const {},
  });
}

/// An actor a plugin asks the host to place: same units and axes as
/// [EditorActorSnapshot]. [id] is optional; the host assigns one otherwise.
/// A `StaticMesh` spec with a [meshAssetPath] (absolute path of a `.glb` /
/// `.lmas` under the project) renders that mesh in the viewport, plays in
/// PIE and is generated into the game like any hand-placed mesh actor.
class EditorActorSpec {
  final String? id;
  final String name;
  final String type;
  final String? parentId;
  final List<double> location;
  final List<double> rotation;
  final List<double> scale;
  final String? meshAssetPath;
  final List<EditorComponentSpec> components;

  const EditorActorSpec({
    this.id,
    required this.name,
    required this.type,
    this.parentId,
    required this.location,
    this.rotation = const [0.0, 0.0, 0.0],
    this.scale = const [1.0, 1.0, 1.0],
    this.meshAssetPath,
    this.components = const [],
  });
}

/// What a plugin can read and do on the open level, shared by the editor's
/// own view of it (`EditorLevelAccess` in `lumina_editor_api`, whose
/// `changes` is a Flutter `Listenable`) and a plugin process's
/// ([PluginLevelAccess], whose `changes` is a pure [ChangeSignal]).
///
/// Every edit is an undoable editor transaction and marks the level dirty,
/// exactly like the same edit made through the Outliner or the Details
/// panel; nothing here bypasses the host's transaction, dirty-flag or
/// auto-save path.
abstract class EditorLevelOperations {
  /// Absolute path of the open project's directory.
  String get projectDirPath;

  /// The active level's `.lmas`, relative to [projectDirPath]
  /// (`contents/levels/L_Main.lmas`).
  String get activeLevelPath;

  /// Every actor in the level, in outliner order.
  List<EditorActorSnapshot> get actors;

  /// The selected actors' ids, in selection order.
  List<String> get selectedActorIds;

  /// Places [specs] as one undoable transaction and returns their ids, in
  /// order. Mesh actors have their geometry loaded before they are added.
  Future<List<String>> addActors(List<EditorActorSpec> specs, {String? label});

  /// Runs [body] so that every level edit it makes is one undo step labelled
  /// [label]: an assistant turn, a scatter, a batch rename. A
  /// call inside another joins it.
  Future<T> runTransaction<T>(String label, Future<T> Function() body);

  /// The label of the step Edit ▸ Undo would revert now, or null when there
  /// is none (e.g. an assistant's "Undo this turn").
  String? get undoTopLabel;

  /// Undoes the newest step only when its label is [label]; false (nothing
  /// changes) when another step is on top or nothing can be undone.
  bool undoIfTop(String label);

  /// Removes the actors with [ids] (and their children) as one undoable
  /// transaction.
  void removeActors(Iterable<String> ids, {String? label});

  /// Sets [propertyId] on the first component of [componentType] on the
  /// actor with [actorId], as an undoable transaction.
  void setComponentProperty(
    String actorId,
    String componentType,
    String propertyId,
    Object? value, {
    String? label,
  });

  /// Selects exactly [ids].
  void selectActors(Iterable<String> ids);

  /// Saves the level to disk and regenerates the game's level code, the
  /// same path as File → Save Level.
  Future<void> saveLevel();

  /// Opens the asset at [assetPath] (absolute, or relative to
  /// [projectDirPath]) in its editor: a plugin asset type opens through the
  /// handler registered with `LuminaEditorContext.registerAssetType`.
  void openAssetEditor(String assetPath);

  /// Opens the level at [relativePath] (project-relative, e.g. a level the
  /// plugin wrote under `contents/levels/`) in the viewport and the
  /// Outliner, like File → Open Level. The open level's unsaved changes are
  /// saved first. When [relativePath] is already the open level it is read
  /// again from disk, so a plugin that rewrote the file sees the new
  /// contents; call [saveLevel] before rewriting it to keep its unsaved
  /// changes. [show] brings the level viewport to the front. Returns false,
  /// changing nothing, when there is no such file or Play-In-Editor runs.
  Future<bool> openLevel(String relativePath, {bool show = true});

  /// Writes a line to the editor's Output Log.
  void log(String message, {String level = 'info', String source = 'Plugin'});
}

/// The open level as a plugin process sees it (`PluginProcessContext.level`):
/// [EditorLevelOperations] plus a pure [changes] signal. A Flutter shell
/// gets the same level as an `EditorLevelAccess` (`asEditorLevelAccess()` in
/// `lumina_editor_api`).
abstract class PluginLevelAccess implements EditorLevelOperations {
  /// Notifies after any change to the level (actors, selection, save).
  ChangeSignal get changes;
}
