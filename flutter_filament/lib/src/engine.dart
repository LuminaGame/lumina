import 'dart:developer' as developer;

import 'ffi_platform.dart' as ffi;
import 'ffi_package_platform.dart';

import 'package:flutter_filament/src/camera.dart';
import 'package:flutter_filament/src/color_grading.dart';
import 'package:flutter_filament/src/debug_registry.dart';
import 'package:flutter_filament/src/fence.dart';
import 'package:flutter_filament/src/frame_pacer.dart';
import 'package:flutter_filament/src/gpu.dart';
import 'package:flutter_filament/src/indirect_light.dart';
import 'package:flutter_filament/src/renderer.dart';
import 'package:flutter_filament/src/scene.dart';
import 'package:flutter_filament/src/skybox.dart';
import 'package:flutter_filament/src/swap_chain.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;
import 'package:flutter_filament/src/view.dart';

/// The Filament the package was built against. Both values are
/// stamped at compile time — the hook reads `VERSION_NAME` from
/// `filament/android/gradle.properties` — so they describe the linked
/// library, not the checkout. No engine is needed, natively or on the web.
abstract final class FilamentInfo {
  static String? _version;
  static int? _materialVersion;

  /// The Filament release, e.g. `1.77.0`.
  static String get version => _version ??= c.filament_get_version().cast<Utf8>().toDartString();

  /// The material package version the linked engine accepts (77 for 1.77).
  static int get materialVersion => _materialVersion ??= c.filament_get_material_version();
}

/// Filament rendering backend.
enum FilamentBackend {
  /// Automatically select the best backend for the platform.
  defaultBackend(0),

  /// OpenGL / OpenGL ES backend.
  opengl(1),

  /// Vulkan backend.
  vulkan(2),

  /// Metal backend (macOS / iOS).
  metal(3),

  /// WebGPU backend.
  webgpu(4),

  /// No-op backend (for testing).
  noop(5);

  final int value;
  const FilamentBackend(this.value);

  static FilamentBackend fromValue(int v) {
    return FilamentBackend.values.firstWhere(
      (e) => e.value == v,
      orElse: () => FilamentBackend.defaultBackend,
    );
  }
}

/// Preferred shader language for Filament backends.
enum ShaderLanguage {
  default_(0),
  msl(1),
  metalLibrary(2);

  final int value;
  const ShaderLanguage(this.value);

  static ShaderLanguage fromValue(int v) {
    return ShaderLanguage.values.firstWhere(
      (e) => e.value == v,
      orElse: () => ShaderLanguage.default_,
    );
  }
}

/// GPU context priority level for scheduling.
enum GpuContextPriority {
  default_(0),
  low(1),
  medium(2),
  high(3),
  realtime(4);

  final int value;
  const GpuContextPriority(this.value);

  static GpuContextPriority fromValue(int v) {
    return GpuContextPriority.values.firstWhere(
      (e) => e.value == v,
      orElse: () => GpuContextPriority.default_,
    );
  }
}

/// Backend feature levels.
enum FeatureLevel {
  fl0(0),
  fl1(1),
  fl2(2),
  fl3(3);

  final int value;
  const FeatureLevel(this.value);

  static FeatureLevel fromValue(int v) {
    return FeatureLevel.values.firstWhere(
      (e) => e.value == v,
      orElse: () => FeatureLevel.fl1,
    );
  }
}

/// Stereoscopic rendering technique type.
enum StereoscopicType {
  none(0),
  instanced(1),
  multiview(2);

  final int value;
  const StereoscopicType(this.value);

  static StereoscopicType fromValue(int v) {
    return StereoscopicType.values.firstWhere(
      (e) => e.value == v,
      orElse: () => StereoscopicType.none,
    );
  }
}

/// Compiler priority queue for shader precompilation.
enum CompilerPriorityQueue {
  high(0),
  low(1);

  final int value;
  const CompilerPriorityQueue(this.value);
}

/// Configuration options for initializing a [FilamentEngine].
class EngineConfig {
  /// Size in MiB of the low-level command buffer arena.
  final int commandBufferSizeMB;

  /// Size in MiB of the per-frame data arena.
  final int perRenderPassArenaSizeMB;

  /// Minimum size in MiB of a low-level command buffer.
  final int minCommandBufferSizeMB;

  /// Number of threads in the Engine JobSystem (0 = heuristic default).
  final int jobSystemThreadCount;

