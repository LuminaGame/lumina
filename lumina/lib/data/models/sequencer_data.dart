import 'dart:convert';
import 'dart:typed_data';

enum KeyInterpolation {
  constant,
  linear,
  cubic;

  String toJson() => name;

  static KeyInterpolation fromJson(String name) {
    return KeyInterpolation.values.firstWhere(
      (e) => e.name.toLowerCase() == name.toLowerCase(),
      orElse: () => KeyInterpolation.linear,
    );
  }
}

class SequencerKey {
  int frame;
  double value;
  KeyInterpolation interpolation;
  double inTangent;
  double outTangent;

  SequencerKey({
    required this.frame,
    required this.value,
    this.interpolation = KeyInterpolation.linear,
    this.inTangent = 0.0,
    this.outTangent = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'frame': frame,
        'value': value,
        'interpolation': interpolation.toJson(),
        'in_tangent': inTangent,
        'out_tangent': outTangent,
      };

  factory SequencerKey.fromJson(Map<String, dynamic> json) => SequencerKey(
        frame: json['frame'] as int? ?? 0,
        value: (json['value'] as num?)?.toDouble() ?? 0.0,
        interpolation: KeyInterpolation.fromJson(json['interpolation'] as String? ?? 'linear'),
        inTangent: (json['in_tangent'] as num?)?.toDouble() ?? 0.0,
        outTangent: (json['out_tangent'] as num?)?.toDouble() ?? 0.0,
      );

  SequencerKey copyWith({
    int? frame,
    double? value,
    KeyInterpolation? interpolation,
    double? inTangent,
    double? outTangent,
  }) {
    return SequencerKey(
      frame: frame ?? this.frame,
      value: value ?? this.value,
      interpolation: interpolation ?? this.interpolation,
      inTangent: inTangent ?? this.inTangent,
      outTangent: outTangent ?? this.outTangent,
    );
  }
}

class SequencerChannel {
  String name;
  List<SequencerKey> keys;

  SequencerChannel({
    required this.name,
    List<SequencerKey>? keys,
  }) : keys = keys ?? [];

  Map<String, dynamic> toJson() => {
        'name': name,
        'keys': keys.map((k) => k.toJson()).toList(),
      };

  factory SequencerChannel.fromJson(Map<String, dynamic> json) => SequencerChannel(
        name: json['name'] as String? ?? '',
        keys: (json['keys'] as List<dynamic>?)
                ?.map((k) => SequencerKey.fromJson(k as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

enum SequencerTrackKind {
  transform,
  property,
  visibility;

  String toJson() => name;

  static SequencerTrackKind fromJson(String name) {
    return SequencerTrackKind.values.firstWhere(
      (e) => e.name.toLowerCase() == name.toLowerCase(),
      orElse: () => SequencerTrackKind.property,
    );
  }
}

class SequencerTrack {
  String id;
  String actorId;
  String actorName;
  SequencerTrackKind kind;
  String? propertyName;
  List<SequencerChannel> channels;

  SequencerTrack({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.kind,
    this.propertyName,
    List<SequencerChannel>? channels,
  }) : channels = channels ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'actor_id': actorId,
        'actor_name': actorName,
        'kind': kind.toJson(),
        if (propertyName != null) 'property_name': propertyName,
        'channels': channels.map((c) => c.toJson()).toList(),
      };

  factory SequencerTrack.fromJson(Map<String, dynamic> json) => SequencerTrack(
        id: json['id'] as String? ?? '',
        actorId: json['actor_id'] as String? ?? '',
        actorName: json['actor_name'] as String? ?? '',
        kind: SequencerTrackKind.fromJson(json['kind'] as String? ?? 'property'),
        propertyName: json['property_name'] as String?,
        channels: (json['channels'] as List<dynamic>?)
                ?.map((c) => SequencerChannel.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class SequencerData {
  int version;
  int fps;
  int lengthFrames;
  List<SequencerTrack> tracks;

  SequencerData({
    this.version = 1,
    this.fps = 30,
    this.lengthFrames = 120,
    List<SequencerTrack>? tracks,
  }) : tracks = tracks ?? [];

  Map<String, dynamic> toJson() => {
        'v': version,
        'fps': fps,
        'length_frames': lengthFrames,
        'tracks': tracks.map((t) => t.toJson()).toList(),
      };

  factory SequencerData.fromJson(Map<String, dynamic> json) => SequencerData(
        version: json['v'] as int? ?? 1,
        fps: json['fps'] as int? ?? 30,
        lengthFrames: json['length_frames'] as int? ?? 120,
        tracks: (json['tracks'] as List<dynamic>?)
                ?.map((t) => SequencerTrack.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [],
      );

  Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  factory SequencerData.fromBytes(Uint8List bytes) {
    if (bytes.isEmpty) return SequencerData();
    final jsonStr = utf8.decode(bytes);
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return SequencerData.fromJson(map);
  }
}
