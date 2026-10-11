import 'package:lumina_core/lumina_core.dart';

/// One plugin's contributions, named for the manifest preview.
typedef AndroidContributionSource = ({String plugin, PluginAndroidContributions android});

/// One line of a composed manifest and where it came from: `template`
/// (Flutter's manifest, or the user's edits to it), `project` (the
/// project's Android settings) or a plugin name.
class ComposedManifestLine {
  final String text;
  final String source;
  const ComposedManifestLine(this.text, this.source);

  @override
  String toString() => '[$source] $text';
}

/// What [AndroidManifestComposer.compose] produced.
class ComposedAndroidManifest {
  /// The manifest text.
  final String xml;

  /// Every line with its source, for the read-only preview.
  final List<ComposedManifestLine> lines;

  /// What the generated blocks hold, for the log.
  final List<String> summary;

  const ComposedAndroidManifest({required this.xml, required this.lines, this.summary = const []});
}

/// Composes a game's `android/app/src/main/AndroidManifest.xml` from
/// Flutter's template, the project's Android settings and the enabled
/// plugins' `android` contributions.
///
/// Everything it adds sits between `<!-- BEGIN LUMINA (generated) -->` and
/// `<!-- END LUMINA (generated) -->` markers, one block per place
/// (manifest-level features and permissions, `<queries>`, the launcher
/// activity's intent filter, `<application>` meta-data); composing again
/// first removes those blocks, so edits outside them survive and the output
/// does not grow. Activity attributes cannot sit inside a comment: they are
/// set on the main activity's start tag (`configChanges` is merged, as a
/// set of flags). The order is deterministic (sorted by name) and duplicates
/// are merged: a feature required by any contributor is required, the
/// highest version wins.
abstract final class AndroidManifestComposer {
  static const String begin = '<!-- BEGIN LUMINA (generated) -->';
  static const String end = '<!-- END LUMINA (generated) -->';

  /// The manifest-level properties Lumina never writes: Horizon OS ignores
  /// Android XR's start-mode property, and a manifest copied from an Android
  /// XR sample must not carry it into a Quest build.
  static const Set<String> refusedProperties = {'android.window.PROPERTY_XR_ACTIVITY_START_MODE'};

  static final RegExp _blocks = RegExp(r'[ \t]*<!-- BEGIN LUMINA \(generated\) -->.*?<!-- END LUMINA \(generated\) -->[ \t]*\r?\n?', dotAll: true);

  /// [template] with the generated blocks of an earlier composition removed.
  static String withoutGenerated(String template) => template.replaceAll(_blocks, '');

