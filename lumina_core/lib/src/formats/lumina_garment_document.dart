import 'dart:convert';
import 'dart:math' as math;

import 'package:lumina_core/src/formats/lumina_asset.dart';

/// A named pair of points: where something sits on the garment (in the
/// source mesh's own space, so it stays valid when the garment is moved) and
/// where it belongs on the reference body (in the body mesh's space). Both in
/// centimetres; null while not placed.
class LuminaGarmentLandmark {
  const LuminaGarmentLandmark(this.name, {this.garment, this.body});

  final String name;
  final List<double>? garment;
  final List<double>? body;

  bool get isComplete => garment != null && body != null;

  LuminaGarmentLandmark withGarment(List<double>? point) => LuminaGarmentLandmark(name, garment: point, body: body);
  LuminaGarmentLandmark withBody(List<double>? point) => LuminaGarmentLandmark(name, garment: garment, body: point);

  Map<String, Object?> toJson() => {'name': name, 'garment': ?garment, 'body': ?body};

  static LuminaGarmentLandmark? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    if (name is! String || name.isEmpty) return null;
    return LuminaGarmentLandmark(name, garment: _vec(json['garment']), body: _vec(json['body']));
  }

  static List<double>? _vec(Object? v) =>
      v is List && v.length == 3 && v.every((e) => e is num) ? [for (final e in v) (e as num).toDouble()] : null;
}

/// A garment: a mesh worn on a character, authored on a reference body
/// (`.lmas` of [AssetType.garment], `raw_payload` this document as JSON).
///
/// - [sourceMesh]: the mesh the garment is made of (a static or skeletal
///   mesh asset); [referenceBody]: the skeletal mesh it is fitted on.
/// - [location] (cm), [rotation] (degrees, applied X then Y then Z) and
///   [scale]: where the source mesh sits in the reference body's mesh space.
/// - [landmarks]: named garment ↔ body point pairs (neck, shoulders, …)
///   that align the garment and guide its fit on other bodies.
/// - [thickness] (cm): the distance the fitted garment keeps from the skin.
/// - [slot]: the character slot it fills (`Torso`, `Legs`, `Feet`, …).
/// - [simulateAsCloth] with [clothSettingsAsset]: worn as a skinned cloth.
class LuminaGarmentDocument {
  const LuminaGarmentDocument({
    this.sourceMesh = '',
    this.referenceBody = '',
    this.location = const [0, 0, 0],
    this.rotation = const [0, 0, 0],
    this.scale = const [1, 1, 1],
    this.landmarks = const [],
    this.thickness = 0.5,
    this.slot = 'Torso',
    this.simulateAsCloth = false,
    this.clothSettingsAsset = '',
  });

  final String sourceMesh, referenceBody;
  final List<double> location, rotation, scale;
  final List<LuminaGarmentLandmark> landmarks;
  final double thickness;
  final String slot;
  final bool simulateAsCloth;
  final String clothSettingsAsset;

  /// The thickness range an editor offers (cm).
  static const double minThickness = 0, maxThickness = 10;

  /// The landmarks every garment can place, in a body's top-down order.
  static const List<String> presets = [
    'Neck',
    'Shoulder L',
    'Shoulder R',
    'Elbow L',
    'Elbow R',
    'Wrist L',
    'Wrist R',
    'Chest',
    'Waist',
    'Hip L',
    'Hip R',
    'Knee L',
    'Knee R',
    'Ankle L',
    'Ankle R',
    'Foot L',
    'Foot R',
  ];

  /// The slots a garment usually fills.
  static const List<String> slots = ['Torso', 'Legs', 'Feet', 'Hair', 'Head', 'Hands'];

  LuminaGarmentDocument copyWith({
    String? sourceMesh,
    String? referenceBody,
    List<double>? location,
    List<double>? rotation,
    List<double>? scale,
    List<LuminaGarmentLandmark>? landmarks,
    double? thickness,
    String? slot,
    bool? simulateAsCloth,
    String? clothSettingsAsset,
  }) => LuminaGarmentDocument(
    sourceMesh: sourceMesh ?? this.sourceMesh,
    referenceBody: referenceBody ?? this.referenceBody,
    location: location ?? this.location,
    rotation: rotation ?? this.rotation,
    scale: scale ?? this.scale,
    landmarks: landmarks ?? this.landmarks,
    thickness: (thickness ?? this.thickness).clamp(minThickness, maxThickness).toDouble(),
    slot: slot ?? this.slot,
    simulateAsCloth: simulateAsCloth ?? this.simulateAsCloth,
    clothSettingsAsset: clothSettingsAsset ?? this.clothSettingsAsset,
  );

  /// The landmark named [name], or null.
  LuminaGarmentLandmark? landmark(String name) {
    for (final l in landmarks) {
      if (l.name == name) return l;
    }
    return null;
  }