  /// Preferred shader language.
  final ShaderLanguage preferredShaderLanguage;

  /// Force GLES 2.0 context when using OpenGL backend.
  final bool forceGLES2Context;

  /// GPU context priority level.
  final GpuContextPriority gpuContextPriority;

  /// Capacity of the LRU cache for material definitions.
  final int materialCacheCapacity;

  /// Number of eyes for stereoscopic rendering.
  final int stereoscopicEyeCount;

  /// Type of technique for stereoscopic rendering.
  final StereoscopicType stereoscopicType;

  const EngineConfig({
    this.commandBufferSizeMB = 3,
    this.perRenderPassArenaSizeMB = 3,
    this.minCommandBufferSizeMB = 1,
    this.jobSystemThreadCount = 0,
    this.preferredShaderLanguage = ShaderLanguage.default_,
    this.forceGLES2Context = false,
    this.gpuContextPriority = GpuContextPriority.default_,
    this.materialCacheCapacity = 0,
    this.stereoscopicEyeCount = 2,
    this.stereoscopicType = StereoscopicType.none,
  });

  /// Populates configuration with Filament's default settings.
  factory EngineConfig.defaults() {
    final arena = calloc<c.filament_engine_config_t>();
    try {
      c.filament_engine_config_init_default(arena);
      return EngineConfig(
        commandBufferSizeMB: arena.ref.command_buffer_size_mb,
        perRenderPassArenaSizeMB: arena.ref.per_render_pass_arena_size_mb,
        minCommandBufferSizeMB: arena.ref.min_command_buffer_size_mb,
        jobSystemThreadCount: arena.ref.job_system_thread_count,
        preferredShaderLanguage: ShaderLanguage.fromValue(arena.ref.preferred_shader_language),
        forceGLES2Context: arena.ref.force_gles2_context,
        gpuContextPriority: GpuContextPriority.fromValue(arena.ref.gpu_context_priority),
        materialCacheCapacity: arena.ref.material_cache_capacity,
        stereoscopicEyeCount: arena.ref.stereoscopic_eye_count,
        stereoscopicType: StereoscopicType.fromValue(arena.ref.stereoscopic_type),
      );
    } finally {
      calloc.free(arena);
    }
  }

  void _copyToNative(ffi.Pointer<c.filament_engine_config_t> ptr) {
    ptr.ref.command_buffer_size_mb = commandBufferSizeMB;
    ptr.ref.per_render_pass_arena_size_mb = perRenderPassArenaSizeMB;
    ptr.ref.min_command_buffer_size_mb = minCommandBufferSizeMB;
    ptr.ref.job_system_thread_count = jobSystemThreadCount;
    ptr.ref.preferred_shader_language = preferredShaderLanguage.value;
    ptr.ref.force_gles2_context = forceGLES2Context;
    ptr.ref.gpu_context_priority = gpuContextPriority.value;
    ptr.ref.material_cache_capacity = materialCacheCapacity;
    ptr.ref.stereoscopic_eye_count = stereoscopicEyeCount;
    ptr.ref.stereoscopic_type = stereoscopicType.value;
  }
}

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

/// The main entry point for the Filament rendering engine.
///
/// An [FilamentEngine] instance manages the rendering thread, hardware context,
/// and the lifetime of all created resources (renderers, views, scenes, etc.).
///
/// Use [FilamentEngine.create] to instantiate and [dispose] to clean up.
class FilamentEngine {
  final ffi.Pointer<ffi.Void> _ptr;
  bool _disposed = false;

  /// The WebGL context of an engine made by [createForCanvas] (web only).
  int _canvasContext = 0;

  FilamentEngine._(this._ptr);

  /// Web builds: creates an OpenGL (WebGL2) engine drawing into the canvas
  /// matched by [canvasSelector] (e.g. `'#game'`). Its swap chain is
  /// `createSwapChain(ffi.nullptr)`. Returns null when there is no such canvas
  /// or no WebGL2 — and always on native platforms, which have no canvas.
  static FilamentEngine? createForCanvas(String canvasSelector) {
    final selector = canvasSelector.toNativeUtf8().cast<ffi.Char>();
    final context = calloc<ffi.Int32>();
    try {
      final ptr = c.filament_engine_create_for_canvas(selector, context);
      if (ptr == ffi.nullptr) return null;
      return FilamentEngine._(ptr).._canvasContext = context.value;
    } finally {
      calloc.free(selector);
      calloc.free(context);
    }
  }

