import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import '../../../lumina/test/blueprint/ragdoll_blueprint.dart';

/// The ragdoll nodes compile to the same library calls the VM makes, and the
/// ragdoll component reaches the generated class through the component
/// table with its properties.
void main() {
  test('the ragdoll Blueprint compiles without issues to the ragdoll library calls', () {
    final result = const BlueprintDartGenerator()
        .generate(ragdollBlueprint(), className: 'BpRagdoll', assetPath: 'contents/blueprints/bp_ragdoll.lmas');
    expect(result.issues.where((i) => i.isError), isEmpty, reason: result.issues.join('\n'));
    final code = result.code!;
    expect(code, contains('LuminaBlueprintFunctionLibrary.startRagdoll(this)'));
    expect(code, contains('LuminaBlueprintFunctionLibrary.isRagdoll(this)'));
    expect(code, contains('LuminaBlueprintFunctionLibrary.toggleRagdoll(this)'));
    expect(code, contains('LuminaBlueprintFunctionLibrary.stopRagdoll(this, true)'));
    expect(code, contains('LuminaBlueprintFunctionLibrary.addRagdollImpulse(this, '));
    expect(code, contains("'LuminaRagdollComponent'"));
    expect(code, contains("'getUpClips'"));
  });
}
