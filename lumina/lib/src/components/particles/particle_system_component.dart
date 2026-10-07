import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/world/world.dart';
import 'package:lumina/src/components/base/scene_component.dart';
import 'package:lumina/src/components/mesh/procedural_mesh_component.dart';
import 'package:lumina/src/components/particles/particle_emitter_config.dart';
import 'package:lumina/src/math/euler.dart';

/// Scene component that simulates CPU particles and renders them as a pool of Filament instanced meshes.
class LuminaParticleSystemComponent extends LuminaSceneComponent {
  final LuminaParticleEmitterConfig config;
  bool autoActivate;
  int? randomSeed;

  late math.Random _random;
  bool _isActive = false;
  double _cycleTime = 0.0;
  double _spawnCarry = 0.0;
  final Set<int> _firedBurstsThisCycle = {};

  int _liveCount = 0;
  late Float32List _posX;
  late Float32List _posY;
  late Float32List _posZ;
  late Float32List _velX;
  late Float32List _velY;
  late Float32List _velZ;
  late Float32List _age;
  late Float32List _lifetime;

  late Int32List _poolIndices;
  late Int32List _freeIndices;
  int _freeCount = 0;

  void Function()? onSystemFinished;

  /// Parameters Blueprints set by name (`Set Particle Parameter`):
  /// `SpawnRate` overrides the config's rate; other names are
  /// kept for the renderer / a project's own emitters.
  final Map<String, Object?> parameters = {};

  /// The config's spawn rate, or the `SpawnRate` parameter when set.
  double get spawnRate {
    final p = parameters['SpawnRate'];
    return p is num ? p.toDouble() : config.spawnRate;
  }
  bool _finishedFired = false;

  final Vector3 _lastWorldLocation = Vector3.zero();
  Vector3 _emitterVelocity = Vector3.zero();

  // Rendering state: one batched section holding a pair of crossed quads per
  // live particle, rebuilt every render prep from the simulation buffers.
  FilamentEngine? _engine;
  LuminaProceduralMeshComponent? _spriteMesh;
  FilamentMaterialProvider? _materialProvider;
  FilamentMaterialInstance? _spriteMaterial;
  int _renderedParticleCount = 0;

  static const int _spriteSection = 0;
  static const int _vertsPerParticle = 8;
  static const int _indicesPerParticle = 12;

  /// World-space half-extent of a particle sprite at curve scale 1.0.
  double spriteHalfSize = 10.0; // cm

  LuminaParticleSystemComponent({
    super.key,
    required this.config,
    this.autoActivate = true,
    this.randomSeed,
    super.location,
    super.rotation,
    super.scale,
  }) {
    _initBuffers();
    if (autoActivate) {
      activate();
    }
  }

  void _initBuffers() {
    _random = math.Random(randomSeed);
    final cap = config.maxParticles;

    _posX = Float32List(cap);
    _posY = Float32List(cap);
    _posZ = Float32List(cap);
    _velX = Float32List(cap);
    _velY = Float32List(cap);
    _velZ = Float32List(cap);
    _age = Float32List(cap);
    _lifetime = Float32List(cap);

    _poolIndices = Int32List(cap);
    _freeIndices = Int32List(cap);
    _freeCount = cap;
    for (int i = 0; i < cap; i++) {
      _freeIndices[i] = i;
    }
    _liveCount = 0;
  }

  int get liveParticleCount => _liveCount;
  bool get isActive => _isActive;

  Vector3 getParticlePosition(int index) {
    if (index < 0 || index >= _liveCount) return Vector3.zero();
    return Vector3(_posX[index], _posY[index], _posZ[index]);
  }

  /// Particles drawn at the last render prep.
  int get renderedParticleCount => _renderedParticleCount;

  /// Whether the batched sprite geometry currently exists on the scene.
  bool get hasSpriteGeometry => _spriteMesh?.hasSection(_spriteSection) ?? false;

  /// Vertices in the batched sprite section (8 per drawn particle).
  int get spriteVertexCount => _renderedParticleCount * _vertsPerParticle;

  /// Normalized age of live particle [index] in `[0, 1]`.
  double particleAgeAt(int index) {
    if (index < 0 || index >= _liveCount) return 0.0;
    final lt = _lifetime[index];
    return lt > 0 ? (_age[index] / lt).clamp(0.0, 1.0) : 0.0;
  }

  /// The colour live particle [index] is drawn with, from its own age.
  Vector4 particleColorAt(int index) => config.sampleColorAt(particleAgeAt(index));

