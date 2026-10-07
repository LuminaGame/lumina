import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:lumina_core/lumina_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

/// A pure-Dart program reads and writes Lumina's files through
/// `lumina_core` alone: a `.lmproject`, a level `.lmas` and a `.lmplugin`,
/// each written to a real temp project, read, written back and read again.
void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('lumina_core_formats_'));
  tearDown(() {
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows can hold a handle briefly; the temp folder is cleaned later.
    }
  });

  test('a .lmproject reads, writes and reads back equal', () {
    final project = LuminaProject(
      projectName: 'CoreGame',
      activeLevel: 'contents/levels/L_Core.lmas',
      enabledPlugins: const ['lumina_plugin_metaxr'],
      template: 'third_person',
      pluginSettings: const {
        'lumina_plugin_metaxr': {'passthrough': true, 'opacity': 0.5},
      },
      pluginIsolation: const {'lumina_plugin_metaxr': PluginIsolation.inProcess},
      extraFields: const {'studio_note': 'kept'},
    );
    final file = File(p.join(temp.path, 'CoreGame.lmproject'))
      ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(project.toMap()));

    final read = LuminaProject.fromMap(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
    expect(read.projectName, 'CoreGame');
    expect(read.activeLevel, 'contents/levels/L_Core.lmas');
    expect(read.enabledPlugins, ['lumina_plugin_metaxr']);
    expect(read.template, 'third_person');
    expect(read.pluginIsolation, {'lumina_plugin_metaxr': PluginIsolation.inProcess});
    expect(read.pluginSettings['lumina_plugin_metaxr'], {'passthrough': true, 'opacity': 0.5});
    expect(read.extraFields['studio_note'], 'kept');
    expect(read.worldUnits, kWorldUnitsCentimetres);
    expect(read.upAxis, kUpAxisZ);

    file.writeAsStringSync(jsonEncode(read.toMap()));
    final again = LuminaProject.fromMap(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
    expect(again.toMap(), read.toMap());
    expect(jsonEncode(again.toMap()), jsonEncode(project.toMap()));
  });

  test('a level .lmas with actors, world partition and a Level Blueprint reads, writes and reads back equal', () {
    final repo = LuminaLevelRepository(temp.path);
    const path = 'contents/levels/L_Core.lmas';
    final level = LuminaLevelDocument(relativePath: path)
      ..actors = [
        {
          'id': 'act_floor',
          'name': 'Floor',
          'class': 'StaticMeshActor',
          'location': [0.0, 0.0, 0.0],
          'rotation': [0.0, 0.0, 0.0],
          'scale': [10.0, 10.0, 1.0],
          'mesh': 'contents/meshes/SM_Floor.lmas',
        },
        {
          'id': 'act_barrel',
          'name': 'Barrel',
          'class': 'StaticMeshActor',
          'location': [250.0, -40.0, 0.0],
          'rotation': [0.0, 0.0, 90.0],
          'scale': [1.0, 1.0, 1.0],
          'mesh': 'contents/meshes/SM_Barrel.lmas',
        },
      ];
    level.metadata['worldPartition'] = {'enabled': true, 'cellSize': 25600, 'loadingRange': 51200};
    level.levelBlueprintJson = {
      'kind': 'level',
      'levelPath': path,
      'graphs': [
        {'name': 'EventGraph', 'nodes': <Object>[]},
      ],
    };
    repo.save(level);
    expect(File(p.join(temp.path, path)).existsSync(), isTrue);

    final read = repo.load(path)!;
    expect(read.name, 'L_Core');
    expect(read.actors.map((a) => a['id']), ['act_floor', 'act_barrel']);
    expect(read.metadata['worldPartition'], {'enabled': true, 'cellSize': 25600, 'loadingRange': 51200});
    expect(read.hasLevelBlueprint, isTrue);
    expect(read.levelBlueprintJson!['levelPath'], path);

    repo.save(read);
    final again = repo.load(path)!;
    expect(again.encode(), read.encode());
    expect(jsonDecode(again.encode()), jsonDecode(level.encode()));

    // An empty Blueprint removes the key, so a level without a script stays as it was.
    again.levelBlueprintJson = null;
    expect(again.hasLevelBlueprint, isFalse);
    expect(again.metadata.containsKey(LuminaLevelDocument.levelBlueprintKey), isFalse);
  });

  test('a .lmplugin with isolation and a process_class scans, writes and reads back equal', () async {
    final pluginDir = Directory(p.join(temp.path, 'plugins', 'lumina_plugin_core_probe'))..createSync(recursive: true);
    final manifest = File(p.join(pluginDir.path, 'lumina_plugin_core_probe.lmplugin'))
      ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
        'name': 'lumina_plugin_core_probe',
        'friendly_name': 'Core Probe',
        'version': '0.2.0',
        'description': 'Reads Lumina files from a pure-Dart process.',
        'category': 'Tools',
        'license': 'MIT',
        'authors': ['Lumina'],
        'engine_version': '>=0.0.1 <1.0.0',
        'isolation': 'process',
        'dependencies': [
          {'name': 'lumina_plugin_openxr', 'version': '>=0.1.0'},
        ],
        'modules': [
          {
            'name': 'lumina_plugin_core_probe',
            'type': 'editor',
            'entry_library': 'lib/lumina_plugin_core_probe.dart',
            'registration_class': 'CoreProbePlugin',
            'process_class': 'CoreProbeProcess',
          },
        ],
      }));

    final scan = await PluginRepository(
      roots: [PluginScanRoot(dir: Directory(p.join(temp.path, 'plugins')), origin: PluginOrigin.project)],
    ).scanAll();
    expect(scan.errors, isEmpty);
    final plugin = scan.plugins.single;
    expect(plugin.name, 'lumina_plugin_core_probe');
    expect(plugin.isolation, PluginIsolation.process);
    expect(plugin.processClass, 'CoreProbeProcess');
    expect(plugin.effectiveIsolation(), PluginIsolation.process);
    expect(
      plugin.effectiveIsolation(const LuminaProject(
        projectName: 'CoreGame',
        pluginIsolation: {'lumina_plugin_core_probe': PluginIsolation.inProcess},
      )),
      PluginIsolation.inProcess,
    );
    expect(plugin.extras['license'], 'MIT');

    manifest.writeAsStringSync(jsonEncode(plugin.toJson()));
    final again = await PluginRepository(
      roots: [PluginScanRoot(dir: Directory(p.join(temp.path, 'plugins')), origin: PluginOrigin.project)],
    ).scanAll();
    final back = again.plugins.single;
    expect(back, plugin);
    expect(back.toJson(), plugin.toJson());
  });

  test('units and axes convert as the engine expects', () {
    // One world unit is one centimetre.
    expect(LuminaUnits.unitsPerMetre, 100.0);
    expect(LuminaUnits.metres(1.8), closeTo(180.0, 1e-9));
    expect(LuminaUnits.toMetres(250.0), closeTo(2.5, 1e-9));
    expect(LuminaUnits.gravity, 980.0);

    // Stored transforms are Z-up; the runtime is Y-up.
    final runtime = LuminaAxes.location([100.0, 200.0, 50.0]);
    expect(runtime.x, 100.0);
    expect(runtime.y, 50.0);
    expect(runtime.z, -200.0);
    expect(LuminaAxes.toAuthoringLocation(runtime), [100.0, 200.0, 50.0]);
    expect(LuminaAxes.scale([2.0, 3.0, 4.0]), Vector3(2.0, 4.0, 3.0));
    expect(LuminaAxes.toAuthoringExtent(LuminaAxes.extent([10.0, 20.0, 30.0])), [10.0, 20.0, 30.0]);

    // A yaw of 90° about the stored Z axis turns about the runtime Y axis.
    final yaw = LuminaAxes.rotation([0.0, 0.0, 90.0]);
    final forward = yaw.rotateVector(Vector3(1.0, 0.0, 0.0));
    expect(forward.x, closeTo(math.cos(math.pi / 2), 1e-9));
    expect(forward.y, closeTo(0.0, 1e-9));
    expect(forward.z.abs(), closeTo(1.0, 1e-9));
  });
}
