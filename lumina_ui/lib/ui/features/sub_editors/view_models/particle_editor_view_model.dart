import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina_ui/ui/features/sub_editors/models/particle_system_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/particle_preview_scene.dart';

/// View model of the Particle sub-editor.
///
/// Owns a [ParticleSystemDocument] — a named list of
/// [LuminaParticleEmitterConfig]s — loaded from and saved into a PARTICLE
/// `.lmas` through the real `LuminaAsset` container, plus the live preview:
/// one real [LuminaParticleSystemComponent] per *enabled* emitter, built with
/// a fixed [previewSeed] so the simulation is reproducible frame for frame.
///
/// There is no editor-side particle simulator: [activeParticleCount],
/// [sampleColorAt] and [sampleSizeAt] all read the engine types directly, so
/// what the editor shows is what the runtime will do.
class ParticleEditorViewModel extends ChangeNotifier {
  /// Path of the PARTICLE `.lmas` on disk.
  final String assetPath;

  /// Project root (`…/<Project>`), used to resolve mesh picks and references.
  final String? projectDirPath;

  /// Fixed simulation seed — deterministic preview (and smoke screenshots).
  final int previewSeed;

  /// One preview tick as taken by `Step Frame`.
  static const double frameSeconds = 1.0 / 60.0;

  static const double minSimSpeed = 0.1;
  static const double maxSimSpeed = 2.0;

  final ParticlePreviewScene preview;
  final AssetRepository _assetRepo = AssetRepository();
  final EngineLoggerService _logger = EngineLoggerService();

  ParticleSystemDocument _document = ParticleSystemDocument.createDefault();
  LuminaAsset? _asset;
  String _onDiskJson = '';
  bool _loaded = false;
  bool _dirty = false;
  bool _disposed = false;
  int _selected = 0;

  List<RealAssetInfo> _availableMeshes = const [];

  /// Rejected edits (a value the config may never hold, e.g. `maxParticles 0`)
  /// surface as inline errors without corrupting the document.
  final Map<String, String> _rejected = {};

  // --- playback ---
  bool _isPlaying = false;
  double _simSpeed = 1.0;
  double _simTime = 0.0;
  final List<LuminaParticleSystemComponent> _components = [];
  bool _componentsStale = true;

  ParticleEditorViewModel({
    required this.assetPath,
    this.projectDirPath,
    this.previewSeed = 1337,
    ParticlePreviewScene? preview,
  }) : preview = preview ?? ParticlePreviewScene();

  // --- document --------------------------------------------------------------

  bool get isLoaded => _loaded;
  bool get isDirty => _dirty;
  LuminaAsset? get asset => _asset;
  ParticleSystemDocument get document => _document;

  List<ParticleEmitterEntry> get emitters => List.unmodifiable(_document.emitters);
  List<ParticleEmitterEntry> get enabledEmitters => _document.emitters.where((e) => e.enabled).toList();

  int get selectedEmitterIndex => _selected;
  ParticleEmitterEntry get selectedEmitter => _document.emitters[_selected.clamp(0, _document.emitters.length - 1)];

  /// The selected emitter's immutable engine config.
  LuminaParticleEmitterConfig get config => selectedEmitter.config;

  List<RealAssetInfo> get availableMeshes => List.unmodifiable(_availableMeshes);

  String get fileBasename {
    final name = assetPath.split(Platform.pathSeparator).last;
    return name.endsWith('.lmas') ? name.substring(0, name.length - 5) : name;
  }

  /// The engine module this editor edits — no GPU compute, no node graph.
  static const String backendLabel = 'CPU emitter (LuminaParticleSystemComponent)';

  /// Reads the `.lmas`; a PARTICLE asset without a document starts from the
  /// engine defaults (Content Browser → New Particle System).
  void open() {
    try {
      final file = File(assetPath);
      if (file.existsSync()) {
        _asset = LuminaAsset.fromBytes(file.readAsBytesSync());
        final parsed = ParticleSystemDocument.tryParse(_asset!.metadata[ParticleSystemDocument.metadataKey]);
        _document = parsed ?? ParticleSystemDocument.createDefault();
      } else {
        _document = ParticleSystemDocument.createDefault();
      }
    } catch (e) {
      _logger.log('Failed to open $assetPath: $e', level: 'error', source: 'ParticleEditor');
      _document = ParticleSystemDocument.createDefault();
    }
    _onDiskJson = _document.toJsonString();
    _selected = 0;
    _loaded = true;
    _dirty = false;
    _componentsStale = true;
    _refreshMeshAssets();
    notifyListeners();
  }