  /// Creates a new Filament Engine with the specified builder parameters.
  ///
  /// Returns `null` if the engine couldn't be created (e.g., GPU driver
  /// doesn't support the required version or features).
  /// The GPU every engine created without an explicit `gpu` renders on
  /// (Vulkan only). The editor sets it at startup from its settings; the
  /// default leaves the choice to the environment (`FILAMENT_GPU`,
  /// `VK_DEVICE_INDEX`) and then to Filament.
  static FilamentGpuPreference defaultGpuPreference = FilamentGpuPreference.automatic;

  static FilamentEngine? create({
    FilamentBackend backend = FilamentBackend.defaultBackend,
    EngineConfig? config,
    FeatureLevel? featureLevel,
    bool paused = false,
    Map<String, bool> features = const {},
    FilamentGpuPreference? gpu,
  }) {
    final arena = calloc<c.filament_engine_config_t>();
    ffi.Pointer<ffi.Pointer<ffi.Char>> featureNamesPtr = ffi.nullptr;
    ffi.Pointer<ffi.Bool> featureValuesPtr = ffi.nullptr;
    final List<ffi.Pointer<ffi.Char>> allocatedStrings = [];

    try {
      ffi.Pointer<c.filament_engine_config_t> configPtr = ffi.nullptr;
      if (config != null) {
        config._copyToNative(arena);
        configPtr = arena;
      }

      final featureCount = features.length;
      if (featureCount > 0) {
        featureNamesPtr = calloc<ffi.Pointer<ffi.Char>>(featureCount);
        featureValuesPtr = calloc<ffi.Bool>(featureCount);
        int idx = 0;
        for (final entry in features.entries) {
          final strPtr = entry.key.toNativeUtf8().cast<ffi.Char>();
          allocatedStrings.add(strPtr);
          featureNamesPtr[idx] = strPtr;
          featureValuesPtr[idx] = entry.value;
          idx++;
        }
      }

      final preference = gpu ?? defaultGpuPreference;
      final name = preference.deviceName;
      final gpuName = name == null || name.isEmpty ? ffi.nullptr : name.toNativeUtf8().cast<ffi.Char>();
      if (gpuName != ffi.nullptr) allocatedStrings.add(gpuName);
      final ptr = c.filament_engine_create_on_gpu(
        backend.value,
        featureLevel?.value ?? -1,
        paused,
        configPtr,
        featureNamesPtr.cast(),
        featureValuesPtr,
        featureCount,
        gpuName,
        preference.index ?? -1,
      );

      if (ptr == ffi.nullptr) return null;
      return FilamentEngine._(ptr);
    } finally {
      calloc.free(arena);
      if (featureNamesPtr != ffi.nullptr) calloc.free(featureNamesPtr);
      if (featureValuesPtr != ffi.nullptr) calloc.free(featureValuesPtr);
      for (final str in allocatedStrings) {
        calloc.free(str);
      }
    }
  }

  /// The name of the physical device this engine renders on, as Vulkan
  /// reports it (`NVIDIA RTX PRO 2000 Blackwell`); "" for other backends.
  String get gpuName {
    final out = calloc<ffi.Char>(256);
    try {
      final length = c.filament_engine_get_gpu_name(nativePointer, out, 256);
      return length <= 0 ? '' : out.cast<Utf8>().toDartString(length: length);
    } finally {
      calloc.free(out);
    }
  }

