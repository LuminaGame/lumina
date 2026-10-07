import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/components/audio/audio_component.dart';
import 'package:lumina/src/world/subsystem/world_subsystem.dart';
import 'package:lumina/src/audio/audio_backend.dart';
import 'package:lumina/src/audio/sound_base.dart';
import 'package:lumina/src/math/euler.dart';

/// Central audio subsystem managing spatial listener coordinates, master volume, and spatial parameter updates.
class LuminaAudioSubsystem extends LuminaWorldSubsystem {
  final LuminaAudioBackend backend;
  final List<LuminaAudioComponent> _activeComponents = [];

  Vector3 listenerLocation = Vector3.zero();
  Quaternion listenerRotation = Quaternion.identity();

  double _masterVolume = 1.0;
  final List<LuminaAudioComponent> _pausedByWorld = [];
  final Map<LuminaAudioHandle, ({double volume, double pitch, double pan})> _lastPushedParams = {};

  LuminaAudioSubsystem({LuminaAudioBackend? backend}) : backend = backend ?? NullAudioBackend() {
    this.backend.onFinished = _handleAudioFinished;
  }

  /// Global master volume scalar (0.0 to 1.0).
  double get masterVolume => _masterVolume;

  /// Sound class volumes (`Master`, `Music`, `SFX`, …) for `Set Sound Class
  /// Volume`; `Master` is [masterVolume].
  final Map<String, double> _classVolumes = {};

  double classVolume(String soundClass) =>
      soundClass.toLowerCase() == 'master' ? _masterVolume : (_classVolumes[soundClass.toLowerCase()] ?? 1.0);

  void setClassVolume(String soundClass, double volume) {
    final v = volume.clamp(0.0, 1.0);
    if (soundClass.toLowerCase() == 'master') {
      masterVolume = v;
    } else {
      _classVolumes[soundClass.toLowerCase()] = v;
      _updateAllAudioParameters(force: true);
    }
  }
  set masterVolume(double v) {
    _masterVolume = v.clamp(0.0, 1.0);
    _updateAllAudioParameters(force: true);
  }

  /// Registers an active audio component.
  void registerComponent(LuminaAudioComponent comp) {
    if (!_activeComponents.contains(comp)) {
      _activeComponents.add(comp);
    }
  }

  /// Records the latest pushed parameters for an audio handle to avoid redundant updates.
  void recordPushedParams(LuminaAudioHandle handle, {required double volume, required double pitch, required double pan}) {
    _lastPushedParams[handle] = (volume: volume, pitch: pitch, pan: pan);
  }

  /// Unregisters an audio component.
  void unregisterComponent(LuminaAudioComponent comp) {
    _activeComponents.remove(comp);
  }

  @override
  void onWorldTick(double deltaTime) {
    if (backend is NullAudioBackend) {
      (backend as NullAudioBackend).tick(deltaTime);
    }
    _updateAllAudioParameters();
  }

  void _updateAllAudioParameters({bool force = false}) {
    for (final comp in _activeComponents) {
      if (!comp.isPlaying || comp.handle == null || comp.sound == null) continue;
      final handle = comp.handle!;
      final sound = comp.sound!;

      final baseGain = sound.baseVolume * comp.volumeMultiplier * comp.fadeFactor;
      final atten = comp.spatialized ? calculateAttenuation(sound, comp.worldLocation) : 1.0;
      final effectiveVol = baseGain * atten * _masterVolume;
      final effectivePitch = sound.basePitch * comp.pitchMultiplier;
      final effectivePan = comp.spatialized ? calculatePan(comp.worldLocation) : 0.0;

      final last = _lastPushedParams[handle];
      if (force || last == null || (last.volume - effectiveVol).abs() > 1e-5) {
        backend.setVolume(handle, effectiveVol);
      }
      if (force || last == null || (last.pitch - effectivePitch).abs() > 1e-5) {
        backend.setPitch(handle, effectivePitch);
      }
      if (force || last == null || (last.pan - effectivePan).abs() > 1e-5) {
        backend.setPan(handle, effectivePan);
      }

      _lastPushedParams[handle] = (volume: effectiveVol, pitch: effectivePitch, pan: effectivePan);
    }
  }

  /// Calculates the 3D distance attenuation gain for [sound] at [emitterLocation].
  double calculateAttenuation(LuminaSoundBase sound, Vector3 emitterLocation) {
    if (sound.attenuation == null) return 1.0;
    final dist = (emitterLocation - listenerLocation).length;
    return sound.attenuation!.calculateGain(dist);
  }

  /// Calculates the stereo panning scalar (-1.0 left, +1.0 right) for [emitterLocation] in listener local space.
  double calculatePan(Vector3 emitterLocation) {
    final diff = emitterLocation - listenerLocation;
    final dist = diff.length;
    if (dist < 1e-6) return 0.0;

    final localDir = listenerRotation.unrotateVector(diff);
    final horizDist = math.sqrt(localDir.x * localDir.x + localDir.z * localDir.z);
    if (horizDist < 1e-6) return 0.0;

    return (localDir.x / horizDist).clamp(-1.0, 1.0);
  }

  void _handleAudioFinished(LuminaAudioHandle handle) {
    _lastPushedParams.remove(handle);
    for (final comp in List<LuminaAudioComponent>.from(_activeComponents)) {
      if (comp.handle == handle) {
        comp.notifyFinished();
      }
    }
  }

  /// Pauses every component that is currently playing with a live handle and remembers them
  /// so [resumeAll] resumes exactly those (components paused/stopped by the user are untouched).
  void pauseAll() {
    _pausedByWorld.clear();
    for (final comp in List<LuminaAudioComponent>.from(_activeComponents)) {
      if (comp.isPlaying && comp.handle != null) {
        comp.pause();
        _pausedByWorld.add(comp);
      }
    }
  }

  /// Resumes the components paused by the last [pauseAll] that still hold their handle.
  void resumeAll() {
    for (final comp in _pausedByWorld) {
      if (comp.handle != null && _activeComponents.contains(comp)) {
        comp.resume();
      }
    }
    _pausedByWorld.clear();
  }

  @override
  void onWorldPauseChanged(bool paused) {
    if (paused) {
      pauseAll();
    } else {
      resumeAll();
    }
  }

  /// Stops all currently playing audio components.
  void stopAll() {
    for (final comp in List<LuminaAudioComponent>.from(_activeComponents)) {
      comp.stop();
    }
    _pausedByWorld.clear();
    _lastPushedParams.clear();
  }

  @override
  void onWorldShutdown() {
    stopAll();
    backend.shutdown();
  }
}