  void _refreshMeshAssets() {
    final dir = projectDirPath;
    if (dir == null) {
      _availableMeshes = const [];
      return;
    }
    try {
      _availableMeshes = _assetRepo
          .scanProjectContents(dir)
          .where((a) => a.type == AssetType.filamesh || a.type == AssetType.filameshSk)
          .toList()
        ..sort((a, b) => a.relativePath.compareTo(b.relativePath));
    } catch (_) {
      _availableMeshes = const [];
    }
  }

  // --- validation ------------------------------------------------------------

  /// Inline field errors keyed by `spawnRate` / `maxParticles` / `lifetime` /
  /// `speed` / `duration` / `bursts`; empty when the document may be saved.
  Map<String, String> get errors {
    final e = <String, String>{..._rejected};
    for (var i = 0; i < _document.emitters.length; i++) {
      final entry = _document.emitters[i];
      final c = entry.config;
      final prefix = _document.emitters.length > 1 ? '${entry.name}: ' : '';
      if (c.maxParticles < 1) {
        e['maxParticles'] = '${prefix}maxParticles must be at least 1.';
      }
      if (c.lifetimeMin > c.lifetimeMax) {
        e['lifetime'] = '${prefix}lifetimeMin (${c.lifetimeMin}) must be <= lifetimeMax (${c.lifetimeMax}).';
      }
      if (c.lifetimeMin <= 0.0) {
        e['lifetime'] = '${prefix}lifetimeMin must be greater than 0.';
      }
      if (c.speedMin > c.speedMax) {
        e['speed'] = '${prefix}speedMin must be <= speedMax.';
      }
      if (c.spawnRate < 0.0) {
        e['spawnRate'] = '${prefix}spawnRate cannot be negative.';
      }
      if (c.duration <= 0.0) {
        e['duration'] = '${prefix}Loop Duration must be greater than 0.';
      }
      for (final b in c.bursts) {
        if (b.time < 0.0 || b.time >= c.duration) {
          e['bursts'] = '${prefix}burst time ${b.time}s must be within [0, ${c.duration}) — the loop period.';
        }
        if (b.count < 1) {
          e['bursts'] = '${prefix}burst count must be at least 1.';
        }
      }
    }
    return e;
  }

  String? errorFor(String field) => errors[field];

  bool get canSave => errors.isEmpty;

  // --- mutations -------------------------------------------------------------

  void _mutate(LuminaParticleEmitterConfig Function(LuminaParticleEmitterConfig c) fn, {bool rebuild = true}) {
    final entry = selectedEmitter;
    entry.config = fn(entry.config);
    _markDirty(rebuild: rebuild);
  }

  void _markDirty({bool rebuild = true}) {
    _dirty = _document.toJsonString() != _onDiskJson;
    if (rebuild) _componentsStale = true;
    if (rebuild) _resetPlayback();
    notifyListeners();
  }

  void setSpawnRate(double v) => _mutate((c) => copyEmitterConfig(c, spawnRate: v < 0 ? 0.0 : v));

  void setMaxParticles(int v) {
    if (v < 1) {
      // Rejected outright: a zero-slot pool would break the component.
      _rejected['maxParticles'] = 'maxParticles must be at least 1 — $v rejected.';
      notifyListeners();
      return;
    }
    _rejected.remove('maxParticles');
    _mutate((c) => copyEmitterConfig(c, maxParticles: v));
  }

  void setLifetimeMin(double v) => _mutate((c) => copyEmitterConfig(c, lifetimeMin: v));

  void setLifetimeMax(double v) => _mutate((c) => copyEmitterConfig(c, lifetimeMax: v));

  void setSpeedMin(double v) => _mutate((c) => copyEmitterConfig(c, speedMin: v));

  void setSpeedMax(double v) => _mutate((c) => copyEmitterConfig(c, speedMax: v));

  void setConeAngleDegrees(double v) =>
      _mutate((c) => copyEmitterConfig(c, coneAngleDegrees: v.clamp(0.0, 180.0)));

  void setInheritVelocityScale(Vector3 v) => _mutate((c) => copyEmitterConfig(c, inheritVelocityScale: v));

  void setGravity(Vector3 v) => _mutate((c) => copyEmitterConfig(c, gravity: v));

  void setDrag(double v) => _mutate((c) => copyEmitterConfig(c, drag: v));

  void setLooping(bool v) => _mutate((c) => copyEmitterConfig(c, looping: v));

