class LodSlot {
  int level;
  double reductionRatio; // 1.0 for LOD0, 0.05..1.0
  double screenSize; // 1.0 for LOD0, 0.0..1.0 strictly decreasing
  int triangleCount;
  int vertexCount;
  Map<String, String> materialOverrides; // slotName -> materialAssetPath

  LodSlot({
    required this.level,
    this.reductionRatio = 1.0,
    this.screenSize = 1.0,
    this.triangleCount = 0,
    this.vertexCount = 0,
    Map<String, String>? materialOverrides,
  }) : materialOverrides = materialOverrides ?? {};

  Map<String, dynamic> toJson() => {
    'level': level,
    'reductionRatio': reductionRatio,
    'screenSize': screenSize,
    'triangleCount': triangleCount,
    'vertexCount': vertexCount,
    'materialOverrides': materialOverrides,
    'decimator': 'vc1',
  };

  factory LodSlot.fromJson(Map<String, dynamic> json) => LodSlot(
    level: (json['level'] as num?)?.toInt() ?? 0,
    reductionRatio: (json['reductionRatio'] as num?)?.toDouble() ?? 1.0,
    screenSize: (json['screenSize'] as num?)?.toDouble() ?? 1.0,
    triangleCount: (json['triangleCount'] as num?)?.toInt() ?? 0,
    vertexCount: (json['vertexCount'] as num?)?.toInt() ?? 0,
    materialOverrides: Map<String, String>.from(json['materialOverrides'] as Map? ?? {}),
  );
}
