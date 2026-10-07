import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/features/sub_editors/models/audio_editor_state.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/audio_wav_decoder_service.dart';

/// View model behind the AudioEditor.
///
/// Honest scope: the engine's audio layer is pure Dart over a pluggable
/// [LuminaAudioBackend] and **no real backend is chosen yet**. So this view model decodes the PCM itself, drives
/// the playhead from ticked game time, derives the VU meter from the decoded
/// samples, and routes every transport action through the backend interface —
/// audible when a real backend is registered, silent-but-functional with
/// [NullAudioBackend].
class AudioEditorViewModel extends ChangeNotifier {
  AudioEditorViewModel({
    required this.assetPath,
    LuminaAudioBackend? backend,
    LuminaAsset? initialAsset,
  })  : _backend = backend ?? NullAudioBackend(),
        // ignore: prefer_initializing_formals
        _initialAsset = initialAsset {
    _previousOnFinished = _backend.onFinished;
    _backend.onFinished = _handleBackendFinished;
  }

  final String assetPath;
  final LuminaAudioBackend _backend;
  final LuminaAsset? _initialAsset;
  void Function(LuminaAudioHandle)? _previousOnFinished;

  LuminaAudioBackend get backend => _backend;
  bool get hasRealBackend => _backend is! NullAudioBackend;

  String get backendStatus => hasRealBackend
      ? 'Playback backend: ${_backend.runtimeType}'
      : 'No audio backend registered — preview is silent (${_backend.runtimeType})';

  // --- load state ----------------------------------------------------------

  LuminaAsset? _asset;
  DecodedAudio? _audio;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  LuminaAsset? get asset => _asset;
  DecodedAudio? get audio => _audio;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;

  // --- settings ------------------------------------------------------------

  AudioSettings _settings = AudioSettings();
  AudioSettings _saved = AudioSettings();

  AudioSettings get settings => _settings;
  bool get isDirty => _settings != _saved;

  // --- transport -----------------------------------------------------------

  bool _isPlaying = false;
  double _positionSeconds = 0.0;
  LuminaAudioHandle? _activeHandle;
  int _finishedCount = 0;
  List<double> _vuPeaks = const [0.0, 0.0];

  bool get isPlaying => _isPlaying;
  double get positionSeconds => _positionSeconds;
  LuminaAudioHandle? get activeHandle => _activeHandle;
  int get finishedCount => _finishedCount;
  List<double> get vuPeaks => List.unmodifiable(_vuPeaks);

  double get duration => _audio?.duration ?? 0.0;
  double get playbackFraction => duration <= 0 ? 0.0 : (_positionSeconds / duration).clamp(0.0, 1.0);

  /// Base volume of the previewed sound; the effective volume handed to the
  /// backend is `baseVolume · volumeMultiplier`.
  static const double baseVolume = 1.0;
  double get effectiveVolume => baseVolume * _settings.volumeMultiplier;

  // --- waveform zoom -------------------------------------------------------

  double _zoom = 1.0;
  double _viewStartFraction = 0.0;

  double get zoom => _zoom;
  double get viewStartFraction => _viewStartFraction;

  int get visibleStartFrame {
    final total = _audio?.frameCount ?? 0;
    return (total * _viewStartFraction).round().clamp(0, total);
  }

  int get visibleEndFrame {
    final total = _audio?.frameCount ?? 0;
    final span = (total / _zoom).round();
    return math.min(total, visibleStartFrame + math.max(1, span));
  }

  // --- attenuation ---------------------------------------------------------

  double _probeDistance = 1200.0;

  double get probeDistance => _probeDistance;
  double get outerDistance => _settings.attenuation.innerRadius + _settings.attenuation.falloffDistance;

  /// The curve canvas plots 0 → outer × 1.2 so the floor beyond the falloff
  /// edge stays visible.
  double get plotMaxDistance => math.max(1.0, outerDistance * 1.2);

  double get innerRadiusHandleFraction => (_settings.attenuation.innerRadius / plotMaxDistance).clamp(0.0, 1.0);
  double get falloffHandleFraction => (outerDistance / plotMaxDistance).clamp(0.0, 1.0);

  /// Gain at [distance] — evaluated by the runtime's own
  /// [LuminaSoundAttenuation], so the plot and the engine cannot drift.
  double gainAt(double distance) => LuminaSoundAttenuation(
        innerRadius: _settings.attenuation.innerRadius,
        falloffDistance: _settings.attenuation.falloffDistance,
        model: _settings.attenuation.model,
      ).calculateGain(distance);

  double get probeGain => gainAt(_probeDistance);

  String get probeLabel => 'd = ${_probeDistance.toStringAsFixed(1)} → gain ${probeGain.toStringAsFixed(3)}';

  // --- header facts --------------------------------------------------------