  void setDuration(double v) => _mutate((c) => copyEmitterConfig(c, duration: v));

  // --- bursts ---

  void addBurst(double time, int count) => _mutate((c) {
        final bursts = List<LuminaParticleBurst>.from(c.bursts)..add(LuminaParticleBurst(time, count));
        bursts.sort((a, b) => a.time.compareTo(b.time));
        return copyEmitterConfig(c, bursts: bursts);
      });

  void removeBurst(int index) => _mutate((c) {
        if (index < 0 || index >= c.bursts.length) return c;
        final bursts = List<LuminaParticleBurst>.from(c.bursts)..removeAt(index);
        return copyEmitterConfig(c, bursts: bursts);
      });

  void setBurstTime(int index, double time) => _mutate((c) {
        if (index < 0 || index >= c.bursts.length) return c;
        final bursts = List<LuminaParticleBurst>.from(c.bursts);
        bursts[index] = LuminaParticleBurst(time, bursts[index].count);
        bursts.sort((a, b) => a.time.compareTo(b.time));
        return copyEmitterConfig(c, bursts: bursts);
      });

  void setBurstCount(int index, int count) => _mutate((c) {
        if (index < 0 || index >= c.bursts.length) return c;
        final bursts = List<LuminaParticleBurst>.from(c.bursts);
        bursts[index] = LuminaParticleBurst(bursts[index].time, count);
        return copyEmitterConfig(c, bursts: bursts);
      });

  // --- render stage ---

  void setBillboard(bool v) => _mutate((c) => copyEmitterConfig(
        c,
        billboard: v,
        clearMeshAssetPath: v,
      ));

  /// Picks a real FILAMESH `.lmas` as the emitter's mesh renderer. Storing the
  /// project-relative path keeps the reference portable; `null` restores the
  /// built-in billboard quad.
  void setMeshAsset(RealAssetInfo? mesh) {
    if (mesh == null) {
      setBillboard(true);
      return;
    }
    _mutate((c) => copyEmitterConfig(c, meshAssetPath: mesh.relativePath, billboard: false));
  }

  // --- gradient (colorOverLife) ---

  void addColorStop(double t, Vector4 rgba) => _mutate((c) {
        final stops = List<LuminaGradientStop>.from(c.colorOverLife)
          ..add(LuminaGradientStop(t.clamp(0.0, 1.0), rgba));
        stops.sort((a, b) => a.t.compareTo(b.t));
        return copyEmitterConfig(c, colorOverLife: stops);
      });

  void moveColorStop(int index, double t) => _mutate((c) {
        if (index < 0 || index >= c.colorOverLife.length) return c;
        final stops = List<LuminaGradientStop>.from(c.colorOverLife);
        stops[index] = LuminaGradientStop(t.clamp(0.0, 1.0), stops[index].rgba);
        stops.sort((a, b) => a.t.compareTo(b.t));
        return copyEmitterConfig(c, colorOverLife: stops);
      });

  void setColorStopRgba(int index, Vector4 rgba) => _mutate((c) {
        if (index < 0 || index >= c.colorOverLife.length) return c;
        final stops = List<LuminaGradientStop>.from(c.colorOverLife);
        stops[index] = LuminaGradientStop(stops[index].t, rgba);
        return copyEmitterConfig(c, colorOverLife: stops);
      });

  void removeColorStop(int index) => _mutate((c) {
        if (index < 0 || index >= c.colorOverLife.length) return c;
        final stops = List<LuminaGradientStop>.from(c.colorOverLife)..removeAt(index);
        return copyEmitterConfig(c, colorOverLife: stops);
      });

  // --- curve (sizeOverLife) ---

  void addSizePoint(double t, double scale) => _mutate((c) {
        final pts = List<LuminaCurvePoint>.from(c.sizeOverLife)
          ..add(LuminaCurvePoint(t.clamp(0.0, 1.0), scale));
        pts.sort((a, b) => a.t.compareTo(b.t));
        return copyEmitterConfig(c, sizeOverLife: pts);
      });

  void moveSizePoint(int index, double t, double scale) => _mutate((c) {
        if (index < 0 || index >= c.sizeOverLife.length) return c;
        final pts = List<LuminaCurvePoint>.from(c.sizeOverLife);
        pts[index] = LuminaCurvePoint(t.clamp(0.0, 1.0), scale);
        pts.sort((a, b) => a.t.compareTo(b.t));
        return copyEmitterConfig(c, sizeOverLife: pts);
      });