  /// The size multiplier live particle [index] is drawn with, from its own age.
  double particleSizeAt(int index) => config.sampleSizeAt(particleAgeAt(index));

  Vector3 getParticleVelocity(int index) {
    if (index < 0 || index >= _liveCount) return Vector3.zero();
    return Vector3(_velX[index], _velY[index], _velZ[index]);
  }

  /// Activates particle emission. If [reset] is true, resets all live simulation state.
  void activate({bool reset = false}) {
    if (reset) {
      resetSimulation();
    }
    _isActive = true;
  }

  /// Deactivates particle emission. Existing live particles continue until end of life.
  void deactivate() {
    _isActive = false;
  }

  /// Resets particle simulation and recycles all active particles.
  void resetSimulation() {
    _clearSprites();
    _liveCount = 0;
    _freeCount = config.maxParticles;
    for (int i = 0; i < _freeCount; i++) {
      _freeIndices[i] = i;
    }
    _cycleTime = 0.0;
    _spawnCarry = 0.0;
    _firedBurstsThisCycle.clear();
    _finishedFired = false;
  }

  @override
  void onRegister(LuminaActor ownerActor) {
    super.onRegister(ownerActor);
    _lastWorldLocation.setFrom(worldLocation);

    final w = ownerActor.world;
    if (w != null && w.hasNativeContext) {
      _engine = w.filamentEngine;
      // The sprite mesh authors world-space vertices, so it deliberately
      // carries no transform of its own.
      final mesh = LuminaProceduralMeshComponent();
      mesh.onRegister(ownerActor);
      _spriteMesh = mesh;
    }
  }

  @override
  void onUnregister() {
    resetSimulation();
    // Order matters: the geometry referencing the instance goes first, then
    // the instance, then the provider that owns the material — Filament panics
    // when a material is destroyed with instances still alive.
    _spriteMesh?.onUnregister();
    _spriteMesh = null;
    try {
      _spriteMaterial?.dispose();
    } catch (_) {}
    _spriteMaterial = null;
    try {
      _materialProvider?.dispose();
    } catch (_) {}
    _materialProvider = null;
    _engine = null;
    super.onUnregister();
  }

  @override
  void onTick(double deltaTime) {
    if (deltaTime <= 0.0) return;

    // Track emitter velocity
    final curLoc = worldLocation;
    _emitterVelocity = (curLoc - _lastWorldLocation) / deltaTime;
    _lastWorldLocation.setFrom(curLoc);

    // 1. Advance active particles
    int i = 0;
    while (i < _liveCount) {
      _age[i] += deltaTime;

      if (_age[i] >= _lifetime[i]) {
        // Kill particle: swap-remove
        _killParticleAt(i);
      } else {
        // Explicit Euler Integration: v += g*dt; v *= (1 - drag*dt); p += v*dt
        _velX[i] += config.gravity.x * deltaTime;
        _velY[i] += config.gravity.y * deltaTime;
        _velZ[i] += config.gravity.z * deltaTime;

        if (config.drag > 0.0) {
          final dragFactor = math.max(0.0, 1.0 - config.drag * deltaTime);
          _velX[i] *= dragFactor;
          _velY[i] *= dragFactor;
          _velZ[i] *= dragFactor;
        }

        _posX[i] += _velX[i] * deltaTime;
        _posY[i] += _velY[i] * deltaTime;
        _posZ[i] += _velZ[i] * deltaTime;

        i++;
      }
    }

    // 2. Spawn new particles if active
    if (_isActive) {
      _cycleTime += deltaTime;

      if (config.looping && config.duration > 0.0) {
        if (_cycleTime >= config.duration) {
          _cycleTime = _cycleTime % config.duration;
          _firedBurstsThisCycle.clear();
        }
      }

      // Check bursts
      for (int b = 0; b < config.bursts.length; b++) {
        if (_firedBurstsThisCycle.contains(b)) continue;
        final burst = config.bursts[b];
        if (burst.time <= _cycleTime) {
          _firedBurstsThisCycle.add(b);
          _spawnParticles(burst.count);
        }
      }

      // Continuous spawning
      if (spawnRate > 0.0) {
        _spawnCarry += spawnRate * deltaTime;
        final toSpawn = _spawnCarry.floor();
        if (toSpawn > 0) {
          _spawnCarry -= toSpawn;
          _spawnParticles(toSpawn);
        }
      }

      // Check non-looping finish
      if (!config.looping) {
        final allBurstsFired = _firedBurstsThisCycle.length >= config.bursts.length;
        if (allBurstsFired && _liveCount == 0 && !_finishedFired) {
          _finishedFired = true;
          _isActive = false;
          onSystemFinished?.call();
        }
      }
    } else {
      if (!config.looping && _liveCount == 0 && !_finishedFired) {
        _finishedFired = true;
        onSystemFinished?.call();
      }
    }

    if (!config.looping && !_finishedFired) {
      final allBurstsFired = _firedBurstsThisCycle.length >= config.bursts.length;
      if (allBurstsFired && _liveCount == 0) {
        _finishedFired = true;
        _isActive = false;
        onSystemFinished?.call();
      }
    }
  }

