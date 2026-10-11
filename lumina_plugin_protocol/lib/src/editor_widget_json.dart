/// Strict readers for the editor widget states ([PluginTimelineState],
/// [PluginTableState], [PluginCanvasState]): a value of the wrong type or
/// an unknown enum value is a [FormatException] that names the field
/// (`timeline.tracks[2].kind`), never a silent default. Absent optional
/// fields read as null.
library;

/// Reads fields of one JSON object at [path].
class EditorWidgetJsonReader {
  EditorWidgetJsonReader(this.json, this.path);

  final Map<String, Object?> json;
  final String path;

  /// [json] at [path] as an object, or a decode error.
  static EditorWidgetJsonReader of(Object? json, String path) {
    if (json is Map) return EditorWidgetJsonReader(json.cast<String, Object?>(), path);
    throw FormatException('$path must be an object');
  }

  Never fail(String field, String what) => throw FormatException('$path: "$field" $what');

  String string(String field) {
    final v = json[field];
    if (v is String) return v;
    fail(field, v == null ? 'is required' : 'must be a string');
  }

  String? optString(String field) {
    final v = json[field];
    if (v == null || v is String) return v as String?;
    fail(field, 'must be a string');
  }

  int integer(String field, {int? fallback}) {
    final v = json[field];
    if (v == null && fallback != null) return fallback;
    if (v is int) return v;
    if (v is double && v == v.roundToDouble()) return v.toInt();
    fail(field, v == null ? 'is required' : 'must be a whole number');
  }

  int? optInt(String field) => json[field] == null ? null : integer(field);

  num? optNum(String field) {
    final v = json[field];
    if (v == null || v is num) return v as num?;
    fail(field, 'must be a number');
  }

  num number(String field, num fallback) => optNum(field) ?? fallback;

  bool flag(String field, bool fallback) {
    final v = json[field];
    if (v == null) return fallback;
    if (v is bool) return v;
    fail(field, 'must be true or false');
  }

  bool? optFlag(String field) => json[field] == null ? null : flag(field, false);

  /// One of [values]; [fallback] when absent.
  String oneOf(String field, List<String> values, String fallback) {
    final v = json[field];
    if (v == null) return fallback;
    if (v is String && values.contains(v)) return v;
    fail(field, 'must be one of ${values.join(', ')} (got ${v is String ? '"$v"' : v})');
  }

  List<Object?> list(String field) {
    final v = json[field];
    if (v == null) return const [];
    if (v is List) return v;
    fail(field, 'must be a list');
  }

  /// A list of objects, each read by [read] at `path.field[i]`.
  List<T> objects<T>(String field, T Function(EditorWidgetJsonReader r) read) {
    final items = list(field);
    return [for (var i = 0; i < items.length; i++) read(EditorWidgetJsonReader.of(items[i], '$path.$field[$i]'))];
  }

  /// A list of numbers.
  List<num>? numbers(String field) {
    final v = json[field];
    if (v == null) return null;
    if (v is List && v.every((e) => e is num)) return [for (final e in v) e as num];
    fail(field, 'must be a list of numbers');
  }

  /// A list of strings.
  List<String> strings(String field) {
    final v = json[field];
    if (v == null) return const [];
    if (v is List && v.every((e) => e is String)) return [for (final e in v) e as String];
    fail(field, 'must be a list of strings');
  }

  Map<String, Object?>? optObject(String field) {
    final v = json[field];
    if (v == null) return null;
    if (v is Map) return v.cast<String, Object?>();
    fail(field, 'must be an object');
  }
}
