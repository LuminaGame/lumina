part of '../engine.dart';

/// Live object counts of one engine: what a viewport sharing the
/// engine created and must destroy again. [entities] is process-wide (entity
/// ids are not per engine).
class FilamentEngineResourceCounts {
  final int textures;
  final int materials;
  final int vertexBuffers;
  final int indexBuffers;
  final int bufferObjects;
  final int skinningBuffers;
  final int morphTargetBuffers;
  final int instanceBuffers;
  final int views;
  final int scenes;
  final int swapChains;
  final int indirectLights;
  final int skyboxes;
  final int colorGradings;
  final int renderTargets;
  final int renderables;
  final int lights;
  final int transforms;
  final int entities;

  const FilamentEngineResourceCounts({
    this.textures = 0,
    this.materials = 0,
    this.vertexBuffers = 0,
    this.indexBuffers = 0,
    this.bufferObjects = 0,
    this.skinningBuffers = 0,
    this.morphTargetBuffers = 0,
    this.instanceBuffers = 0,
    this.views = 0,
    this.scenes = 0,
    this.swapChains = 0,
    this.indirectLights = 0,
    this.skyboxes = 0,
    this.colorGradings = 0,
    this.renderTargets = 0,
    this.renderables = 0,
    this.lights = 0,
    this.transforms = 0,
    this.entities = 0,
  });

  factory FilamentEngineResourceCounts.fromMap(Map<String, int> m) => FilamentEngineResourceCounts(
        textures: m['textures'] ?? 0,
        materials: m['materials'] ?? 0,
        vertexBuffers: m['vertexBuffers'] ?? 0,
        indexBuffers: m['indexBuffers'] ?? 0,
        bufferObjects: m['bufferObjects'] ?? 0,
        skinningBuffers: m['skinningBuffers'] ?? 0,
        morphTargetBuffers: m['morphTargetBuffers'] ?? 0,
        instanceBuffers: m['instanceBuffers'] ?? 0,
        views: m['views'] ?? 0,
        scenes: m['scenes'] ?? 0,
        swapChains: m['swapChains'] ?? 0,
        indirectLights: m['indirectLights'] ?? 0,
        skyboxes: m['skyboxes'] ?? 0,
        colorGradings: m['colorGradings'] ?? 0,
        renderTargets: m['renderTargets'] ?? 0,
        renderables: m['renderables'] ?? 0,
        lights: m['lights'] ?? 0,
        transforms: m['transforms'] ?? 0,
        entities: m['entities'] ?? 0,
      );

  Map<String, int> toMap() => {
        'textures': textures,
        'materials': materials,
        'vertexBuffers': vertexBuffers,
        'indexBuffers': indexBuffers,
        'bufferObjects': bufferObjects,
        'skinningBuffers': skinningBuffers,
        'morphTargetBuffers': morphTargetBuffers,
        'instanceBuffers': instanceBuffers,
        'views': views,
        'scenes': scenes,
        'swapChains': swapChains,
        'indirectLights': indirectLights,
        'skyboxes': skyboxes,
        'colorGradings': colorGradings,
        'renderTargets': renderTargets,
        'renderables': renderables,
        'lights': lights,
        'transforms': transforms,
        'entities': entities,
      };

  /// Per-field difference `this - other` (what was created in between).
  FilamentEngineResourceCounts operator -(FilamentEngineResourceCounts other) {
    final a = toMap();
    final b = other.toMap();
    return FilamentEngineResourceCounts.fromMap({for (final k in a.keys) k: a[k]! - b[k]!});
  }

  /// The fields that differ from zero, for failure messages.
  Map<String, int> get nonZero => {
        for (final e in toMap().entries)
          if (e.value != 0) e.key: e.value,
      };

  @override
  bool operator ==(Object other) =>
      other is FilamentEngineResourceCounts && _mapEquals(toMap(), other.toMap());

  static bool _mapEquals(Map<String, int> a, Map<String, int> b) {
    for (final k in a.keys) {
      if (a[k] != b[k]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(toMap().values);

  @override
  String toString() => 'FilamentEngineResourceCounts(${toMap()})';
}

/// Device-local GPU memory as `VK_EXT_memory_budget` reports it:
/// [usageBytes] is this process's usage of the device-local heaps.
class FilamentGpuMemory {
  final int usageBytes;
  final int budgetBytes;
  final int heapBytes;
  final int heapCount;

  const FilamentGpuMemory({
    required this.usageBytes,
    required this.budgetBytes,
    required this.heapBytes,
    required this.heapCount,
  });

  double get usageMiB => usageBytes / (1024 * 1024);
  double get budgetMiB => budgetBytes / (1024 * 1024);

  @override
  String toString() =>
      'FilamentGpuMemory(usage ${usageMiB.toStringAsFixed(1)} MiB, budget ${budgetMiB.toStringAsFixed(1)} MiB, '
      'heaps ${(heapBytes / (1024 * 1024)).toStringAsFixed(0)} MiB)';
}

class _EngineScoped {
  _EngineScoped(this.key, this.value, this.dispose);
  final Object key;
  final Object value;
  final void Function(Object value)? dispose;
}