  void _spawnParticles(int count) {
    final available = math.min(count, _freeCount);
    if (available <= 0) return;

    final spawnOrigin = worldLocation;
    final fwd = forwardVector.normalized();

    for (int k = 0; k < available; k++) {
      final slot = _liveCount;
      final poolIdx = _freeIndices[--_freeCount];
      _poolIndices[slot] = poolIdx;

      _posX[slot] = spawnOrigin.x;
      _posY[slot] = spawnOrigin.y;
      _posZ[slot] = spawnOrigin.z;

      // Lifetime in range
      final ltSpan = config.lifetimeMax - config.lifetimeMin;
      _lifetime[slot] = config.lifetimeMin + (ltSpan > 0 ? _random.nextDouble() * ltSpan : 0.0);
      _age[slot] = 0.0;

      // Velocity computation
      final speedSpan = config.speedMax - config.speedMin;
      final speed = config.speedMin + (speedSpan > 0 ? _random.nextDouble() * speedSpan : 0.0);

      Vector3 dir;
      if (config.coneAngleDegrees <= 0.0) {
        dir = fwd.clone();
      } else if (config.coneAngleDegrees >= 180.0) {
        // Uniform sphere
        final u = _random.nextDouble() * 2.0 - 1.0;
        final theta = _random.nextDouble() * 2.0 * math.pi;
        final r = math.sqrt(math.max(0.0, 1.0 - u * u));
        dir = Vector3(r * math.cos(theta), u, r * math.sin(theta));
      } else {
        // Cone around fwd
        final maxAngleRad = config.coneAngleDegrees * math.pi / 180.0;
        final cosAngle = 1.0 - _random.nextDouble() * (1.0 - math.cos(maxAngleRad));
        final sinAngle = math.sqrt(math.max(0.0, 1.0 - cosAngle * cosAngle));
        final phi = _random.nextDouble() * 2.0 * math.pi;

        final localDir = Vector3(sinAngle * math.cos(phi), sinAngle * math.sin(phi), -cosAngle);
        final rot = Quaternion.fromTwoVectors(Vector3(0.0, 0.0, -1.0), fwd);
        dir = rot.rotateVector(localDir);
      }

      if (dir.length > 1e-6) dir.normalize();

      _velX[slot] = dir.x * speed + _emitterVelocity.x * config.inheritVelocityScale.x;
      _velY[slot] = dir.y * speed + _emitterVelocity.y * config.inheritVelocityScale.y;
      _velZ[slot] = dir.z * speed + _emitterVelocity.z * config.inheritVelocityScale.z;

      _liveCount++;
    }
  }

  void _killParticleAt(int index) {
    final poolIdx = _poolIndices[index];
    _freeIndices[_freeCount++] = poolIdx;

    final last = _liveCount - 1;
    if (index != last) {
      _posX[index] = _posX[last];
      _posY[index] = _posY[last];
      _posZ[index] = _posZ[last];
      _velX[index] = _velX[last];
      _velY[index] = _velY[last];
      _velZ[index] = _velZ[last];
      _age[index] = _age[last];
      _lifetime[index] = _lifetime[last];
      _poolIndices[index] = _poolIndices[last];
    }
    _liveCount--;
  }

