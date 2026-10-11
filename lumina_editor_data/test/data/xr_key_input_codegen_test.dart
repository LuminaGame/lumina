import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

/// Project input bound to XR controller keys generates the engine's key
/// constants (`LuminaKey.xrRightA`, not the id with a lower-cased letter).
void main() {
  test('the generated project input names the XR key constants', () {
    expect(DartCodeGeneratorService.keyConstantName('XR_Right_A'), 'xrRightA');
    expect(DartCodeGeneratorService.keyConstantName('XR_Left_Thumbstick_Click'), 'xrLeftThumbstickClick');
    expect(DartCodeGeneratorService.keyConstantName('KeyV'), 'keyV');
    expect(DartCodeGeneratorService.keyConstantName('MouseX'), 'mouseX');
    final dir = Directory.systemTemp.createTempSync('xr_keys_codegen_');
    addTearDown(() => dir.deleteSync(recursive: true));
    DartCodeGeneratorService().writeProjectInputDart(dir.path, MetaXrPosingContent.input);
    final code = File('${dir.path}/lib/input/project_input.g.dart').readAsStringSync();
    for (final k in ['xrRightB', 'xrLeftY', 'xrLeftMenu', 'xrRightA', 'xrLeftX', 'xrLeftThumbstickClick', 'xrRightThumbstickX', 'xrLeftThumbstickY']) {
      expect(code, contains('LuminaKey.$k'), reason: k);
    }
    expect(code, isNot(contains('xR_')));
  });
}
