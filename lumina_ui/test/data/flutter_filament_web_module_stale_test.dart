import 'dart:io';

import 'package:flutter_filament/filament.dart' show FilamentInfo;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/flutter_filament_web_module.dart';

/// A web cook refuses a flutter_filament WebAssembly module that cannot run
/// the game: one built for another Filament release (it refuses the
/// editor's materials), or one older than the package's web bindings (the
/// game throws when it calls a function the module lacks, which stopped a
/// MetaHuman game's ticks and its input).
void main() {
  final package = Directory('${Directory.current.parent.path}/flutter_filament');
  final module = FlutterFilamentWebModule.at(Directory('${package.path}/web'));
  final skip = module == null ? 'needs flutter_filament/web/flutter_filament.{js,wasm} (tool/web/build_module.sh)' : null;

  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('lumina_web_module_'));
  tearDown(() => temp.deleteSync(recursive: true));

  /// A copy of the package's module and web bindings under [temp], laid out
  /// as the package is (`web/` beside `lib/`).
  FlutterFilamentWebModule copy({String extraBinding = ''}) {
    final web = Directory('${temp.path}/flutter_filament/web')..createSync(recursive: true);
    for (final f in module!.files) {
      f.copySync('${web.path}/${f.uri.pathSegments.last}');
    }
    final lib = Directory('${temp.path}/flutter_filament/lib/src/third_party')..createSync(recursive: true);
    final bindings = File('${package.path}/lib/src/third_party/filament_c.web.g.dart').readAsStringSync();
    File('${lib.path}/filament_c.web.g.dart').writeAsStringSync('$bindings$extraBinding');
    return FlutterFilamentWebModule.at(web)!;
  }

  test('the package module is current: built for the linked Filament, with every function the bindings call', () {
    expect(module!.staleReason(filamentVersion: FilamentInfo.version), isNull);
    expect(module.missingExports(), isEmpty);
  }, skip: skip);

  test('a module built for another Filament release is refused, naming the release the editor needs', () {
    final reason = copy().staleReason(filamentVersion: '1.99.0');
    expect(reason, contains("built for another Filament release than the editor's (1.99.0)"));
  }, skip: skip);

  test('a module older than the bindings is refused, naming the functions it lacks', () {
    final stale = copy(extraBinding: "\n// a function added after the module was built\n@JS('_filament_transform_copy_poses_v2')\n");
    expect(stale.missingExports(), ['filament_transform_copy_poses_v2']);
    expect(stale.staleReason(filamentVersion: FilamentInfo.version), contains('lacks 1 function the game calls (filament_transform_copy_poses_v2)'));
  }, skip: skip);
}
