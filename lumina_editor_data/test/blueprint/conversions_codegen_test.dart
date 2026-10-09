import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import '../../../lumina/test/blueprint/conversions_blueprint.dart';
import '../../../lumina/test/blueprint/generated/bp_conversions.g.dart';

/// The Math|Conversions nodes compile to the same library calls the VM makes.
void main() {
  test('the conversions Blueprint compiles without issues to the conversion library calls', () {
    final result = const BlueprintDartGenerator().generate(conversionsBlueprint(),
        className: 'BpConversions', assetPath: 'contents/blueprints/bp_conversions.lmas');
    expect(result.issues, isEmpty, reason: result.issues.join('\n'));
    final code = result.code!;
    for (final call in [
      'LuminaBlueprintFunctionLibrary.intToFloat(7)',
      'LuminaBlueprintFunctionLibrary.round(2.5)',
      'LuminaBlueprintFunctionLibrary.truncate(-2.7)',
      'LuminaBlueprintFunctionLibrary.floor(-2.1)',
      'LuminaBlueprintFunctionLibrary.ceil(2.1)',
      'LuminaBlueprintFunctionLibrary.boolToInt(true)',
      'LuminaBlueprintFunctionLibrary.intToBool(0)',
      'LuminaBlueprintFunctionLibrary.boolToFloat(true)',
      "LuminaBlueprintFunctionLibrary.stringToIntChecked(' 42 ')",
      "LuminaBlueprintFunctionLibrary.stringToFloatChecked('abc')",
      "LuminaBlueprintFunctionLibrary.stringToName('Door_01')",
      'LuminaBlueprintFunctionLibrary.nameToString(',
      'LuminaBlueprintFunctionLibrary.floatToVector(2.5)',
      'LuminaBlueprintFunctionLibrary.floatToVector2D(-1.0)',
    ]) {
      expect(code, contains(call), reason: call);
    }
    expect(code, contains('.success'), reason: 'Success is read from the record');
  });

  test('VM and generated code print the same conversions', () {
    List<LuminaBlueprintTraceEvent> run(bool generated) {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final actor = generated
          ? BpConversions()
          : LuminaBlueprintClass.fromDocument(conversionsBlueprint(), name: 'bp_conversions').instantiate();
      final trace = <LuminaBlueprintTraceEvent>[];
      (actor as LuminaBlueprintRuntime).trace = trace.add;
      world.persistentLevel.registerActor(actor);
      world.beginPlay();
      return trace;
    }

    final vm = run(false);
    final gen = run(true);
    expect([for (final t in gen.where((t) => t.printed != null)) t.printed], conversionsBlueprintPrints);
    expect([for (final t in gen) t.registryId], [for (final t in vm) t.registryId]);
    expect([for (final t in gen) t.printed], [for (final t in vm) t.printed]);
  });
}