  /// The raw native pointer to the Filament Engine.
  ///
  /// Use with caution — this is for advanced interop scenarios.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _ptr;
  }

  /// Returns the current configuration of this engine.
  EngineConfig get config {
    _checkDisposed();
    final arena = calloc<c.filament_engine_config_t>();
    try {
      c.filament_engine_get_config(_ptr, arena);
      return EngineConfig(
        commandBufferSizeMB: arena.ref.command_buffer_size_mb,
        perRenderPassArenaSizeMB: arena.ref.per_render_pass_arena_size_mb,
        minCommandBufferSizeMB: arena.ref.min_command_buffer_size_mb,
        jobSystemThreadCount: arena.ref.job_system_thread_count,
        preferredShaderLanguage: ShaderLanguage.fromValue(arena.ref.preferred_shader_language),
        forceGLES2Context: arena.ref.force_gles2_context,
        gpuContextPriority: GpuContextPriority.fromValue(arena.ref.gpu_context_priority),
        materialCacheCapacity: arena.ref.material_cache_capacity,
        stereoscopicEyeCount: arena.ref.stereoscopic_eye_count,
        stereoscopicType: StereoscopicType.fromValue(arena.ref.stereoscopic_type),
      );
    } finally {
      calloc.free(arena);
    }
  }

  /// Creates a new [FilamentRenderer] associated with this engine.
  FilamentRenderer createRenderer() {
    _checkDisposed();
    final ptr = c.filament_engine_create_renderer(_ptr);
    return FilamentRenderer.internal(ptr, this);
  }

  /// Creates a new [FilamentSwapChain] from a native window handle.
  FilamentSwapChain createSwapChain(
    ffi.Pointer<ffi.Void> nativeWindow, {
    dynamic flags = 0,
  }) {
    _checkDisposed();
    final flagVal = flags is SwapChainConfig ? flags.value : (flags as int);
    final ptr = c.filament_engine_create_swap_chain(_ptr, nativeWindow, flagVal);
    return FilamentSwapChain.internal(ptr, this);
  }

  /// Creates a headless [FilamentSwapChain] for offscreen rendering.
  FilamentSwapChain createHeadlessSwapChain(
    int width,
    int height, {
    dynamic flags = 0,
  }) {
    _checkDisposed();
    final flagVal = flags is SwapChainConfig ? flags.value : (flags as int);
    final ptr = c.filament_engine_create_headless_swap_chain(
      _ptr,
      width,
      height,
      flagVal,
    );
    return FilamentSwapChain.internal(ptr, this);
  }

  /// Creates a new [FilamentView].
  FilamentView createView() {
    _checkDisposed();
    final ptr = c.filament_engine_create_view(_ptr);
    return FilamentView.internal(ptr, this);
  }

  /// Creates a new [FilamentScene].
  FilamentScene createScene() {
    _checkDisposed();
    final ptr = c.filament_engine_create_scene(_ptr);
    return FilamentScene.internal(ptr, this);
  }

  /// Creates a new [FilamentCamera] attached to the given entity.
  FilamentCamera createCamera(int entity) {
    _checkDisposed();
    final ptr = c.filament_engine_create_camera(_ptr, entity);
    return FilamentCamera.internal(ptr, entity, this);
  }

  /// Creates a new entity and returns its ID.
  int createEntity() {
    _checkDisposed();
    return c.filament_entity_create(_ptr);
  }

  /// Creates a new [FilamentFence] in the command stream.
  FilamentFence createFence() {
    _checkDisposed();
    return FilamentFence.create(this);
  }

  /// Creates a new [FilamentFramePacer] associated with this engine.
  FilamentFramePacer createFramePacer({
    double targetFrameRate = 60.0,
    Duration? latency,
    int? latencyFrames,
  }) {
    _checkDisposed();
    return FilamentFramePacer.create(
      this,
      targetFrameRate: targetFrameRate,
      latency: latency,
      latencyFrames: latencyFrames,
    );
  }

  /// Destroys a [FilamentFramePacer].
  void destroyFramePacer(FilamentFramePacer pacer) {
    _checkDisposed();
    pacer.dispose();
  }

  FilamentDebugRegistry? _debugRegistry;

  /// Returns the [FilamentDebugRegistry] for querying and setting engine debug switches.
  FilamentDebugRegistry get debugRegistry {
    _checkDisposed();
    if (_debugRegistry == null) {
      final ptr = c.filament_engine_get_debug_registry(_ptr);
      _debugRegistry = FilamentDebugRegistry.internal(ptr, this);
    }
    return _debugRegistry!;
  }

  /// Destroys a [FilamentView].
  void destroyView(FilamentView view) {
    _checkDisposed();
    c.filament_engine_destroy_view(_ptr, view.nativePointer);
  }

  /// Destroys a [FilamentScene].
  void destroyScene(FilamentScene scene) {
    _checkDisposed();
    c.filament_engine_destroy_scene(_ptr, scene.nativePointer);
  }

  /// Destroys a [FilamentCamera].
  void destroyCamera(FilamentCamera camera) {
    _checkDisposed();
    c.filament_engine_destroy_camera_component(_ptr, camera.entity);
  }

  /// Destroys a [ColorGrading] object.
  void destroyColorGrading(ColorGrading colorGrading) {
    _checkDisposed();
    colorGrading.destroy();
  }

  /// Destroys an entity and all its Filament components.
  void destroyEntity(int entity) {
    _checkDisposed();
    c.filament_entity_destroy(_ptr, entity);
  }

  /// Destroys all Filament components attached to the given [entity].
  void destroyEntityComponents(int entity) {
    _checkDisposed();
    c.filament_engine_destroy_entity_components(_ptr, entity);
  }

  /// Destroys a morph target buffer given its native pointer.
  void destroyMorphTargetBuffer(ffi.Pointer<ffi.Void> mtb) {
    _checkDisposed();
    c.filament_engine_destroy_morph_target_buffer(_ptr, mtb);
  }

  /// Destroys a fence given its native pointer.
  void destroyFence(ffi.Pointer<ffi.Void> fence) {
    _checkDisposed();
    c.filament_engine_destroy_fence(_ptr, fence);
  }

  /// Destroys an instance buffer given its native pointer.
  void destroyInstanceBuffer(ffi.Pointer<ffi.Void> ibuf) {
    _checkDisposed();
    c.filament_engine_destroy_instance_buffer(_ptr, ibuf);
  }

  // =========================================================================
  // isValid family
  // =========================================================================

  /// Tells whether a [FilamentRenderer] is valid.
  bool isValidRenderer(FilamentRenderer renderer) {
    _checkDisposed();
    if (renderer.isDisposed) return false;
    return c.filament_engine_is_valid_renderer(_ptr, renderer.nativePointer);
  }

  /// Tells whether a [FilamentView] is valid.
  bool isValidView(FilamentView view) {
    _checkDisposed();
    if (view.isDisposed) return false;
    return c.filament_engine_is_valid_view(_ptr, view.nativePointer);
  }

  /// Tells whether a [FilamentScene] is valid.
  bool isValidScene(FilamentScene scene) {
    _checkDisposed();
    if (scene.isDisposed) return false;
    return c.filament_engine_is_valid_scene(_ptr, scene.nativePointer);
  }

  /// Tells whether a [FilamentSwapChain] is valid.
  bool isValidSwapChain(FilamentSwapChain swapChain) {
    _checkDisposed();
    if (swapChain.isDisposed) return false;
    return c.filament_engine_is_valid_swap_chain(_ptr, swapChain.nativePointer);
  }

  /// Tells whether a [FilamentCamera] component is valid.
  bool isValidCamera(FilamentCamera camera) {
    _checkDisposed();
    if (camera.isDisposed) return false;
    return c.filament_engine_is_valid_camera(_ptr, camera.nativePointer);
  }

  /// Tells whether a Texture native handle is valid.
  bool isValidTexture(ffi.Pointer<ffi.Void> texture) {
    _checkDisposed();
    if (texture == ffi.nullptr) return false;
    return c.filament_engine_is_valid_texture(_ptr, texture);
  }

  /// Tells whether a Material native handle is valid.
  bool isValidMaterial(ffi.Pointer<ffi.Void> material) {
    _checkDisposed();
    if (material == ffi.nullptr) return false;
    return c.filament_engine_is_valid_material(_ptr, material);
  }

  /// Tells whether a MaterialInstance is valid when its parent Material is known.
  bool isValidMaterialInstance(ffi.Pointer<ffi.Void> material, ffi.Pointer<ffi.Void> mi) {
    _checkDisposed();
    if (material == ffi.nullptr || mi == ffi.nullptr) return false;
    return c.filament_engine_is_valid_material_instance(_ptr, material, mi);
  }

  /// Tells whether a MaterialInstance is valid (expensive full scan).
  bool isValidMaterialInstanceExpensive(ffi.Pointer<ffi.Void> mi) {
    _checkDisposed();
    if (mi == ffi.nullptr) return false;
    return c.filament_engine_is_valid_expensive_material_instance(_ptr, mi);
  }

  /// Tells whether a VertexBuffer native handle is valid.
  bool isValidVertexBuffer(ffi.Pointer<ffi.Void> vb) {
    _checkDisposed();
    if (vb == ffi.nullptr) return false;
    return c.filament_engine_is_valid_vertex_buffer(_ptr, vb);
  }

  /// Tells whether an IndexBuffer native handle is valid.
  bool isValidIndexBuffer(ffi.Pointer<ffi.Void> ib) {
    _checkDisposed();
    if (ib == ffi.nullptr) return false;
    return c.filament_engine_is_valid_index_buffer(_ptr, ib);
  }

  /// Tells whether a BufferObject native handle is valid.
  bool isValidBufferObject(ffi.Pointer<ffi.Void> bo) {
    _checkDisposed();
    if (bo == ffi.nullptr) return false;
    return c.filament_engine_is_valid_buffer_object(_ptr, bo);
  }

  /// Tells whether a SkinningBuffer native handle is valid.
  bool isValidSkinningBuffer(ffi.Pointer<ffi.Void> sb) {
    _checkDisposed();
    if (sb == ffi.nullptr) return false;
    return c.filament_engine_is_valid_skinning_buffer(_ptr, sb);
  }

  /// Tells whether a MorphTargetBuffer native handle is valid.
  bool isValidMorphTargetBuffer(ffi.Pointer<ffi.Void> mtb) {
    _checkDisposed();
    if (mtb == ffi.nullptr) return false;
    return c.filament_engine_is_valid_morph_target_buffer(_ptr, mtb);
  }

  /// Tells whether an InstanceBuffer native handle is valid.
  bool isValidInstanceBuffer(ffi.Pointer<ffi.Void> ibuf) {
    _checkDisposed();
    if (ibuf == ffi.nullptr) return false;
    return c.filament_engine_is_valid_instance_buffer(_ptr, ibuf);
  }

  /// Tells whether an [IndirectLight] native handle or instance is valid.
  bool isValidIndirectLight(FilamentIndirectLight ibl) {
    _checkDisposed();
    if (ibl.isDisposed) return false;
    return c.filament_engine_is_valid_indirect_light(_ptr, ibl.nativePointer);
  }

  /// Tells whether a [Skybox] instance is valid.
  bool isValidSkybox(FilamentSkybox skybox) {
    _checkDisposed();
    if (skybox.isDisposed) return false;
    return c.filament_engine_is_valid_skybox(_ptr, skybox.nativePointer);
  }

  /// Tells whether a RenderTarget native handle is valid.
  bool isValidRenderTarget(ffi.Pointer<ffi.Void> rt) {
    _checkDisposed();
    if (rt == ffi.nullptr) return false;
    return c.filament_engine_is_valid_render_target(_ptr, rt);
  }

  /// Tells whether a Fence native handle is valid.
  bool isValidFence(ffi.Pointer<ffi.Void> fence) {
    _checkDisposed();
    if (fence == ffi.nullptr) return false;
    return c.filament_engine_is_valid_fence(_ptr, fence);
  }

  /// Tells whether a [ColorGrading] instance is valid.
  bool isValidColorGrading(ColorGrading cg) {
    _checkDisposed();
    if (cg.isDisposed) return false;
    return c.filament_engine_is_valid_color_grading(_ptr, cg.nativePointer);
  }

  // =========================================================================
  // Frame & Thread Control
  // =========================================================================

  /// Flushes the current command buffer to the hardware rendering thread without blocking.
  void flush() {
    _checkDisposed();
    c.filament_engine_flush(_ptr);
  }

  /// Kicks the hardware thread and blocks until all commands are executed, or until [timeout] elapses.
  ///
  /// Returns `true` if all commands finished before timeout, `false` otherwise.
  bool flushAndWait({Duration? timeout}) {
    _checkDisposed();
    if (timeout == null) {
      c.filament_engine_flush_and_wait(_ptr);
      return true;
    }
    final timeoutNs = timeout.inMicroseconds * 1000;
    return c.filament_engine_flush_and_wait_timeout(_ptr, timeoutNs);
  }

  /// Pumps the engine's internal message queues, processing pending callbacks and asynchronous events.
  ///
  /// Recommended to call once per frame in the main game loop.
  void pumpMessageQueues() {
    _checkDisposed();
    c.filament_engine_pump_message_queues(_ptr);
  }

  /// Executes work on the calling thread. Only supported in single-threaded/web builds.
  void execute() {
    _checkDisposed();
    c.filament_engine_execute(_ptr);
  }

  /// Whether the rendering thread is paused.
  bool get isPaused {
    _checkDisposed();
    return c.filament_engine_is_paused(_ptr);
  }

  set paused(bool val) {
    _checkDisposed();
    c.filament_engine_set_paused(_ptr, val);
  }

  /// Monotonically increasing clock time in nanoseconds, suitable for `beginFrame` vsync calculations.
  int get steadyClockTimeNano {
    _checkDisposed();
    return c.filament_engine_get_steady_clock_time_nano(_ptr);
  }

  // =========================================================================
  // Capabilities & Query
  // =========================================================================

  /// The highest feature level supported by the active backend driver.
  FeatureLevel get supportedFeatureLevel {
    _checkDisposed();
    return FeatureLevel.fromValue(c.filament_engine_get_supported_feature_level(_ptr));
  }

  /// Sets the active feature level within the supported range.
  FeatureLevel setActiveFeatureLevel(FeatureLevel level) {
    _checkDisposed();
    return FeatureLevel.fromValue(c.filament_engine_set_active_feature_level(_ptr, level.value));
  }

  /// The currently active feature level.
  FeatureLevel get activeFeatureLevel {
    _checkDisposed();
    return FeatureLevel.fromValue(c.filament_engine_get_active_feature_level(_ptr));
  }

  /// Maximum number of automatic instances supported when automatic instancing is enabled.
  int get maxAutomaticInstances {
    _checkDisposed();
    return c.filament_engine_get_max_automatic_instances(_ptr);
  }

  /// Whether stereoscopic rendering is supported for the given [type].
  bool isStereoSupported([StereoscopicType type = StereoscopicType.instanced]) {
    _checkDisposed();
    return c.filament_engine_is_stereo_supported(_ptr, type.value);
  }

  /// Whether this engine's device builds ray tracing acceleration structures
  /// and traces rays from shaders (Vulkan ray query).
  ///
  /// True only on a Vulkan engine created after [RayTracing.requestExtensions]
  /// on a GPU with the ray query extensions. Without it
  /// [FilamentScene.rayTracingEnabled] builds nothing, [ShadowOptions.rayTraced]
  /// falls back to the shadow maps and ray queries report no hit.
  bool get supportsRayQuery {
    _checkDisposed();
    return c.filament_engine_supports_ray_query(_ptr);
  }

  /// Whether the engine has encountered an unrecoverable failure (e.g. GPU crash).
  bool get hasUnrecoverableFailure {
    _checkDisposed();
    return c.filament_engine_has_unrecoverable_failure(_ptr);
  }

  /// The backend driver used by this engine.
  FilamentBackend get backend {
    _checkDisposed();
    return FilamentBackend.fromValue(c.filament_engine_get_backend(_ptr));
  }

  /// Pointer to the default material owned by this engine (do NOT dispose).
  ffi.Pointer<ffi.Void> get defaultMaterialPointer {
    _checkDisposed();
    return c.filament_engine_get_default_material(_ptr).cast();
  }

  /// Whether automatic draw-call batching/instancing is enabled.
  bool get automaticInstancingEnabled {
    _checkDisposed();
    return c.filament_engine_is_automatic_instancing_enabled(_ptr);
  }

  set automaticInstancingEnabled(bool enable) {
    _checkDisposed();
    c.filament_engine_set_automatic_instancing_enabled(_ptr, enable);
  }

  // =========================================================================
  // Resource Counters & Lifecycle
  // =========================================================================

  /// Returns the current number of allocated Material objects tracked by this engine.
  int get materialCount {
    _checkDisposed();
    return c.filament_engine_get_material_count(_ptr);
  }

  /// Returns the current number of allocated VertexBuffer objects tracked by this engine.
  int get vertexBufferCount {
    _checkDisposed();
    return c.filament_engine_get_vertex_buffer_count(_ptr);
  }

  /// Returns the current number of allocated IndexBuffer objects tracked by this engine.
  int get indexBufferCount {
    _checkDisposed();
    return c.filament_engine_get_index_buffer_count(_ptr);
  }

  /// Live object counts of this engine.
  FilamentEngineResourceCounts get resourceCounts {
    _checkDisposed();
    final out = calloc<c.filament_engine_resource_counts_t>();
    try {
      if (!c.filament_engine_get_resource_counts(_ptr, out)) return const FilamentEngineResourceCounts();
      final r = out.ref;
      return FilamentEngineResourceCounts(
        textures: r.textures,
        materials: r.materials,
        vertexBuffers: r.vertex_buffers,
        indexBuffers: r.index_buffers,
        bufferObjects: r.buffer_objects,
        skinningBuffers: r.skinning_buffers,
        morphTargetBuffers: r.morph_target_buffers,
        instanceBuffers: r.instance_buffers,
        views: r.views,
        scenes: r.scenes,
        swapChains: r.swap_chains,
        indirectLights: r.indirect_lights,
        skyboxes: r.skyboxes,
        colorGradings: r.color_gradings,
        renderTargets: r.render_targets,
        renderables: r.renderables,
        lights: r.lights,
        transforms: r.transforms,
        entities: r.entities,
      );
    } finally {
      calloc.free(out);
    }
  }

  /// This process's device-local GPU memory on the device this engine renders
  /// on (`VK_EXT_memory_budget`); null for OpenGL, noop, the web, or a device
  /// without the extension.
  FilamentGpuMemory? get gpuMemory {
    _checkDisposed();
    final out = calloc<c.filament_gpu_memory_t>();
    try {
      if (!c.filament_engine_get_gpu_memory(_ptr, out)) return null;
      final r = out.ref;
      return FilamentGpuMemory(
        usageBytes: r.device_local_usage,
        budgetBytes: r.device_local_budget,
        heapBytes: r.device_local_size,
        heapCount: r.heap_count,
      );
    } finally {
      calloc.free(out);
    }
  }

  // =========================================================================
  // Engine-scoped resources
  // =========================================================================

  final List<_EngineScoped> _scoped = [];

  /// The value registered under [key] on this engine, created by [create] on
  /// first use. Engine-scoped values (a glTF asset cache shared by every
  /// viewport, …) live exactly as long as the engine: [dispose] runs their
  /// [dispose] callbacks in reverse registration order, with the engine
  /// still alive, before the engine is destroyed.
  T engineScoped<T extends Object>(Object key, T Function() create, {void Function(T value)? dispose}) {
    _checkDisposed();
    for (final s in _scoped) {
      if (s.key == key) return s.value as T;
    }
    final value = create();
    _scoped.add(_EngineScoped(key, value, dispose == null ? null : (v) => dispose(v as T)));
    return value;
  }

  /// The value registered under [key], or null.
  T? engineScopedOrNull<T extends Object>(Object key) {
    if (_disposed) return null;
    for (final s in _scoped) {
      if (s.key == key) return s.value as T;
    }
    return null;
  }

  /// Disposes and forgets the value registered under [key] (no-op when none).
  void releaseEngineScoped(Object key) {
    final index = _scoped.indexWhere((s) => s.key == key);
    if (index < 0) return;
    final s = _scoped.removeAt(index);
    s.dispose?.call(s.value);
  }

  void _disposeScoped() {
    while (_scoped.isNotEmpty) {
      final s = _scoped.removeLast();
      try {
        s.dispose?.call(s.value);
      } catch (e, st) {
        // One failing cache must not keep the others (or the engine) alive.
        developer.log('engine-scoped ${s.key} failed to dispose: $e', name: 'flutter_filament', error: e, stackTrace: st);
      }
    }
  }

  /// Set by `FilamentEngineHost` for the engines it owns: [dispose] then
  /// refuses to run unless the host itself is tearing the engine down.
  String Function()? _hostOwners;
  bool _hostReleasing = false;

  /// Whether `FilamentEngineHost` owns this engine.
  bool get isHostOwned => _hostOwners != null;

  /// Releases all resources and destroys this engine: engine-scoped values
  /// first (reverse order, engine alive), then the engine itself.
  ///
  /// An engine owned by `FilamentEngineHost` cannot be disposed directly —
  /// release the lease instead; the host destroys the engine after its last
  /// lease.
  ///
  /// After calling [dispose], this engine instance must not be used.
  void dispose() {
    if (_disposed) return;
    if (_hostOwners != null && !_hostReleasing) {
      throw StateError('This FilamentEngine is shared through FilamentEngineHost (leases: ${_hostOwners!()}); '
          'release your lease instead of disposing the engine.');
    }
    _disposeScoped();
    _disposed = true;
    c.filament_engine_destroy(_ptr);
    if (_canvasContext != 0) {
      c.filament_web_destroy_canvas_context(_canvasContext);
      _canvasContext = 0;
    }
  }

  /// Whether this engine has been disposed.
  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('FilamentEngine has been disposed');
    }
  }
}

/// Host plumbing for `FilamentEngineHost` (engine_host.dart); not public API.
void markHostOwnedEngine(FilamentEngine engine, String Function() owners) => engine._hostOwners = owners;

/// Destroys a host-owned engine on behalf of `FilamentEngineHost`.
void disposeHostOwnedEngine(FilamentEngine engine) {
  engine._hostReleasing = true;
  try {
    engine.dispose();
  } finally {
    engine._hostOwners = null;
    engine._hostReleasing = false;
  }
}
