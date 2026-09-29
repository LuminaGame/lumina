import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';

// Test implementation
class TestPlugin extends LuminaEditorPlugin {
  @override
  String get pluginName => 'TestPlugin';

  @override
  void register(LuminaEditorContext context) {}
  
  @override
  void unregister(LuminaEditorContext context) {}
}

void main() {
  test('LuminaEditorPlugin API contract exists', () {
    final plugin = TestPlugin();
    expect(plugin.pluginName, 'TestPlugin');
  });
}
