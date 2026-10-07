import 'package:lumina_editor_data/lumina_editor.dart' show LuminaAttenuationModel;

/// Mixer bus an AUDIO asset belongs to: the Audio editor's `Sound Class`,
/// stored verbatim in the `.lmas` metadata.
enum AudioSoundClass {
  sfx('SFX'),
  music('Music'),
  voice('Voice'),
  ui('UI');

  const AudioSoundClass(this.label);
  final String label;

  static AudioSoundClass fromLabel(String? label) =>
      AudioSoundClass.values.firstWhere((c) => c.label == label, orElse: () => AudioSoundClass.sfx);
}

String attenuationModelLabel(LuminaAttenuationModel model) => switch (model) {
      LuminaAttenuationModel.linear => 'Linear',
      LuminaAttenuationModel.logarithmic => 'Logarithmic',
      LuminaAttenuationModel.inverse => 'Inverse (Natural Sounding)',
    };

/// Distance attenuation block — the editor-side mirror of
/// `LuminaSoundAttenuation`. The curve math itself is
/// never re-implemented here: [AudioEditorViewModel] evaluates the runtime
/// class so the plotted curve and the engine agree by construction.
class AudioAttenuationSettings {
  LuminaAttenuationModel model;
  double innerRadius;
  double falloffDistance;

  AudioAttenuationSettings({
    this.model = LuminaAttenuationModel.linear,
    this.innerRadius = 400.0,
    this.falloffDistance = 3500.0,
  });

  Map<String, dynamic> toJson() => {
        'model': model.name,
        'innerRadius': innerRadius,
        'falloffDistance': falloffDistance,
      };

  factory AudioAttenuationSettings.fromJson(Map<String, dynamic> json) {
    final name = json['model'] as String?;
    return AudioAttenuationSettings(
      model: LuminaAttenuationModel.values.firstWhere(
        (m) => m.name == name,
        orElse: () => LuminaAttenuationModel.linear,
      ),
      innerRadius: (json['innerRadius'] as num?)?.toDouble() ?? 400.0,
      falloffDistance: (json['falloffDistance'] as num?)?.toDouble() ?? 3500.0,
    );
  }

  AudioAttenuationSettings copy() => AudioAttenuationSettings(
        model: model,
        innerRadius: innerRadius,
        falloffDistance: falloffDistance,
      );

  @override
  bool operator ==(Object other) =>
      other is AudioAttenuationSettings &&
      other.model == model &&
      other.innerRadius == innerRadius &&
      other.falloffDistance == falloffDistance;

  @override
  int get hashCode => Object.hash(model, innerRadius, falloffDistance);
}

/// Everything the AudioEditor persists into `LuminaAsset.metadata['audio_settings']`
/// as one versioned JSON string (metadata is `Map<String, String>`).
class AudioSettings {
  static const int version = 1;

  double volumeMultiplier;
  double pitchMultiplier;
  double pitchRandomization;
  AudioSoundClass soundClass;
  bool looping;
  bool spatialized;
  AudioAttenuationSettings attenuation;

  AudioSettings({
    this.volumeMultiplier = 1.0,
    this.pitchMultiplier = 1.0,
    this.pitchRandomization = 0.0,
    this.soundClass = AudioSoundClass.sfx,
    this.looping = false,
    this.spatialized = true,
    AudioAttenuationSettings? attenuation,
  }) : attenuation = attenuation ?? AudioAttenuationSettings();

  Map<String, dynamic> toJson() => {
        'v': version,
        'volumeMultiplier': volumeMultiplier,
        'pitchMultiplier': pitchMultiplier,
        'pitchRandomization': pitchRandomization,
        'soundClass': soundClass.label,
        'looping': looping,
        'spatialized': spatialized,
        'attenuation': attenuation.toJson(),
      };

  factory AudioSettings.fromJson(Map<String, dynamic> json) => AudioSettings(
        volumeMultiplier: (json['volumeMultiplier'] as num?)?.toDouble() ?? 1.0,
        pitchMultiplier: (json['pitchMultiplier'] as num?)?.toDouble() ?? 1.0,
        pitchRandomization: (json['pitchRandomization'] as num?)?.toDouble() ?? 0.0,
        soundClass: AudioSoundClass.fromLabel(json['soundClass'] as String?),
        looping: json['looping'] as bool? ?? false,
        spatialized: json['spatialized'] as bool? ?? true,
        attenuation: json['attenuation'] is Map
            ? AudioAttenuationSettings.fromJson(Map<String, dynamic>.from(json['attenuation'] as Map))
            : AudioAttenuationSettings(),
      );

  AudioSettings copy() => AudioSettings(
        volumeMultiplier: volumeMultiplier,
        pitchMultiplier: pitchMultiplier,
        pitchRandomization: pitchRandomization,
        soundClass: soundClass,
        looping: looping,
        spatialized: spatialized,
        attenuation: attenuation.copy(),
      );

  @override
  bool operator ==(Object other) =>
      other is AudioSettings &&
      other.volumeMultiplier == volumeMultiplier &&
      other.pitchMultiplier == pitchMultiplier &&
      other.pitchRandomization == pitchRandomization &&
      other.soundClass == soundClass &&
      other.looping == looping &&
      other.spatialized == spatialized &&
      other.attenuation == attenuation;

  @override
  int get hashCode => Object.hash(
        volumeMultiplier,
        pitchMultiplier,
        pitchRandomization,
        soundClass,
        looping,
        spatialized,
        attenuation,
      );
}
