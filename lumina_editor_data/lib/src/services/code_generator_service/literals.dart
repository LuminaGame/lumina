part of '../code_generator_service.dart';

/// Dart literal helpers shared by every generated file.

/// Maps the persisted data-layer state string onto `DataLayerState`.
String _dataLayerState(dynamic raw) {
  switch ((raw ?? '').toString()) {
    case 'loaded':
      return 'loaded';
    case 'activated':
      return 'activated';
    default:
      return 'unloaded';
  }
}

String _escape(String v) => v.replaceAll("\\", "\\\\").replaceAll("'", "\\'");

/// [path] as the game's asset bundle names it (`contents/…`). The editor
/// stores absolute project paths; a shipped game has only its bundle.
/// Paths outside a `contents/` folder are left as they are.
String _bundlePath(String path) {
  final p = path.replaceAll('\\', '/');
  if (p.startsWith('contents/')) return p;
  final i = p.indexOf('/contents/');
  return i < 0 ? path : p.substring(i + 1);
}

double _num(dynamic v, double fallback) => v is num ? v.toDouble() : fallback;

List<double> _vec3(dynamic v, List<double> fallback) {
  if (v is List && v.length >= 3 && v.every((e) => e is num)) {
    return [v[0].toDouble(), v[1].toDouble(), v[2].toDouble()];
  }
  return fallback;
}

String _f(double v) => (v == 0 ? 0.0 : v).toStringAsFixed(4);

/// A component `properties` map as a Dart `const {…}` literal: numbers
/// through [_f], booleans and strings verbatim, anything else dropped.
String _emitPropertyMap(dynamic raw) {
  if (raw is! Map || raw.isEmpty) return 'const <String, dynamic>{}';
  final entries = <String>[];
  for (final k in raw.keys.map((k) => k.toString()).toList()..sort()) {
    final v = raw[k];
    final code = switch (v) {
      num n => _f(n.toDouble()),
      bool b => '$b',
      String t => "'${_escape(t)}'",
      _ => null,
    };
    if (code != null) entries.add("'${_escape(k)}': $code");
  }
  return 'const <String, dynamic>{${entries.join(', ')}}';
}

String _vector3(List<double> v) => 'Vector3(${_f(v[0])}, ${_f(v[1])}, ${_f(v[2])})';

/// One `LuminaCollisionPrimitive.<kind>(...)` entry of a level's
/// `collisionPrimitives:` list (authored cm, Z up).
String _emitCollisionPrimitive(LuminaCollisionPrimitive p) {
  String v(List<double> xs) => '[${xs.map(_f).join(', ')}]';
  final body = switch (p.kind) {
    LuminaCollisionPrimitiveKind.box => 'box(center: ${v(p.center)}, halfExtents: ${v(p.halfExtents)})',
    LuminaCollisionPrimitiveKind.sphere => 'sphere(center: ${v(p.center)}, radius: ${_f(p.radius)})',
    LuminaCollisionPrimitiveKind.capsule => "capsule(center: ${v(p.center)}, radius: ${_f(p.radius)}, "
        "halfLength: ${_f(p.halfLength)}, axis: '${_escape(p.axis)}')",
  };
  return '            LuminaCollisionPrimitive.$body,\n';
}

/// One `LuminaCollisionHull(...)` entry of a level's `collisionHulls:`
/// list: authored points (cm, Z up), four per line.
String _emitCollisionHull(LuminaCollisionHull hull) {
  final b = StringBuffer("            LuminaCollisionHull('${_escape(hull.name)}', [\n");
  for (var i = 0; i < hull.points.length; i += 12) {
    final end = i + 12 < hull.points.length ? i + 12 : hull.points.length;
    b.writeln('              ${[for (var j = i; j < end; j++) _f(hull.points[j])].join(', ')},');
  }
  b.write('            ]');
  if (hull.shape != 'convex') b.write(", shape: '${_escape(hull.shape)}'");
  b.writeln('),');
  return b.toString();
}

/// Parses `#RRGGBB` / `#AARRGGBB` into linear 0..1 RGB; white on error.
List<double> _hexRgb(dynamic hex, List<double> fallback) {
  if (hex is! String) return fallback;
  var h = hex.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 8) h = h.substring(2);
  if (h.length != 6) return fallback;
  final v = int.tryParse(h, radix: 16);
  if (v == null) return fallback;
  return [((v >> 16) & 0xFF) / 255.0, ((v >> 8) & 0xFF) / 255.0, (v & 0xFF) / 255.0];
}

Map<String, dynamic>? _componentOfType(Map<String, dynamic> actor, String type) {
  final comps = actor['components'];
  if (comps is! List) return null;
  for (final c in comps) {
    if (c is Map && c['type'] == type) return Map<String, dynamic>.from(c);
  }
  return null;
}
