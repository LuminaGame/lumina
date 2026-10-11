/// The `android` section of a plugin descriptor (`.lmplugin`): what an
/// enabled plugin adds to a game's `AndroidManifest.xml`.
library;

/// Reads and validates the JSON of one contribution entry: unknown keys are
/// refused with their path, so a typo never silently drops a feature.
Map<String, dynamic> _entry(Object? raw, String path, Set<String> allowed) {
  if (raw is! Map) throw FormatException('`android.$path` must be an object');
  final map = Map<String, dynamic>.from(raw);
  for (final key in map.keys) {
    if (!allowed.contains(key)) {
      throw FormatException('`android.$path.$key` is not a known key (allowed: ${allowed.join(', ')})');
    }
  }
  return map;
}

String _string(Map<String, dynamic> map, String key, String path, {bool required = true}) {
  final value = map[key];
  if (value == null && !required) return '';
  if (value is! String || (required && value.trim().isEmpty)) {
    throw FormatException('`android.$path.$key` must be a non-empty string');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> map, String key, String path) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) throw FormatException('`android.$path.$key` must be a non-empty string');
  return value;
}

/// `<uses-feature>`. [requiredWhenUsed] / [whenUsed] name a component class:
/// the feature becomes required, or is declared at all, only when the
/// project uses that class (a level or Blueprint names it).
class AndroidUsesFeature {
  final String name;
  final bool required;
  final int? version;

  /// A class name: when the project uses it, [required] is true.
  final String? requiredWhenUsed;

  /// A class name: the feature is declared only when the project uses it.
  final String? whenUsed;

  const AndroidUsesFeature({required this.name, this.required = false, this.version, this.requiredWhenUsed, this.whenUsed});

  static const Set<String> keys = {'name', 'required', 'version', 'required_when_used', 'when_used'};

  factory AndroidUsesFeature.fromJson(Object? raw, String path) {
    final m = _entry(raw, path, keys);
    final required = m['required'];
    if (required != null && required is! bool) throw FormatException('`android.$path.required` must be true or false');
    final version = m['version'];
    if (version != null && version is! int) throw FormatException('`android.$path.version` must be an integer');
    return AndroidUsesFeature(
      name: _string(m, 'name', path),
      required: required as bool? ?? false,
      version: version as int?,
      requiredWhenUsed: _optionalString(m, 'required_when_used', path),
      whenUsed: _optionalString(m, 'when_used', path),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'required': required,
        if (version != null) 'version': version,
        if (requiredWhenUsed != null) 'required_when_used': requiredWhenUsed,
        if (whenUsed != null) 'when_used': whenUsed,
      };

  /// This feature as it applies to a project using [usedClasses].
  AndroidUsesFeature resolvedFor(Set<String> usedClasses) => AndroidUsesFeature(
        name: name,
        required: required || (requiredWhenUsed != null && usedClasses.contains(requiredWhenUsed)),
        version: version,
      );

  String toXml() => '<uses-feature android:name="${PluginAndroidContributions.escapeXml(name)}" '
      'android:required="$required"${version == null ? '' : ' android:version="$version"'} />';
}

/// `<uses-permission>`, optionally only when the project uses [whenUsed].
class AndroidPermission {
  final String name;
  final String? whenUsed;

  const AndroidPermission(this.name, {this.whenUsed});

  factory AndroidPermission.fromJson(Object? raw, String path) {
    if (raw is String) {
      if (raw.trim().isEmpty) throw FormatException('`android.$path` must be a non-empty string');
      return AndroidPermission(raw);
    }
    final m = _entry(raw, path, const {'name', 'when_used'});
    return AndroidPermission(_string(m, 'name', path), whenUsed: _optionalString(m, 'when_used', path));
  }

  Object toJson() => whenUsed == null ? name : {'name': name, 'when_used': whenUsed};

  String toXml() => '<uses-permission android:name="${PluginAndroidContributions.escapeXml(name)}" />';
}

/// `<meta-data>` inside `<application>`, optionally only when the project
/// uses [whenUsed].
class AndroidMetaData {
  final String name;
  final String value;
  final String? whenUsed;

  const AndroidMetaData({required this.name, required this.value, this.whenUsed});

  factory AndroidMetaData.fromJson(Object? raw, String path) {
    final m = _entry(raw, path, const {'name', 'value', 'when_used'});
    final value = m['value'];
    if (value is! String && value is! num && value is! bool) {
      throw FormatException('`android.$path.value` must be a string, a number or a boolean');
    }
    return AndroidMetaData(name: _string(m, 'name', path), value: '$value', whenUsed: _optionalString(m, 'when_used', path));
  }

  Map<String, dynamic> toJson() => {'name': name, 'value': value, if (whenUsed != null) 'when_used': whenUsed};