  /// A copy with [landmark] replacing the one of the same name (appended
  /// when new).
  LuminaGarmentDocument withLandmark(LuminaGarmentLandmark landmark) {
    final out = [...landmarks];
    final i = out.indexWhere((l) => l.name == landmark.name);
    if (i >= 0) {
      out[i] = landmark;
    } else {
      out.add(landmark);
    }
    return copyWith(landmarks: out);
  }

  LuminaGarmentDocument withoutLandmark(String name) => copyWith(landmarks: [
    for (final l in landmarks)
      if (l.name != name) l,
  ]);

  /// The placement as a column-major 4×4 matrix (cm): T · Rz · Ry · Rx · S.
  List<double> placementMatrix() {
    final rx = rotation[0] * math.pi / 180, ry = rotation[1] * math.pi / 180, rz = rotation[2] * math.pi / 180;
    final cx = math.cos(rx), sx = math.sin(rx), cy = math.cos(ry), sy = math.sin(ry), cz = math.cos(rz), sz = math.sin(rz);
    // R = Rz · Ry · Rx (rows).
    final r = [
      cz * cy, cz * sy * sx - sz * cx, cz * sy * cx + sz * sx, //
      sz * cy, sz * sy * sx + cz * cx, sz * sy * cx - cz * sx,
      -sy, cy * sx, cy * cx,
    ];
    return [
      r[0] * scale[0], r[3] * scale[0], r[6] * scale[0], 0, //
      r[1] * scale[1], r[4] * scale[1], r[7] * scale[1], 0,
      r[2] * scale[2], r[5] * scale[2], r[8] * scale[2], 0,
      location[0], location[1], location[2], 1,
    ];
  }

  /// [point] of the source mesh (cm) placed in the body's space.
  List<double> place(List<double> point) {
    final m = placementMatrix();
    final x = point[0], y = point[1], z = point[2];
    return [
      m[0] * x + m[4] * y + m[8] * z + m[12],
      m[1] * x + m[5] * y + m[9] * z + m[13],
      m[2] * x + m[6] * y + m[10] * z + m[14],
    ];
  }

  Map<String, Object?> toProperties() => {
    'sourceMesh': sourceMesh,
    'referenceBody': referenceBody,
    'location': location,
    'rotation': rotation,
    'scale': scale,
    'landmarks': [for (final l in landmarks) l.toJson()],
    'thickness': thickness,
    'slot': slot,
    'simulateAsCloth': simulateAsCloth,
    'clothSettingsAsset': clothSettingsAsset,
  };

  factory LuminaGarmentDocument.fromProperties(Map<String, dynamic> p) {
    List<double> vec(Object? v, List<double> fallback) =>
        v is List && v.length == 3 && v.every((e) => e is num) ? [for (final e in v) (e as num).toDouble()] : fallback;
    final thickness = p['thickness'];
    return LuminaGarmentDocument(
      sourceMesh: p['sourceMesh'] as String? ?? '',
      referenceBody: p['referenceBody'] as String? ?? '',
      location: vec(p['location'], const [0, 0, 0]),
      rotation: vec(p['rotation'], const [0, 0, 0]),
      scale: vec(p['scale'], const [1, 1, 1]),
      landmarks: [
        for (final l in (p['landmarks'] as List? ?? const []))
          ?LuminaGarmentLandmark.fromJson(l),
      ],
      thickness: (thickness is num ? thickness.toDouble() : 0.5).clamp(minThickness, maxThickness).toDouble(),
      slot: p['slot'] as String? ?? 'Torso',
      simulateAsCloth: p['simulateAsCloth'] == true,
      clothSettingsAsset: p['clothSettingsAsset'] as String? ?? '',
    );
  }

  String toJson() => jsonEncode(toProperties());

  factory LuminaGarmentDocument.fromJson(String json) {
    try {
      final decoded = jsonDecode(json);
      return LuminaGarmentDocument.fromProperties(decoded is Map<String, dynamic> ? decoded : const {});
    } on FormatException {
      return const LuminaGarmentDocument();
    }
  }

  /// The garment as a `.lmas` asset named [name] (its meshes referenced).
  LuminaAsset toAsset({required String name, String? assetId}) => LuminaAsset(
    assetId: assetId ?? 'garment_${name.toLowerCase()}',
    name: name,
    type: AssetType.garment,
    rawPayload: utf8.encode(toJson()),
    references: [
      if (sourceMesh.isNotEmpty) AssetReference(slotName: 'source_mesh', assetId: '', assetPath: sourceMesh),
      if (referenceBody.isNotEmpty) AssetReference(slotName: 'reference_body', assetId: '', assetPath: referenceBody),
    ],
  );

  factory LuminaGarmentDocument.fromAsset(LuminaAsset asset) {
    final payload = asset.rawPayload;
    if (payload == null || payload.isEmpty) return const LuminaGarmentDocument();
    try {
      return LuminaGarmentDocument.fromJson(utf8.decode(payload));
    } on FormatException {
      return const LuminaGarmentDocument();
    }
  }

  @override
  bool operator ==(Object other) => other is LuminaGarmentDocument && other.toJson() == toJson();

  @override
  int get hashCode => toJson().hashCode;
}
