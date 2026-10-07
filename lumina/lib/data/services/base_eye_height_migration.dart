import 'dart:convert';
import 'dart:io';

import 'package:lumina/src/game/template_character.dart';
import 'package:lumina_core/lumina_core.dart';

/// What [BaseEyeHeightMigration.run] did to one project.
class BaseEyeHeightMigrationReport {
  /// Project-relative `.lmas` paths whose class default was rewritten.
  final List<String> migratedBlueprints;

  /// Project-relative generated `lib/actors/*.dart` files patched to match.
  final List<String> patchedGeneratedFiles;

  /// True when the project had already been migrated (the marker exists).
  final bool alreadyMigrated;

  const BaseEyeHeightMigrationReport({
    this.migratedBlueprints = const [],
    this.patchedGeneratedFiles = const [],
    this.alreadyMigrated = false,
  });

  bool get didAnything => migratedBlueprints.isNotEmpty || patchedGeneratedFiles.isNotEmpty;

  @override
  String toString() => alreadyMigrated
      ? 'already migrated'
      : 'Base Eye Height ${BaseEyeHeightMigration.legacyValue} → ${BaseEyeHeightMigration.newValue} in '
          '${migratedBlueprints.isEmpty ? 'no Blueprint' : migratedBlueprints.join(', ')}'
          '${patchedGeneratedFiles.isEmpty ? '' : ' (generated: ${patchedGeneratedFiles.join(', ')})'}';
}

/// The one-time move of the Third Person template's Base Eye Height to
/// the capsule-centre convention.
///
/// `baseEyeHeight` is measured from the actor location, which for a
/// character is the capsule centre. Older projects store the
/// template's feet-based 160 cm in BP_ThirdPersonCharacter's class defaults,
/// which puts the eyes (and every trace) 250 cm above the ground. On project
/// open, every Character Blueprint that still carries exactly that template
/// value — parent `LuminaCharacter`, class default `baseEyeHeight == 160`,
/// root capsule of the template's 90 cm half height — gets
/// [LuminaTemplateCharacterTuning.baseEyeHeight] instead; its generated
/// `lib/actors/<name>.dart` constructor line is patched to match. A value the
/// user chose (anything but 160) or a different capsule is left alone.
///
/// Runs once per project: [markerPath] under `.lumina/` records it, so a
/// value set back to 160 on purpose later is never touched again.
class BaseEyeHeightMigration {
  static const String markerPath = '.lumina/migrations/base_eye_height_capsule_centre.json';

  /// The feet-based template value older projects carry.
  static const double legacyValue = 160.0;

  /// What it becomes: the eyes above the capsule centre.
  static const double newValue = LuminaTemplateCharacterTuning.baseEyeHeight;

  static bool isMigrated(String projectDir) => File('$projectDir/$markerPath').existsSync();

  static BaseEyeHeightMigrationReport run(String projectDir) {
    if (isMigrated(projectDir)) return const BaseEyeHeightMigrationReport(alreadyMigrated: true);
    final migrated = <String>[];
    final patched = <String>[];
    final contents = Directory('$projectDir/contents');
    if (contents.existsSync()) {
      final files = [
        for (final e in contents.listSync(recursive: true, followLinks: false))
          if (e is File && e.path.endsWith('.lmas') && !e.path.replaceAll(r'\', '/').contains('/.thumbnails/')) e,
      ]..sort((a, b) => a.path.compareTo(b.path));
      for (final file in files) {
        if (!_migrateBlueprint(file)) continue;
        // Project-relative paths stay `/`-separated (Windows listings use `\`).
        final relative = file.path.substring(projectDir.length + 1).replaceAll(r'\', '/');
        migrated.add(relative);
        final name = file.uri.pathSegments.last.replaceAll('.lmas', '');
        // The generated class: `bp_x.dart`, or `BP_X.dart` from before
        // generated files were snake_case.
        for (final fileName in {dartFileName(name), '$name.dart'}) {
          if (_patchGenerated(File('$projectDir/lib/actors/$fileName'))) {
            patched.add('lib/actors/$fileName');
            break;
          }
        }
      }
    }
    File('$projectDir/$markerPath')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
        'reason': 'Base Eye Height is measured from the capsule centre',
        'from': legacyValue,
        'to': newValue,
        'migratedAt': DateTime.now().toUtc().toIso8601String(),
        'blueprints': migrated,
        'generated': patched,
      }));
    return BaseEyeHeightMigrationReport(migratedBlueprints: migrated, patchedGeneratedFiles: patched);
  }

  /// Rewrites [file]'s class default when it is the template value on the
  /// template capsule; true when it did.
  static bool _migrateBlueprint(File file) {
    try {
      final summary = LuminaAssetSummary.read(file);
      if (summary.type != AssetType.actor || summary.documentParentClass != 'LuminaCharacter') return false;
      final bytes = file.readAsBytesSync();
      final hasHeader = bytes.length >= 4 && bytes[0] == 0x4C && bytes[1] == 0x4D && bytes[2] == 0x41 && bytes[3] == 0x53;
      final asset = jsonDecode(utf8.decode(hasHeader ? bytes.sublist(4) : bytes));
      if (asset is! Map || asset['raw_payload'] is! String) return false;
      final doc = jsonDecode(utf8.decode(base64Decode(asset['raw_payload'] as String)));
      if (doc is! Map || doc['parentClass'] != 'LuminaCharacter') return false;
      final defaults = doc['classDefaults'];
      if (defaults is! Map || defaults['baseEyeHeight'] is! num || (defaults['baseEyeHeight'] as num) != legacyValue) return false;
      if (_rootCapsuleHalfHeight(doc['components']) != LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight) return false;

      defaults['baseEyeHeight'] = newValue;
      final patchedAsset = Map<String, dynamic>.from(asset)..['raw_payload'] = base64Encode(utf8.encode(jsonEncode(doc)));
      final json = utf8.encode(jsonEncode(LuminaAsset.withTrailingPayload(patchedAsset)));
      file.writeAsBytesSync([if (hasHeader) ...const [0x4C, 0x4D, 0x41, 0x53], ...json], flush: true);
      return true;
    } catch (_) {
      return false; // Not a readable Blueprint: nothing to migrate.
    }
  }

  /// The half height of the Blueprint's root capsule, or null without one.
  static double? _rootCapsuleHalfHeight(Object? components) {
    if (components is! List) return null;
    for (final c in components) {
      if (c is! Map || c['type'] != 'LuminaCapsuleComponent') continue;
      final parent = c['parentId'];
      if (parent is String && parent.isNotEmpty) continue;
      final props = c['properties'];
      final h = props is Map ? props['capsuleHalfHeight'] : null;
      return h is num ? h.toDouble() : null;
    }
    return null;
  }

  static final RegExp _generatedLine = RegExp('^(\\s*)baseEyeHeight = ${RegExp.escape(legacyValue.toString())};\$', multiLine: true);

  /// Patches the compiled Blueprint's `baseEyeHeight = 160.0;` constructor
  /// line; true when it did.
  static bool _patchGenerated(File file) {
    if (!file.existsSync()) return false;
    final text = file.readAsStringSync();
    if (_generatedLine.allMatches(text).length != 1) return false;
    file.writeAsStringSync(text.replaceFirstMapped(_generatedLine, (m) => '${m[1]}baseEyeHeight = $newValue;'), flush: true);
    return true;
  }
}