  String toXml() => '<meta-data android:name="${PluginAndroidContributions.escapeXml(name)}" '
      'android:value="${PluginAndroidContributions.escapeXml(value)}" />';
}

/// What an enabled plugin adds to a game's Android manifest:
/// `uses_features`, `permissions`, `intent_categories` (on the launcher
/// activity's MAIN intent filter), `meta_data` (in `<application>`),
/// `queries` (raw `<provider>` / `<intent>` fragments) and
/// `activity_attributes` (`android:` attributes of the main activity).
class PluginAndroidContributions {
  final List<AndroidUsesFeature> usesFeatures;
  final List<AndroidPermission> permissions;
  final List<String> intentCategories;
  final List<AndroidMetaData> metaData;
  final List<String> queries;
  final Map<String, String> activityAttributes;

  const PluginAndroidContributions({
    this.usesFeatures = const [],
    this.permissions = const [],
    this.intentCategories = const [],
    this.metaData = const [],
    this.queries = const [],
    this.activityAttributes = const {},
  });

  static const Set<String> keys = {
    'uses_features',
    'permissions',
    'intent_categories',
    'meta_data',
    'queries',
    'activity_attributes',
  };

  static final RegExp _androidName = RegExp(r'^[A-Za-z_][A-Za-z0-9_.]*$');
  static final RegExp _attributeName = RegExp(r'^[A-Za-z][A-Za-z0-9_]*$');

  /// Parses and validates the section; a [FormatException] names the
  /// offending key or entry.
  factory PluginAndroidContributions.fromJson(Map<String, dynamic> json) {
    for (final key in json.keys) {
      if (!keys.contains(key)) throw FormatException('`android.$key` is not a known key (allowed: ${keys.join(', ')})');
    }
    List<Object?> list(String key) {
      final v = json[key];
      if (v == null) return const [];
      if (v is! List) throw FormatException('`android.$key` must be a list');
      return v;
    }

    final categories = <String>[];
    final rawCategories = list('intent_categories');
    for (var i = 0; i < rawCategories.length; i++) {
      final c = rawCategories[i];
      if (c is! String || !_androidName.hasMatch(c)) {
        throw FormatException('`android.intent_categories[$i]` must be a category name, got "$c"');
      }
      categories.add(c);
    }
    final queries = <String>[];
    final rawQueries = list('queries');
    for (var i = 0; i < rawQueries.length; i++) {
      final q = rawQueries[i];
      final t = q is String ? q.trim() : '';
      final element = RegExp(r'^<(provider|intent)[\s>/]').firstMatch(t)?.group(1);
      final closed = element != null && (t.endsWith('/>') || t.endsWith('</$element>'));
      if (!closed) {
        throw FormatException('`android.queries[$i]` must be one <provider …/> or <intent>…</intent> element, got "$q"');
      }
      queries.add(t);
    }
    final rawAttributes = json['activity_attributes'];
    final attributes = <String, String>{};
    if (rawAttributes != null) {
      if (rawAttributes is! Map) throw const FormatException('`android.activity_attributes` must be an object');
      for (final e in rawAttributes.entries) {
        final name = '${e.key}';
        if (!_attributeName.hasMatch(name) || name == 'name' || name == 'exported') {
          throw FormatException('`android.activity_attributes.$name` is not an activity attribute a plugin may set');
        }
        final value = e.value;
        if (value is! String && value is! bool && value is! num) {
          throw FormatException('`android.activity_attributes.$name` must be a string, a number or a boolean');
        }
        attributes[name] = '$value';
      }
    }
    final features = list('uses_features');
    final permissions = list('permissions');
    final meta = list('meta_data');
    return PluginAndroidContributions(
      usesFeatures: [for (var i = 0; i < features.length; i++) AndroidUsesFeature.fromJson(features[i], 'uses_features[$i]')],
      permissions: [for (var i = 0; i < permissions.length; i++) AndroidPermission.fromJson(permissions[i], 'permissions[$i]')],
      intentCategories: categories,
      metaData: [for (var i = 0; i < meta.length; i++) AndroidMetaData.fromJson(meta[i], 'meta_data[$i]')],
      queries: queries,
      activityAttributes: attributes,
    );
  }

  Map<String, dynamic> toJson() => {
        if (usesFeatures.isNotEmpty) 'uses_features': [for (final f in usesFeatures) f.toJson()],
        if (permissions.isNotEmpty) 'permissions': [for (final p in permissions) p.toJson()],
        if (intentCategories.isNotEmpty) 'intent_categories': intentCategories,
        if (metaData.isNotEmpty) 'meta_data': [for (final m in metaData) m.toJson()],
        if (queries.isNotEmpty) 'queries': queries,
        if (activityAttributes.isNotEmpty) 'activity_attributes': activityAttributes,
      };

  bool get isEmpty =>
      usesFeatures.isEmpty && permissions.isEmpty && intentCategories.isEmpty && metaData.isEmpty && queries.isEmpty && activityAttributes.isEmpty;

  /// [value] safe inside an XML attribute or text.
  static String escapeXml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