  void removeSizePoint(int index) => _mutate((c) {
        if (index < 0 || index >= c.sizeOverLife.length) return c;
        final pts = List<LuminaCurvePoint>.from(c.sizeOverLife)..removeAt(index);
        return copyEmitterConfig(c, sizeOverLife: pts);
      });

  /// Runtime-parity sampling: delegates to the engine config itself.
  Vector4 sampleColorAt(double t) => config.sampleColorAt(t);

  double sampleSizeAt(double t) => config.sampleSizeAt(t);

  // --- emitter list ----------------------------------------------------------

  void selectEmitter(int index) {
    if (index < 0 || index >= _document.emitters.length || index == _selected) return;
    _selected = index;
    notifyListeners();
  }

  void addEmitter(String name) {
    _document.emitters.add(ParticleEmitterEntry(
      name: _uniqueName(name),
      enabled: true,
      config: LuminaParticleEmitterConfig(),
    ));
    _selected = _document.emitters.length - 1;
    _markDirty();
  }

  void duplicateEmitter(int index) {
    if (index < 0 || index >= _document.emitters.length) return;
    final src = _document.emitters[index];
    final copy = src.clone()..name = _uniqueName('${src.name} Copy');
    _document.emitters.insert(index + 1, copy);
    _selected = index + 1;
    _markDirty();
  }

  void renameEmitter(int index, String name) {
    if (index < 0 || index >= _document.emitters.length) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _document.emitters[index].name = trimmed;
    _markDirty(rebuild: false);
  }

  void setEmitterEnabled(int index, bool enabled) {
    if (index < 0 || index >= _document.emitters.length) return;
    _document.emitters[index].enabled = enabled;
    _markDirty();
  }

  /// Deletes an emitter; the last one is kept (a system always has one).
  void deleteEmitter(int index) {
    if (index < 0 || index >= _document.emitters.length) return;
    if (_document.emitters.length <= 1) return;
    _document.emitters.removeAt(index);
    if (_selected >= _document.emitters.length) _selected = _document.emitters.length - 1;
    _markDirty();
  }

  String _uniqueName(String base) {
    final taken = _document.emitters.map((e) => e.name).toSet();
    if (!taken.contains(base)) return base;
    var i = 2;
    while (taken.contains('$base $i')) {
      i++;
    }
    return '$base $i';
  }

  /// Per-stage summary shown on the collapsed accordion headers.
  String stageSummary(String stage) {
    final c = config;
    switch (stage) {
      case 'spawn':
        return 'Spawn Rate: ${_n(c.spawnRate)}/s · ${c.bursts.length} burst${c.bursts.length == 1 ? '' : 's'}';
      case 'lifetime':
        return 'Life: ${_n(c.lifetimeMin)}–${_n(c.lifetimeMax)}s · Speed: ${_n(c.speedMin)}–${_n(c.speedMax)} · Cone: ${_n(c.coneAngleDegrees)}°';
      case 'forces':
        return 'Gravity: (${_n(c.gravity.x)}, ${_n(c.gravity.y)}, ${_n(c.gravity.z)}) · Drag: ${_n(c.drag)}';
      case 'overlife':
        return 'Color stops: ${c.colorOverLife.length} · Size points: ${c.sizeOverLife.length}';
      case 'render':
        return c.billboard ? 'Built-in Quad (billboard)' : 'Mesh: ${c.meshAssetPath}';
    }
    return '';
  }

  static String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  // --- save ------------------------------------------------------------------

  /// Collects one `AssetReference` per emitter that renders a real mesh.
  List<AssetReference> _collectReferences() {
    final refs = <AssetReference>[];
    final dir = projectDirPath;
    for (var i = 0; i < _document.emitters.length; i++) {
      final path = _document.emitters[i].config.meshAssetPath;
      if (path == null || path.isEmpty) continue;
      var assetId = '';
      if (dir != null) {
        final f = File('$dir/$path');
        if (f.existsSync()) {
          try {
            assetId = LuminaAsset.fromBytes(f.readAsBytesSync()).assetId;
          } catch (_) {}
        }
      }
      refs.add(AssetReference(
        slotName: '${ParticleSystemDocument.meshSlotPrefix}$i',
        assetId: assetId,
        assetPath: path,
      ));
    }
    return refs;
  }

