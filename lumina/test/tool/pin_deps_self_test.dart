import 'package:test/test.dart';

import '../../../tool/pin_deps.dart' as pin;

/// `--self`: pinning a checkout other than lumina pins its lumina
/// dependency and leaves its own repo's git dependencies alone.
void main() {
  const pubspec = '''
name: lumina_plugin_example
dependencies:
  lumina:
    git:
      url: https://github.com/LuminaGame/lumina.git
      path: lumina
  sibling:
    git:
      url: https://github.com/LuminaGame/plugins.git
      path: sibling
''';

  String sha(String repo) => repo == 'lumina' ? 'a' * 40 : 'b' * 40;

  test('a plugins checkout pins lumina and skips its own repo', () {
    final out = pin.pinPubspec(pubspec, sha, self: 'plugins');
    expect(out, contains('path: lumina\n      ref: ${'a' * 40}'));
    expect(out, isNot(contains('b' * 40)));
  });

  test('the default self is lumina', () {
    final out = pin.pinPubspec(pubspec, sha);
    expect(out, contains('ref: ${'b' * 40}'));
    expect(out, isNot(contains('a' * 40)));
  });

  test('crossRepo honours self', () {
    final deps = pin.findGitDependencies(pubspec.split('\n'));
    expect(pin.crossRepo(deps, self: 'plugins').map((d) => d.repo), ['lumina']);
    expect(pin.crossRepo(deps).map((d) => d.repo), ['plugins']);
  });
}
