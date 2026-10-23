part of '../engine.dart';

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
/// How the engine runs asynchronous resource creation and uploads
/// (`Engine::Config::asynchronousMode`). A request, not a guarantee: read
/// `FilamentEngine.isAsynchronousModeEnabled` before relying on it.
enum FilamentAsynchronousMode {
  /// No asynchronous operations (Filament's default).
  none(0),

  /// A dedicated worker thread; falls back to [amortization] where the
  /// platform has no threads.
  threadPreferred(1),

  /// A few asynchronous tasks per engine update, on the main thread.
  amortization(2);

  const FilamentAsynchronousMode(this.value);
  final int value;

  static FilamentAsynchronousMode fromValue(int v) =>
      values.firstWhere((m) => m.value == v, orElse: () => none);
}

/// The engine feature flag that lets `EngineConfig.asynchronousMode` take
/// effect (`Engine::Builder::feature`); `FilamentEngine.create` turns it on
/// whenever the mode is not [FilamentAsynchronousMode.none].
const String asynchronousOperationFeature = 'backend.enable_asynchronous_operation';

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

  /// Asynchronous resource creation and uploads; a worker thread when the
  /// platform has one, so textures and buffers stream in without blocking
  /// the caller.
  final FilamentAsynchronousMode asynchronousMode;

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
    this.asynchronousMode = FilamentAsynchronousMode.threadPreferred,
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
        asynchronousMode: FilamentAsynchronousMode.fromValue(arena.ref.asynchronous_mode),
      );
    } finally {
      calloc.free(arena);
    }
  }

  /// This configuration with another [asynchronousMode].
  EngineConfig withAsynchronousMode(FilamentAsynchronousMode mode) => EngineConfig(
        commandBufferSizeMB: commandBufferSizeMB,
        perRenderPassArenaSizeMB: perRenderPassArenaSizeMB,
        minCommandBufferSizeMB: minCommandBufferSizeMB,
        jobSystemThreadCount: jobSystemThreadCount,
        preferredShaderLanguage: preferredShaderLanguage,
        forceGLES2Context: forceGLES2Context,
        gpuContextPriority: gpuContextPriority,
        materialCacheCapacity: materialCacheCapacity,
        stereoscopicEyeCount: stereoscopicEyeCount,
        stereoscopicType: stereoscopicType,
        asynchronousMode: mode,
      );

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
    ptr.ref.asynchronous_mode = asynchronousMode.value;
  }
}
