import 'package:vector_math/vector_math_64.dart';
import '../../audio/audio_backend.dart';
import '../../audio/audio_subsystem.dart';
import '../../audio/sound_base.dart';
import '../../object/actor.dart';
import '../base/scene_component.dart';

/// Scene component that emits 2D or spatialized 3D audio instances via a pluggable audio backend.
class LuminaAudioComponent extends LuminaSceneComponent {
  LuminaSoundBase? sound;
  bool autoPlay;
  bool spatialized;

  double volumeMultiplier = 1.0;
  double pitchMultiplier = 1.0;

  double _fadeFactor = 1.0;
  double? _fadeDuration;
  double _fadeElapsed = 0.0;
  double _fadeStartVolume = 1.0;
  double _fadeTargetVolume = 1.0;
  bool _stopWhenFadeDone = false;

  LuminaAudioHandle? _handle;
  bool _isPlaying = false;

  void Function()? onAudioFinished;

  LuminaAudioComponent({
    this.sound,
    this.autoPlay = false,
    bool? spatialized,
    this.volumeMultiplier = 1.0,
    this.pitchMultiplier = 1.0,
    super.key,
    super.location,
    super.rotation,
  }) : spatialized = spatialized ?? (sound?.attenuation != null);

  /// Whether audio is actively playing on this component.
  bool get isPlaying => _isPlaying;

  /// The active audio instance handle.
  LuminaAudioHandle? get handle => _handle;

  /// Current fade multiplier factor (0.0 to 1.0).
  double get fadeFactor => _fadeFactor;

  @override
  void onRegister(LuminaActor owner) {
    super.onRegister(owner);
    final audioSys = world?.subsystems.getSubsystem<LuminaAudioSubsystem>();
    audioSys?.registerComponent(this);

    if (autoPlay && sound != null) {
      play();
    }
  }

  @override
  void onUnregister() {
    stop();
    final audioSys = world?.subsystems.getSubsystem<LuminaAudioSubsystem>();
    audioSys?.unregisterComponent(this);
    super.onUnregister();
  }

  /// Starts playback of the assigned [sound] asset.
  void play({double startVolume = 1.0}) {
    if (sound == null) return;
    final audioSys = world?.subsystems.getSubsystem<LuminaAudioSubsystem>();
    if (audioSys == null) return;

    _fadeFactor = startVolume;
    _fadeDuration = null;
    _fadeElapsed = 0.0;

    final baseGain = sound!.baseVolume * volumeMultiplier * _fadeFactor;
    final pan = spatialized ? audioSys.calculatePan(worldLocation) : 0.0;
    final atten = spatialized ? audioSys.calculateAttenuation(sound!, worldLocation) : 1.0;
    final effectiveVol = baseGain * atten * audioSys.masterVolume;
    final effectivePitch = sound!.basePitch * pitchMultiplier;

    _isPlaying = true;
    audioSys.backend.play(
      sound!,
      volume: effectiveVol,
      pitch: effectivePitch,
      pan: pan,
      looping: sound!.looping,
    ).then((h) {
      _handle = h;
      audioSys.recordPushedParams(h, volume: effectiveVol, pitch: effectivePitch, pan: pan);
    });
  }

  /// Stops audio playback and releases the active handle.
  void stop() {
    if (!_isPlaying && _handle == null) return;
    _isPlaying = false;
    if (_handle != null) {
      final audioSys = world?.subsystems.getSubsystem<LuminaAudioSubsystem>();
      audioSys?.backend.stop(_handle!);
      _handle = null;
    }
  }

  /// Pauses audio playback.
  void pause() {
    if (_handle != null) {
      final audioSys = world?.subsystems.getSubsystem<LuminaAudioSubsystem>();
      audioSys?.backend.pause(_handle!);
      _isPlaying = false;
    }
  }

  /// Resumes paused playback.
  void resume() {
    if (_handle != null) {
      final audioSys = world?.subsystems.getSubsystem<LuminaAudioSubsystem>();
      audioSys?.backend.resume(_handle!);
      _isPlaying = true;
    }
  }

  /// Initiates a linear volume fade-in ramp over [duration] seconds.
  void fadeIn(double duration, {double targetVolume = 1.0}) {
    if (duration <= 0.0) {
      _fadeFactor = targetVolume;
      _fadeDuration = null;
      if (!_isPlaying) play(startVolume: targetVolume);
      return;
    }

    final startVol = _isPlaying ? _fadeFactor : 0.0;
    if (!_isPlaying) {
      play(startVolume: startVol);
    }

    _fadeStartVolume = startVol;
    _fadeTargetVolume = targetVolume;
    _fadeDuration = duration;
    _fadeElapsed = 0.0;
    _stopWhenFadeDone = false;
  }

  /// Initiates a linear volume fade-out ramp over [duration] seconds, optionally stopping when finished.
  void fadeOut(double duration, {bool stopWhenDone = true}) {
    if (!_isPlaying) return;
    if (duration <= 0.0) {
      _fadeFactor = 0.0;
      _fadeDuration = null;
      if (stopWhenDone) stop();
      return;
    }

    _fadeStartVolume = _fadeFactor;
    _fadeTargetVolume = 0.0;
    _fadeDuration = duration;
    _fadeElapsed = 0.0;
    _stopWhenFadeDone = stopWhenDone;
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);

    if (_fadeDuration != null && _isPlaying) {
      _fadeElapsed += deltaTime;
      final t = (_fadeElapsed / _fadeDuration!).clamp(0.0, 1.0);
      _fadeFactor = _fadeStartVolume + (_fadeTargetVolume - _fadeStartVolume) * t;

      if (t >= 1.0 || _fadeElapsed >= _fadeDuration! - 1e-6) {
        _fadeFactor = _fadeTargetVolume;
        _fadeDuration = null;
        if (_stopWhenFadeDone && _fadeTargetVolume == 0.0) {
          stop();
        }
      }
    }
  }

  /// Called by the subsystem when the backend signals that this audio handle has finished.
  void notifyFinished() {
    _isPlaying = false;
    _handle = null;
    onAudioFinished?.call();
  }
}
