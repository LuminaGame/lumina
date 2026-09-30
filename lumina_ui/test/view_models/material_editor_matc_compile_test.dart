import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/models/lumina_asset.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';

/// The Material Editor compiles the whole `.mat` source with the material
/// compiler (Filament's own `.mat` parser): every header key, the `vertex`
/// block wherever it is written, and the compiler's own messages as issues.
const _header = '''material {
    name : M_Wave,
    shadingModel : unlit,
    blending : fade,
    requires : [ color ],
    variables : [ tint ]
}''';

const _fragment = '''fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = vec4(variable_tint.rgb, 0.75);
    }
}''';

const _vertex = '''vertex {
    void materialVertex(inout MaterialVertexInputs material) {
        material.tint = vec4(material.color.rgb * 0.5 + vec3(0.5, 0.25, 0.0), 1.0);
    }
}''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FilamentEngine engine;

  setUpAll(() {
    engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
  });

  tearDownAll(() {
    if (!engine.isDisposed) engine.dispose();
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('mat_matc_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<MaterialEditorViewModel> openWith(String source, {String name = 'M_Wave'}) async {
    final file = File('${tempDir.path}/$name.lmas');
    file.writeAsBytesSync(LuminaAsset(
      assetId: name,
      name: name,
      type: AssetType.filamat,
      rawMatSource: source,
      // A payload so load() does not compile on its own: each test compiles.
      rawPayload: Uint8List.fromList([1]),
    ).toProtoBufferBytes());
    final vm = MaterialEditorViewModel(assetPath: file.path);
    await vm.load();
    return vm;
  }

  FilamentMaterial materialOf(MaterialEditorViewModel vm) =>
      FilamentMaterial.fromBuffer(engine: engine, filamatBuffer: vm.compiledBytes!);

  test('a vertex block written after the fragment compiles, and its code is compiled', () async {
    final vm = await openWith('$_header\n$_fragment\n$_vertex\n');
    expect(await vm.compile(), isTrue, reason: vm.issues.map((i) => i.message).join('\n'));
    final material = materialOf(vm);
    expect(material.shading, FilamatShading.unlit);
    expect(material.blendingMode, BlendingMode.fade);
    expect(material.requiredAttributes, contains(VertexAttribute.color));
    material.dispose();

    // The vertex code reaches the compiler: an error in it fails at its line.
    final broken = '$_header\n$_fragment\n${_vertex.replaceFirst('material.color.rgb', 'notAColour')}\n';
    vm.currentCode = broken;
    expect(await vm.compile(), isFalse);
    final line = broken.split('\n').indexWhere((l) => l.contains('notAColour')) + 1;
    expect(vm.issues.where((i) => i.severity == MaterialCompileSeverity.error).map((i) => i.line), contains(line));
    expect(vm.issues.any((i) => i.message.contains("'notAColour' : undeclared identifier")), isTrue);
    expect(vm.syntaxStatus, startsWith('Compile Error'));
  });

  test('a vertex block written before the fragment compiles', () async {
    final vm = await openWith('$_header\n$_vertex\n$_fragment\n');
    expect(await vm.compile(), isTrue, reason: vm.issues.map((i) => i.message).join('\n'));
    final material = materialOf(vm);
    expect(material.name, 'M_Wave');
    material.dispose();
  });

  test('header keys the editor never mapped reach the compiled material; the header bar shows them', () async {
    final vm = await openWith('''material {
    name : M_Keys,
    shadingModel : specularGlossiness,
    blending : transparent,
    transparency : twoPassesOneSide,
    culling : front
}
fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = vec4(0.4, 0.5, 0.6, 0.5);
        material.glossiness = 0.7;
    }
}
''', name: 'M_Keys');
    expect(await vm.compile(), isTrue, reason: vm.issues.map((i) => i.message).join('\n'));
    final material = materialOf(vm);
    expect(material.shading, FilamatShading.specularGlossiness);
    expect(material.blendingMode, BlendingMode.transparent);
    expect(material.transparencyMode, TransparencyMode.twoPassesOneSide);
    expect(material.cullingMode, CullingMode.front);
    material.dispose();
    expect(vm.shading, FilamatShading.specularGlossiness);
    expect(vm.blending, BlendingMode.transparent);

    vm.currentCode = vm.currentCode.replaceFirst('blending : transparent', 'blending : fade');
    await vm.compile();
    expect(vm.blending, BlendingMode.fade);
  });

  test("a header syntax error is matc's message at its line", () async {
    final vm = await openWith('material {\n    name : M_Bad,\n    shadingModel lit\n}\n$_fragment\n', name: 'M_Bad');
    expect(await vm.compile(), isFalse);
    final error = vm.issues.firstWhere((i) => i.severity == MaterialCompileSeverity.error);
    expect(error.line, 3);
    expect(error.message, contains('line:3'));
    expect(error.fromCompiler, isTrue);
  });

  test('a GLSL error in the fragment is reported at its .mat line with the compiler text', () async {
    final source = '$_header\n${_fragment.replaceFirst('variable_tint.rgb', 'missingThing')}\n$_vertex\n';
    final vm = await openWith(source);
    expect(await vm.compile(), isFalse);
    final line = source.split('\n').indexWhere((l) => l.contains('missingThing')) + 1;
    final error = vm.issues.firstWhere((i) => i.severity == MaterialCompileSeverity.error);
    expect(error.line, line);
    expect(error.message, contains("'missingThing' : undeclared identifier"));
  });

  test("the editor's quick checks do not stand in the way: a post-process material without prepareMaterial compiles", () async {
    final vm = await openWith('''material {
    name : M_Post,
    domain : postprocess
}
fragment {
    void postProcess(inout PostProcessInputs postProcess) {
        postProcess.color = vec4(1.0, 0.5, 0.0, 1.0);
    }
}
''', name: 'M_Post');
    expect(await vm.compile(), isTrue, reason: vm.issues.map((i) => i.message).join('\n'));
    final material = materialOf(vm);
    expect(material.materialDomain, MaterialDomain.postProcess);
    material.dispose();
  });

  test("the editor's new-material template compiles", () async {
    final vm = MaterialEditorViewModel(assetPath: '${tempDir.path}/M_New.lmas');
    await vm.load();
    expect(vm.compiledBytes, isNotNull, reason: vm.issues.map((i) => i.message).join('\n'));
    expect(vm.syntaxStatus, startsWith('Compile OK'));
  });
}
