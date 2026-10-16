import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/filament_material_api.g.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/mat_completion.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/mat_migration.dart';

String material({String header = '', String fragment = 'prepareMaterial(material);'}) =>
    '''
material {
    name : "M_Old",
    shadingModel : lit,
$header
}

fragment {
    void material(inout MaterialInputs material) {
        $fragment
    }
}
''';

int lines(String s) => '\n'.allMatches(s).length;

void main() {
  group('header values', () {
    test('drops variant filters matc ignores or no longer accepts and keeps the others', () {
      final old = material(header: '    variantFilter : [ dynamicLighting, skinning, directionalLighting, fog ],');
      final m = MatMigration.of(old);
      expect(m.changed, isTrue);
      expect(m.source, contains('variantFilter : [ skinning, fog ]'));
      expect(m.source, isNot(contains('Lighting')));
      expect(m.changes.single.line, 4);
      expect(m.changes.single.message, contains('removed dynamicLighting'));
      expect(m.changes.single.message, contains('removed directionalLighting'));
    });

    test('a list on several lines keeps its line count and loses the dangling comma', () {
      final old = material(header: '    variantFilter : [\n        skinning,\n        directionalLighting\n    ],');
      final m = MatMigration.of(old);
      expect(lines(m.source), lines(old));
      expect(m.source, contains('variantFilter : [\n        skinning\n'));
      expect(m.source, isNot(contains('directionalLighting')));
    });

    test('a list of only removed values becomes empty', () {
      final m = MatMigration.of(material(header: '    variantFilter : [directionalLighting],'));
      expect(m.source, contains('variantFilter : [],'));
    });

    test('backward-compatible aliases become the value they stand for, quoted or not', () {
      final bare = MatMigration.of(material(header: '    specularAmbientOcclusion : true,'));
      expect(bare.source, contains('specularAmbientOcclusion : simple,'));
      expect(bare.changes.single.message, contains('replaced with simple'));
      final quoted = MatMigration.of(material(header: '    specularAmbientOcclusion : "false",'));
      expect(quoted.source, contains('specularAmbientOcclusion : "none",'));
    });

    test('a key in a comment is left alone', () {
      final old = material(header: '    // variantFilter : [directionalLighting],');
      expect(MatMigration.of(old).changed, isFalse);
    });
  });

  group('shader functions', () {
    test('calls of a deprecated getter become the expression it returns', () {
      final old = material(fragment: 'prepareMaterial(material);\n        float3 o = getWorldOffset();');
      final m = MatMigration.of(old);
      final getter = filamentFunctions.firstWhere((f) => f.name == 'getWorldOffset');
      expect(m.source, contains('float3 o = ${getter.replacement};'));
      expect(m.changes.single.line, 10);
      expect(lines(m.source), lines(old));
    });

    test('a call in a comment and a source declaring its own getter are left alone', () {
      expect(MatMigration.of(material(fragment: '// getWorldOffset()\n        prepareMaterial(material);')).changed, isFalse);
      final own = 'float3 getWorldOffset() { return float3(0.0); }\n${material(fragment: 'float3 o = getWorldOffset();')}';
      expect(MatMigration.of(own).changed, isFalse);
    });
  });

  test('a current source is returned unchanged', () {
    final current = material(header: '    variantFilter : [skinning, ssr],\n    specularAmbientOcclusion : bentNormals,');
    final m = MatMigration.of(current);
    expect(m.changed, isFalse);
    expect(identical(m.source, current), isTrue);
  });

  group('completion offers only what the current Filament accepts', () {
    MatCompletionResult at(String marked) {
      final offset = marked.indexOf('|');
      return MatCompletion.suggest(marked.replaceFirst('|', ''), offset, explicit: true);
    }

    test('variant filters: no removed value, the code-only ones included', () {
      final r = at('material {\n    variantFilter : [ | ]\n}\n');
      final values = [for (final i in r.items) i.label];
      expect(values, containsAll(['shadowReceiver', 'skinning', 'vsm', 'fog', 'ssr', 'stereo']));
      expect(values, isNot(contains('directionalLighting')));
      expect(values, isNot(contains('dynamicLighting')));
    });

    test('a deprecated getter is not suggested, a current one is', () {
      final r = at(material(fragment: 'prepareMaterial(material);\n        float3 o = getW|'));
      final names = [for (final i in r.items) i.label];
      expect(names, contains('getWorldPosition'));
      expect(names, isNot(contains('getWorldOffset')));
    });

    test('keys the documentation leaves out are suggested and say so', () {
      final r = at('material {\n    name : "M",\n    stereo|\n}\n');
      final item = r.items.firstWhere((i) => i.label == 'stereoscopicType');
      expect(item.documentation, contains('Not in the material documentation'));
    });
  });
}
