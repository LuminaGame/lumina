import 'dart:typed_data';

class EditorComponentNode {
  final String id;
  final String type;
  String name;
  bool enabled;
  final Map<String, dynamic> properties;

  EditorComponentNode({
    required this.id,
    required this.type,
    required this.name,
    this.enabled = true,
    Map<String, dynamic>? properties,
  }) : properties = properties ?? {};

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'enabled': enabled,
      'properties': Map<String, dynamic>.from(properties),
    };
  }

  /// A copy with its own [properties] (nested maps and lists copied too),
  /// under [id] when given (e.g. a duplicated actor's components).
  EditorComponentNode copy({String? id}) => EditorComponentNode(
        id: id ?? this.id,
        type: type,
        name: name,
        enabled: enabled,
        properties: deepCopyProperties(properties),
      );

  /// [properties] with every nested map and list copied, so editing a copy
  /// never reaches the original.
  static Map<String, dynamic> deepCopyProperties(Map<String, dynamic> properties) =>
      _deepCopy(properties) as Map<String, dynamic>;

  static Object? _deepCopy(Object? v) {
    if (v is TypedData) return v;
    if (v is Map<String, dynamic>) return <String, dynamic>{for (final e in v.entries) e.key: _deepCopy(e.value)};
    if (v is Map) return v.map((k, x) => MapEntry(k, _deepCopy(x)));
    if (v is List<double>) return List<double>.of(v);
    if (v is List<int>) return List<int>.of(v);
    if (v is List<String>) return List<String>.of(v);
    if (v is List) return [for (final x in v) _deepCopy(x)];
    return v;
  }

  factory EditorComponentNode.fromMap(Map<String, dynamic> map) {
    return EditorComponentNode(
      id: map['id'],
      type: map['type'],
      name: map['name'] ?? map['type'],
      enabled: map['enabled'] ?? true,
      properties: map['properties'] != null ? Map<String, dynamic>.from(map['properties']) : {},
    );
  }
}
