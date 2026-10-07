/// Generates `lib/ui/features/sub_editors/services/mat_language/filament_material_api.g.dart`
/// (the `.mat` completion tables) from Filament's material documentation.
///
/// ```
/// dart run tool/generate_filament_material_api.dart [<Materials.md.html>] [--version <x.y.z>]
/// ```
///
/// The document defaults to `docs_src/src_markdeep/Materials.md.html` in the
/// Filament checkout `tool/filament/build_prebuilt.*` builds from:
/// `LUMINA_FILAMENT_WORK`, else `<workspace>/build/filament-src`. The
/// version defaults to that checkout's `android/gradle.properties`
/// `VERSION_NAME`.
library;

import 'dart:io';

import 'package:lumina_core/lumina_core.dart' show LuminaWorkspace;
import 'package:path/path.dart' as p;

import 'src/filament_material_api_writer.dart';
import 'src/filament_material_doc.dart';

/// The material documentation inside a Filament checkout.
const materialsDocRelativePath = 'docs_src/src_markdeep/Materials.md.html';

/// The Filament checkout the prebuilt scripts use.
String defaultFilamentSource() =>
    Platform.environment['LUMINA_FILAMENT_WORK'] ?? p.join(LuminaWorkspace.root, 'build', 'filament-src');

Future<void> main(List<String> args) async {
  String? docPath;
  String? version;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--version' && i + 1 < args.length) {
      version = args[++i];
    } else if (args[i] == '--help' || args[i] == '-h') {
      stdout.writeln('usage: dart run tool/generate_filament_material_api.dart [<Materials.md.html>] [--version <x.y.z>]');
      return;
    } else {
      docPath = args[i];
    }
  }
  docPath ??= p.join(defaultFilamentSource(), materialsDocRelativePath);
  final doc = File(docPath);
  if (!await doc.exists()) {
    stderr.writeln('Material documentation not found: $docPath');
    stderr.writeln('Pass its path, or set LUMINA_FILAMENT_WORK to the Filament checkout.');
    exitCode = 2;
    return;
  }
  if (version == null) {
    final props = File(p.join(p.dirname(docPath), '..', '..', 'android', 'gradle.properties'));
    if (await props.exists()) {
      version = RegExp(r'^VERSION_NAME=(.+)$', multiLine: true).firstMatch(await props.readAsString())?[1]?.trim();
    }
  }
  final parsed = FilamentMaterialDoc.parse(await doc.readAsString());
  final out = File(p.join(
    p.dirname(p.dirname(Platform.script.toFilePath())),
    'lib/ui/features/sub_editors/services/mat_language/filament_material_api.g.dart',
  ));
  await out.writeAsString(renderFilamentMaterialApi(parsed, filamentVersion: version ?? 'unknown'));
  stdout.writeln('Wrote ${out.path}: ${parsed.headerKeys.length} header keys, '
      '${parsed.fragmentInputs.length} MaterialInputs fields, ${parsed.vertexInputs.length} MaterialVertexInputs '
      'fields, ${parsed.functions.length} functions, ${parsed.typeAliases.length} type aliases, '
      '${parsed.constants.length} constants.');
}