  String get fileBasename => assetPath.split(Platform.pathSeparator).last.replaceAll('.lmas', '');
  String get sampleRateLabel => _audio == null ? '—' : '${_audio!.sampleRate} Hz';
  String get bitDepthLabel =>
      _audio == null ? '—' : (_audio!.isFloat ? '${_audio!.bitDepth}-bit Float' : '${_audio!.bitDepth}-bit PCM');
  String get channelsLabel => _audio == null
      ? '—'
      : _audio!.channels == 1
          ? 'Mono'
          : 'Stereo';
  String get durationLabel => formatTime(duration);
  String get sampleCountLabel => _audio == null ? '—' : '${_audio!.frameCount} samples';
  String get positionLabel => '${formatTime(_positionSeconds)} / ${formatTime(duration)}';

  static String formatTime(double seconds) {
    final s = seconds.isFinite && seconds > 0 ? seconds : 0.0;
    final minutes = s ~/ 60;
    final rest = s - minutes * 60;
    final whole = rest.floor();
    final millis = ((rest - whole) * 1000).round().clamp(0, 999);
    return '${minutes.toString().padLeft(2, '0')}:${whole.toString().padLeft(2, '0')}.${millis.toString().padLeft(3, '0')}';
  }

  // --- loading -------------------------------------------------------------