  @override
  void onRenderPrep(LuminaWorld world) {
    final mesh = _spriteMesh;
    if (mesh == null) return;
    if (_liveCount == 0) {
      _clearSprites();
      return;
    }

    final material = _spriteMaterial ??= _createSpriteMaterial();
    final live = _liveCount;
    final positions = Float32List(live * _vertsPerParticle * 3);
    final normals = Float32List(live * _vertsPerParticle * 3);
    final uvs = Float32List(live * _vertsPerParticle * 2);
    final colors = Uint8List(live * _vertsPerParticle * 4);
    final indices = Uint32List(live * _indicesPerParticle);

    for (int i = 0; i < live; i++) {
      final normAge = particleAgeAt(i);
      final rgba = config.sampleColorAt(normAge);
      final r = (rgba.x.clamp(0.0, 1.0) * 255).round();
      final g = (rgba.y.clamp(0.0, 1.0) * 255).round();
      final b = (rgba.z.clamp(0.0, 1.0) * 255).round();
      final a = (rgba.w.clamp(0.0, 1.0) * 255).round();
      final half = spriteHalfSize * config.sampleSizeAt(normAge);
      final px = _posX[i], py = _posY[i], pz = _posZ[i];
      final base = i * _vertsPerParticle * 3;

      // Two crossed quads: the sprite reads from any viewing angle without
      // needing the camera basis here.
      _writeVert(positions, base, 0, px - half, py - half, pz);
      _writeVert(positions, base, 1, px + half, py - half, pz);
      _writeVert(positions, base, 2, px + half, py + half, pz);
      _writeVert(positions, base, 3, px - half, py + half, pz);
      _writeVert(positions, base, 4, px, py - half, pz - half);
      _writeVert(positions, base, 5, px, py - half, pz + half);
      _writeVert(positions, base, 6, px, py + half, pz + half);
      _writeVert(positions, base, 7, px, py + half, pz - half);

      for (int v = 0; v < _vertsPerParticle; v++) {
        final idx = i * _vertsPerParticle + v;
        normals[idx * 3] = v < 4 ? 0.0 : 1.0;
        normals[idx * 3 + 2] = v < 4 ? 1.0 : 0.0;
        uvs[idx * 2] = (v % 4 == 1 || v % 4 == 2) ? 1.0 : 0.0;
        uvs[idx * 2 + 1] = (v % 4 >= 2) ? 1.0 : 0.0;
        colors[idx * 4] = r;
        colors[idx * 4 + 1] = g;
        colors[idx * 4 + 2] = b;
        colors[idx * 4 + 3] = a;
      }

      final vBase = i * _vertsPerParticle;
      final o = i * _indicesPerParticle;
      indices[o] = vBase;
      indices[o + 1] = vBase + 1;
      indices[o + 2] = vBase + 2;
      indices[o + 3] = vBase;
      indices[o + 4] = vBase + 2;
      indices[o + 5] = vBase + 3;
      indices[o + 6] = vBase + 4;
      indices[o + 7] = vBase + 5;
      indices[o + 8] = vBase + 6;
      indices[o + 9] = vBase + 4;
      indices[o + 10] = vBase + 6;
      indices[o + 11] = vBase + 7;
    }

    try {
      mesh.clearMeshSection(_spriteSection);
      mesh.createMeshSection(
        _spriteSection,
        positions: positions,
        normals: normals,
        uv0: uvs,
        colors: colors,
        indices: indices,
        material: material,
        dynamic: true,
      );
      mesh.setSectionVisible(_spriteSection, true);
      _renderedParticleCount = live;
    } catch (_) {
      _renderedParticleCount = 0;
    }
  }

  static void _writeVert(Float32List out, int base, int v, double x, double y, double z) {
    out[base + v * 3] = x;
    out[base + v * 3 + 1] = y;
    out[base + v * 3 + 2] = z;
  }

  void _clearSprites() {
    _renderedParticleCount = 0;
    final mesh = _spriteMesh;
    if (mesh != null && mesh.hasSection(_spriteSection)) {
      mesh.clearMeshSection(_spriteSection);
    }
  }

  /// Unlit, alpha-blended, double-sided ubershader instance driven by the
  /// per-vertex particle colours.
  FilamentMaterialInstance? _createSpriteMaterial() {
    final engine = _engine;
    if (engine == null) return null;
    try {
      final provider = _materialProvider ??= FilamentMaterialProvider.ubershader(engine);
      final result = provider.createMaterialInstance(
        MaterialKey(unlit: true, alphaMode: 2, doubleSided: true, hasVertexColors: true),
        label: 'lumina_particles',
      );
      final mi = result.instance;
      if (mi == null) return null;
      mi.setFloat4('baseColorFactor', 1.0, 1.0, 1.0, 1.0);
      mi.setCullingMode(CullingMode.none);
      mi.setDepthWrite(false);
      return mi;
    } catch (_) {
      return null;
    }
  }
}
