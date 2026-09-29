class SkeletalMeshSocket {
  String name;
  String parentBone;
  List<double> relativeLocation; // [x, y, z]
  List<double> relativeRotation; // [roll, pitch, yaw] in degrees or quaternion
  List<double> relativeScale;    // [sx, sy, sz]
  String? previewAssetPath;

  SkeletalMeshSocket({
    required this.name,
    required this.parentBone,
    List<double>? relativeLocation,
    List<double>? relativeRotation,
    List<double>? relativeScale,
    this.previewAssetPath,
  })  : relativeLocation = relativeLocation ?? [0.0, 0.0, 0.0],
        relativeRotation = relativeRotation ?? [0.0, 0.0, 0.0],
        relativeScale = relativeScale ?? [1.0, 1.0, 1.0];

  Map<String, dynamic> toJson() => {
    'name': name,
    'bone': parentBone,
    't': relativeLocation,
    'r': relativeRotation,
    's': relativeScale,
    if (previewAssetPath != null) 'previewAsset': previewAssetPath,
  };

  factory SkeletalMeshSocket.fromJson(Map<String, dynamic> json) => SkeletalMeshSocket(
    name: json['name'] as String? ?? 'Socket',
    parentBone: (json['bone'] as String?) ?? (json['parentBone'] as String?) ?? 'root',
    relativeLocation: (json['t'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [0.0, 0.0, 0.0],
    relativeRotation: (json['r'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [0.0, 0.0, 0.0],
    relativeScale: (json['s'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [1.0, 1.0, 1.0],
    previewAssetPath: json['previewAsset'] as String?,
  );

  SkeletalMeshSocket copyWith({
    String? name,
    String? parentBone,
    List<double>? relativeLocation,
    List<double>? relativeRotation,
    List<double>? relativeScale,
    String? previewAssetPath,
  }) {
    return SkeletalMeshSocket(
      name: name ?? this.name,
      parentBone: parentBone ?? this.parentBone,
      relativeLocation: relativeLocation ?? List.from(this.relativeLocation),
      relativeRotation: relativeRotation ?? List.from(this.relativeRotation),
      relativeScale: relativeScale ?? List.from(this.relativeScale),
      previewAssetPath: previewAssetPath ?? this.previewAssetPath,
    );
  }
}