  Future<void> load() async {
    _isLoading = true;
    _hasError = false;
    _errorMessage = null;
    notifyListeners();

    try {
      var asset = _initialAsset;
      if (asset == null) {
        final file = File(assetPath);
        if (await file.exists()) {
          asset = LuminaAsset.fromBytes(await file.readAsBytes());
        }
      }
      _asset = asset;

      final storedJson = asset?.metadata['audio_settings'];
      if (storedJson != null && storedJson.isNotEmpty) {
        try {
          _settings = AudioSettings.fromJson(jsonDecode(storedJson) as Map<String, dynamic>);
        } catch (_) {
          _settings = AudioSettings();
        }
      } else {
        _settings = AudioSettings();
      }
      _saved = _settings.copy();
      _probeDistance = math.min(_probeDistance, plotMaxDistance);

      final payload = asset?.rawPayload;
      if (payload == null || payload.isEmpty) {
        _audio = null;
        _hasError = true;
        _errorMessage = 'This AUDIO asset carries no payload — re-import the source .wav file.';
      } else {
        try {
          _audio = WavDecoderService.decode(payload);
          _vuPeaks = List<double>.filled(_audio!.channels, 0.0);
        } on WavDecodeException catch (e) {
          _audio = null;
          _hasError = true;
          _errorMessage = e.message;
        }
      }
    } catch (e) {
      _audio = null;
      _hasError = true;
      _errorMessage = 'Failed to open the AUDIO asset: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- transport -----------------------------------------------------------

  Future<void> play() async {
    final decoded = _audio;
    if (decoded == null) return;
    if (_isPlaying) stop();
    if (_positionSeconds >= duration) _positionSeconds = 0.0;

    final sound = LuminaSoundWave(
      assetPath: assetPath,
      soundId: fileBasename,
      baseVolume: baseVolume,
      basePitch: _settings.pitchMultiplier,
      looping: _settings.looping,
      duration: math.max(0.0, duration - _positionSeconds),
      attenuation: _settings.spatialized
          ? LuminaSoundAttenuation(
              innerRadius: _settings.attenuation.innerRadius,
              falloffDistance: _settings.attenuation.falloffDistance,
              model: _settings.attenuation.model,
            )
          : null,
    );

    _activeHandle = await _backend.play(
      sound,
      volume: effectiveVolume,
      pitch: _settings.pitchMultiplier,
      pan: 0.0,
      looping: _settings.looping,
    );
    _isPlaying = true;
    _updateVu();
    notifyListeners();
  }

  void stop() {
    final handle = _activeHandle;
    if (handle != null) _backend.stop(handle);
    _activeHandle = null;
    _isPlaying = false;
    _positionSeconds = 0.0;
    _updateVu();
    notifyListeners();
  }

  /// Advances the playhead by [dt] seconds of **game-tick** time (never a
  /// wall-clock `Timer`), and advances the headless backend simulation so a
  /// non-looping preview really ends through `onFinished`.
  void tick(double dt) {
    if (!_isPlaying || _audio == null || dt <= 0) return;
    _positionSeconds += dt;
    final total = duration;
    if (_settings.looping) {
      if (total > 0 && _positionSeconds >= total) _positionSeconds = _positionSeconds % total;
    } else if (_positionSeconds > total) {
      _positionSeconds = total;
    }

    final b = _backend;
    if (b is NullAudioBackend) b.tick(dt);

    _updateVu();
    notifyListeners();
  }

  void _handleBackendFinished(LuminaAudioHandle handle) {
    _previousOnFinished?.call(handle);
    // A late callback for an already-stopped handle is dropped silently
    // (runtime spec pitfall).
    if (_activeHandle == null || handle != _activeHandle) return;
    _activeHandle = null;
    _isPlaying = false;
    _positionSeconds = duration;
    _finishedCount++;
    _updateVu();
    notifyListeners();
  }

  void seekSeconds(double seconds) {
    _positionSeconds = seconds.clamp(0.0, duration);
    _updateVu();
    notifyListeners();
  }

  void seekFraction(double fraction) => seekSeconds(fraction.clamp(0.0, 1.0) * duration);

  void _updateVu() {
    final decoded = _audio;
    if (decoded == null) {
      _vuPeaks = const [0.0, 0.0];
      return;
    }
    _vuPeaks = List<double>.generate(decoded.channels, (c) => decoded.peakAt(c, _positionSeconds));
  }

  // --- waveform zoom -------------------------------------------------------

  void setZoom(double zoom, {double focusFraction = 0.5}) {
    final clamped = zoom.clamp(1.0, 512.0);
    final total = _audio?.frameCount ?? 0;
    if (total == 0) return;
    final focusAbsolute = _viewStartFraction + focusFraction / _zoom;
    _zoom = clamped.toDouble();
    _viewStartFraction = (focusAbsolute - focusFraction / _zoom).clamp(0.0, 1.0 - 1.0 / _zoom);
    notifyListeners();
  }

  void zoomBy(double factor, {double focusFraction = 0.5}) => setZoom(_zoom * factor, focusFraction: focusFraction);

  // --- property setters ----------------------------------------------------

  void setVolumeMultiplier(double v) {
    _settings.volumeMultiplier = v.clamp(0.0, 2.0);
    final handle = _activeHandle;
    if (handle != null) _backend.setVolume(handle, effectiveVolume);
    notifyListeners();
  }

  void setPitchMultiplier(double v) {
    _settings.pitchMultiplier = v.clamp(0.5, 2.0);
    final handle = _activeHandle;
    if (handle != null) _backend.setPitch(handle, _settings.pitchMultiplier);
    notifyListeners();
  }

  void setPitchRandomization(double v) {
    _settings.pitchRandomization = v.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setSoundClass(AudioSoundClass c) {
    _settings.soundClass = c;
    notifyListeners();
  }

  void setLooping(bool value) {
    _settings.looping = value;
    notifyListeners();
  }

  void setSpatialized(bool value) {
    _settings.spatialized = value;
    notifyListeners();
  }

  void setAttenuationModel(LuminaAttenuationModel model) {
    _settings.attenuation.model = model;
    notifyListeners();
  }

  /// Moves the inner-radius handle. The falloff edge (`inner + falloff`) is
  /// held still — the two handles share one axis and must not cross, so the
  /// falloff shrinks as the inner radius grows (validation: inner ≤ outer).
  void setInnerRadius(double value) {
    final outer = outerDistance;
    final inner = value.clamp(0.0, outer).toDouble();
    _settings.attenuation.innerRadius = inner;
    _settings.attenuation.falloffDistance = math.max(0.0, outer - inner);
    notifyListeners();
  }

  void setFalloffDistance(double value) {
    _settings.attenuation.falloffDistance = math.max(0.0, value);
    notifyListeners();
  }

  /// Canvas drag → distance. [fraction] is the pointer's x position across the
  /// curve canvas, which spans `0 → plotMaxDistance`.
  void dragInnerRadiusToFraction(double fraction) =>
      setInnerRadius(fraction.clamp(0.0, 1.0) * plotMaxDistance);

  void dragFalloffEdgeToFraction(double fraction) {
    final target = fraction.clamp(0.0, 1.0) * plotMaxDistance;
    setFalloffDistance(target - _settings.attenuation.innerRadius);
  }

  void setProbeDistance(double value) {
    _probeDistance = value.clamp(0.0, plotMaxDistance);
    notifyListeners();
  }

  // --- persistence ---------------------------------------------------------

  Future<bool> save() async {
    try {
      final file = File(assetPath);
      LuminaAsset? current = _asset;
      if (await file.exists()) {
        current = LuminaAsset.fromBytes(await file.readAsBytes());
      }
      if (current == null) return false;

      final metadata = Map<String, String>.from(current.metadata);
      metadata['audio_settings'] = jsonEncode(_settings.toJson());

      final updated = LuminaAsset(
        assetId: current.assetId,
        name: current.name,
        type: current.type,
        hasThumbnail: current.hasThumbnail,
        thumbnailPng: current.thumbnailPng,
        rawPayload: current.rawPayload,
        rawMatSource: current.rawMatSource,
        references: current.references,
        metadata: metadata,
      );

      await file.parent.create(recursive: true);
      await file.writeAsBytes(updated.toProtoBufferBytes());
      _asset = updated;
      _saved = _settings.copy();
      notifyListeners();
      return true;
    } catch (e) {
      EngineLoggerService().log('Failed to save AUDIO asset: $e', level: 'error', source: 'AudioEditor');
      return false;
    }
  }

  @override
  void dispose() {
    final handle = _activeHandle;
    if (handle != null) _backend.stop(handle);
    _activeHandle = null;
    if (_backend.onFinished == _handleBackendFinished) {
      _backend.onFinished = _previousOnFinished;
    }
    _previousOnFinished = null;
    super.dispose();
  }
}
