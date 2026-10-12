import 'dart:io';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:lumina_editor_data/lumina_editor.dart';

/// A group of cloth settings the editor lists on its left.
class ClothSettingsSection {
  const ClothSettingsSection(this.id, this.label, this.keys);

  final String id;
  final String label;

  /// The setting keys (`LuminaClothSettingsDocument` property keys).
  final List<String> keys;
}

/// View model for the Cloth Settings editor: one cloth settings `.lmas`
/// (a `LuminaClothSettingsDocument`), edited and saved in place.
class ClothSettingsEditorViewModel extends ChangeNotifier {
  ClothSettingsEditorViewModel({required this.assetPath});

  /// The `.lmas` file edited.
  final String assetPath;

  static const List<ClothSettingsSection> sections = [
    ClothSettingsSection('material', 'Material', ['massKg', 'stiffness', 'bendStiffness', 'damping', 'friction', 'thickness']),
    ClothSettingsSection('simulation', 'Simulation', ['iterations', 'gravityScale']),
    ClothSettingsSection('wind', 'Wind', ['windDrag', 'windTurbulence']),
    ClothSettingsSection('motion', 'Motion', ['inertiaScale', 'teleportDistance', 'teleportRotation']),
    ClothSettingsSection('collision', 'Self Collision', ['selfCollision', 'selfCollisionDistance']),
  ];

  /// A setting's label and unit.
  static const Map<String, (String, String?)> labels = {
    'massKg': ('Mass', 'kg'),
    'stiffness': ('Stiffness', null),
    'bendStiffness': ('Bend Stiffness', null),
    'damping': ('Damping', null),
    'friction': ('Friction', null),
    'thickness': ('Thickness', 'cm'),
    'iterations': ('Iterations', null),
    'gravityScale': ('Gravity Scale', 'x'),
    'windDrag': ('Wind Drag', '1/s'),
    'windTurbulence': ('Wind Turbulence', null),
    'inertiaScale': ('Inertia Scale', null),
    'teleportDistance': ('Teleport Distance', 'cm'),
    'teleportRotation': ('Teleport Rotation', 'deg'),
    'selfCollision': ('Self Collision', null),
    'selfCollisionDistance': ('Self Collision Distance', 'cm'),
  };

  LuminaClothSettingsDocument _doc = const LuminaClothSettingsDocument();
  LuminaClothSettingsDocument _saved = const LuminaClothSettingsDocument();
  bool _loaded = false;
  String? _error;
  String _section = sections.first.id;
  bool _disposed = false;

  LuminaClothSettingsDocument get doc => _doc;
  bool get isLoaded => _loaded;
  bool get isDirty => _doc != _saved;

  /// Why the asset could not be read or written (null when it could).
  String? get error => _error;

  /// The section shown on the right.
  String get selectedSection => _section;
  ClothSettingsSection get section => sections.firstWhere((s) => s.id == _section);

  void selectSection(String id) {
    if (id == _section || !sections.any((s) => s.id == id)) return;
    _section = id;
    _notify();
  }

  /// Reads the asset (defaults when it does not exist yet).
  Future<void> load() async {
    try {
      final file = File(assetPath);
      if (await file.exists()) {
        _doc = LuminaClothSettingsDocument.fromAsset(LuminaAsset.fromBytes(await file.readAsBytes()));
      }
      _error = null;
    } catch (e) {
      _error = 'Cannot read $assetPath: $e';
    }
    _saved = _doc;
    _loaded = true;
    _notify();
  }

  /// A setting's value (a number, or a bool for `selfCollision`).
  Object valueOf(String key) => _doc.toProperties()[key]!;

  /// The default a setting resets to.
  Object defaultOf(String key) => const LuminaClothSettingsDocument().toProperties()[key]!;

  void set(String key, Object value) {
    final next = _doc.withValue(key, value);
    if (next == _doc) return;
    _doc = next;
    _notify();
  }

  void reset(String key) => set(key, defaultOf(key));

  void revert() {
    _doc = _saved;
    _notify();
  }

  /// Writes the asset; false (with [error]) when it cannot be written.
  Future<bool> save() async {
    try {
      final file = File(assetPath);
      await file.parent.create(recursive: true);
      final name = file.uri.pathSegments.last.replaceAll('.lmas', '');
      // Keep the asset's id and thumbnail when it has them.
      LuminaAsset? existing;
      if (await file.exists()) {
        try {
          existing = LuminaAsset.fromBytes(await file.readAsBytes());
        } catch (_) {}
      }
      final asset = _doc.toAsset(name: name, assetId: existing?.assetId);
      final bytes = existing == null
          ? asset.toProtoBufferBytes()
          : LuminaAsset(
              assetId: asset.assetId,
              name: name,
              type: AssetType.clothSettings,
              hasThumbnail: existing.hasThumbnail,
              thumbnailPng: existing.thumbnailPng,
              rawPayload: asset.rawPayload,
              references: existing.references,
              metadata: existing.metadata,
            ).toProtoBufferBytes();
      await file.writeAsBytes(bytes);
      _saved = _doc;
      _error = null;
      _notify();
      return true;
    } catch (e) {
      _error = 'Cannot save $assetPath: $e';
      _notify();
      return false;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
