/// Prints what `tool/src/filament_material_code.dart` reads from a Filament
/// checkout (default: `LUMINA_FILAMENT_WORK`, else `build/filament-src`):
/// matc's header keys and values, the shader public API and the input
/// structures. For checking the generator against a new Filament release.
library;

import 'dart:io';

import 'package:lumina_core/lumina_core.dart' show LuminaWorkspace;
import 'package:path/path.dart' as p;

import 'src/filament_material_code.dart';

void main(List<String> args) {
  final root = args.isNotEmpty
      ? args.first
      : Platform.environment['LUMINA_FILAMENT_WORK'] ?? p.join(LuminaWorkspace.root, 'build', 'filament-src');
  final code = FilamentMaterialCode.read(root);
  for (final k in code.headerKeys) {
    stdout.writeln('key ${k.name} ${k.jsonType} ${k.values}'
        '${k.aliases.isEmpty ? '' : ' aliases ${k.aliases}'}${k.ignored.isEmpty ? '' : ' ignored ${k.ignored.keys}'}'
        '${k.builderDoc.isEmpty ? '' : '\n    ${k.builderDoc}'}');
  }
  stdout.writeln('blendFunctions ${code.blendFunctions}');
  stdout.writeln('parameterTypes ${code.parameterTypes}');
  stdout.writeln('precisions ${code.precisions} constantTypes ${code.constantTypes}');
  stdout.writeln('properties ${code.properties}');
  for (final f in code.functions) {
    stdout.writeln('fn [${f.stage}] ${f.signature}'
        '${f.deprecated == null ? '' : '  DEPRECATED ${f.deprecated} -> ${f.replacement}'}');
  }
  for (final f in code.materialInputs) {
    stdout.writeln('MaterialInputs ${f.glslType} ${f.name} ${f.shadingModels} api ${f.apiLevel}');
  }
  for (final f in code.vertexInputs) {
    stdout.writeln('MaterialVertexInputs ${f.glslType} ${f.name} ${f.shadingModels} api ${f.apiLevel}');
  }
}