  static ComposedAndroidManifest compose({
    required String template,
    required ProjectAndroidSettings settings,
    List<AndroidContributionSource> plugins = const [],
    Set<String> usedClasses = const {},
  }) {
    final nl = template.contains('\r\n') ? '\r\n' : '\n';
    var xml = withoutGenerated(template.replaceAll('\r\n', '\n'));
    final summary = <String>[];

    // Merge every contribution, remembering who asked first.
    final features = <String, AndroidUsesFeature>{};
    final featureSource = <String, String>{};
    final permissions = <String, String>{};
    final categories = <String, String>{};
    final meta = <String, (String, String)>{};
    final queries = <String, String>{};
    final attributes = <String, (String, String)>{};
    final configChanges = <String>{};
    for (final (:plugin, :android) in plugins) {
      for (final f in android.usesFeatures) {
        if (f.whenUsed != null && !usedClasses.contains(f.whenUsed)) continue;
        final resolved = f.resolvedFor(usedClasses);
        final had = features[resolved.name];
        if (had == null) {
          features[resolved.name] = resolved;
          featureSource[resolved.name] = plugin;
        } else {
          final versions = [?had.version, ?resolved.version];
          features[resolved.name] = AndroidUsesFeature(
            name: resolved.name,
            required: had.required || resolved.required,
            version: versions.isEmpty ? null : versions.reduce((a, b) => a > b ? a : b),
          );
        }
      }
      for (final p in android.permissions) {
        if (p.whenUsed != null && !usedClasses.contains(p.whenUsed)) continue;
        permissions.putIfAbsent(p.name, () => plugin);
      }
      for (final c in android.intentCategories) {
        categories.putIfAbsent(c, () => plugin);
      }
      for (final m in android.metaData) {
        if (m.whenUsed != null && !usedClasses.contains(m.whenUsed)) continue;
        if (refusedProperties.contains(m.name)) continue;
        meta.putIfAbsent(m.name, () => (m.value, plugin));
      }
      for (final q in android.queries) {
        queries.putIfAbsent(q.replaceAll(RegExp(r'\s+'), ' '), () => plugin);
      }
      for (final e in android.activityAttributes.entries) {
        if (e.key == 'configChanges') {
          configChanges.addAll(e.value.split('|').map((v) => v.trim()).where((v) => v.isNotEmpty));
        } else {
          attributes.putIfAbsent(e.key, () => (e.value, plugin));
        }
      }
    }
    // The project's own settings.
    if (!settings.impeller) {
      meta.putIfAbsent('io.flutter.embedding.android.EnableImpeller', () => ('false', 'project'));
    }

    final sources = <String, String>{}; // generated line -> source
    String block(List<(String, String)> items, String indent) {
      final b = StringBuffer('$indent$begin\n');
      for (final (line, source) in items) {
        b.write('$indent$line\n');
        sources[line] = source;
      }
      b.write('$indent$end\n');
      return b.toString();
    }

    // 1. Features and permissions, right after the <manifest> start tag.
    final top = <(String, String)>[
      for (final name in features.keys.toList()..sort()) (features[name]!.toXml(), featureSource[name]!),
      for (final name in permissions.keys.toList()..sort()) (AndroidPermission(name).toXml(), permissions[name]!),
    ];
    if (top.isNotEmpty) {
      final m = RegExp(r'<manifest\b[^>]*>[ \t]*\n').firstMatch(xml);
      if (m == null) throw const FormatException('The manifest template has no <manifest> start tag');
      xml = xml.replaceRange(m.end, m.end, block(top, '    '));
      summary.add('${features.length} uses-feature, ${permissions.length} uses-permission');
    }

    // 2. Queries: inside the template's <queries>, or a new one at the end.
    if (queries.isNotEmpty) {
      final items = [for (final q in queries.keys.toList()..sort()) (q, queries[q]!)];
      final close = xml.indexOf('</queries>');
      if (close >= 0) {
        final lineStart = xml.lastIndexOf('\n', close) + 1;
        xml = xml.replaceRange(lineStart, lineStart, block(items, '        '));
      } else {
        final at = xml.lastIndexOf('</manifest>');
        final b = '    $begin\n    <queries>\n${[for (final (q, _) in items) '        $q\n'].join()}    </queries>\n    $end\n';
        for (final (q, s) in items) {
          sources[q] = s;
        }
        xml = xml.replaceRange(at, at, b);
      }
      summary.add('${queries.length} queries');
    }

    // 3. Categories on the launcher activity's MAIN intent filter.
    if (categories.isNotEmpty) {
      final filter = RegExp(r'<intent-filter\b[^>]*>(?:(?!</intent-filter>).)*?android\.intent\.action\.MAIN.*?(</intent-filter>)', dotAll: true)
          .firstMatch(xml);
      if (filter == null) throw const FormatException('The manifest template has no MAIN intent filter');
      final close = filter.start + filter.group(0)!.lastIndexOf('</intent-filter>');
      final lineStart = xml.lastIndexOf('\n', close) + 1;
      final items = [
        for (final c in categories.keys.toList()..sort())
          ('<category android:name="${PluginAndroidContributions.escapeXml(c)}" />', categories[c]!),
      ];
      xml = xml.replaceRange(lineStart, lineStart, block(items, '                '));
      summary.add('${categories.length} launcher categories');
    }

    // 4. Application meta-data before </application>.
    if (meta.isNotEmpty) {
      final close = xml.lastIndexOf('</application>');
      if (close < 0) throw const FormatException('The manifest template has no </application>');
      final lineStart = xml.lastIndexOf('\n', close) + 1;
      final items = [
        for (final name in meta.keys.toList()..sort())
          (AndroidMetaData(name: name, value: meta[name]!.$1).toXml(), meta[name]!.$2),
      ];
      xml = xml.replaceRange(lineStart, lineStart, block(items, '        '));
      summary.add('${meta.length} application meta-data');
    }

    // 5. Activity attributes on the main activity's start tag.
    final attributeSources = <String, String>{};
    if (attributes.isNotEmpty || configChanges.isNotEmpty) {
      final activity = RegExp(r'<activity\b[^>]*android:name="\.MainActivity"[^>]*>', dotAll: true).firstMatch(xml) ??
          RegExp(r'<activity\b[^>]*>', dotAll: true).firstMatch(xml);
      if (activity == null) throw const FormatException('The manifest template has no <activity>');
      var tag = activity.group(0)!;
      String setAttribute(String tag, String name, String value) {
        final escaped = PluginAndroidContributions.escapeXml(value);
        final existing = RegExp('android:$name="[^"]*"').firstMatch(tag);
        if (existing != null) return tag.replaceRange(existing.start, existing.end, 'android:$name="$escaped"');
        final indent = RegExp(r'\n([ \t]+)android:').firstMatch(tag)?.group(1) ?? '            ';
        final close = tag.endsWith('/>') ? tag.length - 2 : tag.length - 1;
        var head = tag.substring(0, close).trimRight();
        head = '$head\n${indent}android:$name="$escaped"';
        return '$head${tag.substring(close)}';
      }

      for (final name in attributes.keys.toList()..sort()) {
        tag = setAttribute(tag, name, attributes[name]!.$1);
        attributeSources['android:$name='] = attributes[name]!.$2;
      }
      if (configChanges.isNotEmpty) {
        final current = RegExp(r'android:configChanges="([^"]*)"').firstMatch(tag)?.group(1) ?? '';
        final merged = <String>[...current.split('|').map((v) => v.trim()).where((v) => v.isNotEmpty)];
        for (final c in configChanges.toList()..sort()) {
          if (!merged.contains(c)) merged.add(c);
        }
        tag = setAttribute(tag, 'configChanges', merged.join('|'));
        attributeSources['android:configChanges='] = plugins.firstWhere((p) => p.android.activityAttributes.containsKey('configChanges')).plugin;
      }
      xml = xml.replaceRange(activity.start, activity.end, tag);
      summary.add('${attributes.length + (configChanges.isEmpty ? 0 : 1)} activity attributes');
    }

    // The refused properties never survive, wherever they were.
    for (final name in refusedProperties) {
      xml = xml.replaceAll(RegExp('[ \\t]*<property\\b[^>]*android:name="${RegExp.escape(name)}"[^>]*/>[ \\t]*\\n?'), '');
    }

    final lines = <ComposedManifestLine>[];
    var inBlock = false;
    for (final line in xml.split('\n')) {
      final t = line.trim();
      if (t == begin) inBlock = true;
      String source = 'template';
      if (inBlock) {
        source = sources[t] ?? 'generated';
      } else {
        for (final e in attributeSources.entries) {
          if (t.startsWith(e.key)) source = e.value;
        }
      }
      lines.add(ComposedManifestLine(line, source));
      if (t == end) inBlock = false;
    }
    if (lines.isNotEmpty && lines.last.text.isEmpty) lines.removeLast();
    return ComposedAndroidManifest(xml: nl == '\n' ? xml : xml.replaceAll('\n', nl), lines: lines, summary: summary);
  }
}