  Future<bool> save() async {
    if (!canSave) {
      _logger.log(
        'Save blocked: ${errors.values.join(' ')}',
        level: 'error',
        source: 'ParticleEditor',
      );
      return false;
    }
    final json = _document.toJsonString();
    final base = _asset ??
        LuminaAsset(assetId: fileBasename, name: fileBasename, type: AssetType.particle);
    final updated = LuminaAsset(
      assetId: base.assetId.isEmpty ? fileBasename : base.assetId,
      name: base.name.isEmpty ? fileBasename : base.name,
      type: AssetType.particle,
      hasThumbnail: base.hasThumbnail,
      thumbnailPng: base.thumbnailPng,
      rawPayload: base.rawPayload,
      rawMatSource: base.rawMatSource,
      references: _collectReferences(),
      metadata: {
        ...base.metadata,
        ParticleSystemDocument.metadataKey: json,
        'emitter_count': '${_document.emitters.length}',
      },
    );
    try {
      final file = File(assetPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(updated.toProtoBufferBytes(), flush: true);
      _asset = updated;
      _onDiskJson = json;
      _dirty = false;
      _logger.log(
        'Saved particle system $fileBasename (${_document.emitters.length} emitter(s))',
        level: 'success',
        source: 'ParticleEditor',
      );
      notifyListeners();
      return true;
    } catch (e) {
      _logger.log('Failed to save $assetPath: $e', level: 'error', source: 'ParticleEditor');
      return false;
    }
  }

  // --- preview / playback ----------------------------------------------------

  bool get isPlaying => _isPlaying;
  double get simSpeed => _simSpeed;
  double get simTime => _simTime;
  bool get isPreviewAttached => preview.isAttached;

  /// The live engine components — one per enabled emitter.
  List<LuminaParticleSystemComponent> get components {
    _ensureComponents();
    return List.unmodifiable(_components);
  }

  /// Real `liveParticleCount` summed over the live components.
  int get activeParticleCount {
    _ensureComponents();
    var n = 0;
    for (final c in _components) {
      n += c.liveParticleCount;
    }
    return n;
  }

  /// Total pool budget (`maxParticles`) across the enabled emitters.
  int get particleBudget {
    var n = 0;
    for (final e in enabledEmitters) {
      n += e.config.maxParticles;
    }
    return n;
  }

  String get statsLabel =>
      'Active Particles: $activeParticleCount / $particleBudget  ·  Sim: ${_simTime.toStringAsFixed(2)}s  ·  ${_simSpeed.toStringAsFixed(1)}x';

  void _ensureComponents() {
    if (!_componentsStale) return;
    _componentsStale = false;
    preview.releaseComponents();
    _components.clear();
    final enabled = enabledEmitters;
    if (!canSave) return; // never build a component from an invalid config
    for (final entry in enabled) {
      final c = LuminaParticleSystemComponent(
        config: entry.config,
        randomSeed: previewSeed,
        autoActivate: true,
      );
      _components.add(c);
    }
    preview.setComponents(_components);
  }

  void _resetPlayback() {
    _simTime = 0.0;
  }

  void play() {
    _ensureComponents();
    _isPlaying = true;
    notifyListeners();
  }

  void pause() {
    _isPlaying = false;
    notifyListeners();
  }

  void togglePlay() => _isPlaying ? pause() : play();

  void setSimSpeed(double v) {
    _simSpeed = v.clamp(minSimSpeed, maxSimSpeed);
    notifyListeners();
  }

  /// Advances the simulation by `dt · simSpeed` when playing. Called by the
  /// preview scene's render ticker (and directly by tests).
  void advance(double dt) {
    if (!_isPlaying || dt <= 0.0) return;
    _tick(dt * _simSpeed);
  }

  /// Advances exactly one 1/60 s tick without leaving the paused state.
  void stepFrame() {
    _ensureComponents();
    _tick(frameSeconds);
  }

  void _tick(double dt) {
    _ensureComponents();
    if (_components.isEmpty || dt <= 0.0) return;
    _simTime += dt;
    for (final c in _components) {
      c.onTick(dt);
    }
    preview.syncParticles();
    notifyListeners();
  }

  /// `Reset Sim` — the components' own reset, not an editor-side fake.
  void resetSimulation() {
    _ensureComponents();
    for (final c in _components) {
      c.resetSimulation();
      c.activate();
    }
    _simTime = 0.0;
    preview.syncParticles();
    notifyListeners();
  }

  void attachPreview(LuminaWorld world) {
    _ensureComponents();
    preview.attach(world, onAdvance: advance);
    preview.setComponents(_components);
    if (!_disposed) notifyListeners();
  }

  void detachPreview(LuminaWorld world) {
    preview.detach();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    preview.detach();
    _components.clear();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
}
