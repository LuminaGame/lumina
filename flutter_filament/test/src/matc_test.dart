// FilamentMatc: whole `.mat` material definitions compiled by Filament's own
// matc parser, each package loaded into a real Material on a noop engine.
import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

const _vertexTint = '''
    void materialVertex(inout MaterialVertexInputs material) {
        material.tint = vec4(material.color.rgb * 0.5 + 0.5, 1.0);
        material.worldPosition.y += sin(material.worldPosition.x) * 0.1;
    }''';

const _fragmentTint = '''
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = vec4(variable_tint.rgb, 1.0);
        material.roughness = 0.5;
    }''';

const _header = '''
material {
    name : TintWave,
    shadingModel : lit,
    requires : [ color ],
    variables : [ tint ]
}''';

void main() {
  late FilamentEngine engine;

  setUpAll(() {
    engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
  });

  tearDownAll(() {
    if (!engine.isDisposed) engine.dispose();
  });

  FilamentMaterial load(MatcResult result) {
    expect(result.ok, isTrue, reason: result.log);
    expect(result.package, isNotNull);
    return FilamentMaterial.fromBuffer(engine: engine, filamatBuffer: result.package!);
  }

  String surface(String header, {String fragment = _fragmentBasic}) => '$header\nfragment {\n$fragment\n}\n';

  test('a lit material with a vertex block and variables compiles', () {
    final result = FilamentMatc.compile('$_header\nvertex {\n$_vertexTint\n}\nfragment {\n$_fragmentTint\n}\n');
    final material = load(result);
    expect(material.name, 'TintWave');
    expect(material.shading, FilamatShading.lit);
    expect(material.requiredAttributes, contains(VertexAttribute.color));
    material.dispose();
  });

  test('a vertex block written after the fragment compiles the same material', () {
    final result = FilamentMatc.compile('$_header\nfragment {\n$_fragmentTint\n}\nvertex {\n$_vertexTint\n}\n');
    final material = load(result);
    expect(material.name, 'TintWave');
    material.dispose();
  });

  test('the vertex block is compiled: a GLSL error in it fails at its .mat line', () {
    final source = '$_header\nfragment {\n$_fragmentTint\n}\nvertex {\n'
        '    void materialVertex(inout MaterialVertexInputs material) {\n'
        '        material.tint = undeclaredThing;\n'
        '    }\n}\n';
    final line = source.split('\n').indexWhere((l) => l.contains('undeclaredThing')) + 1;
    final result = FilamentMatc.compile(source);
    expect(result.ok, isFalse);
    expect(result.package, isNull);
    expect(result.errorText, contains('undeclaredThing'));
    expect(result.diagnostics.where((d) => d.severity == MatcSeverity.error).map((d) => d.line), contains(line));
  });

  test('specularGlossiness shading', () {
    final m = load(FilamentMatc.compile(surface('material { name : Sg, shadingModel : specularGlossiness }')));
    expect(m.shading, FilamatShading.specularGlossiness);
    m.dispose();
  });

  test('fade and multiply blending', () {
    final fade = load(FilamentMatc.compile(surface('material { name : F, blending : fade }')));
    expect(fade.blendingMode, BlendingMode.fade);
    fade.dispose();
    final multiply = load(FilamentMatc.compile(surface('material { name : M, shadingModel : unlit, blending : multiply }',
        fragment: _fragmentUnlit)));
    expect(multiply.blendingMode, BlendingMode.multiply);
    multiply.dispose();
  });

  test('transparent blending with transparency twoPassesOneSide', () {
    final m = load(FilamentMatc.compile(
        surface('material { name : T, blending : transparent, transparency : twoPassesOneSide }')));
    expect(m.blendingMode, BlendingMode.transparent);
    expect(m.transparencyMode, TransparencyMode.twoPassesOneSide);
    m.dispose();
  });

  test('screen-space thin refraction', () {
    final m = load(FilamentMatc.compile(surface(
        'material { name : R, blending : opaque, refractionMode : screenspace, refractionType : thin }',
        fragment: _fragmentRefraction)));
    expect(m.refractionMode, RefractionMode.screenSpace);
    expect(m.refractionType, RefractionType.thin);
    m.dispose();
  });

  test('requires tangents, uv0 and color', () {
    final m = load(FilamentMatc.compile(surface('material { name : Rq, requires : [ tangents, uv0, color ] }')));
    expect(m.requiredAttributes, containsAll([VertexAttribute.tangents, VertexAttribute.uv0, VertexAttribute.color]));
    m.dispose();
  });

  test('custom parameters of several types, an array and a sampler', () {
    final m = load(FilamentMatc.compile(surface('''
material {
    name : Params,
    parameters : [
        { type : float, name : amount },
        { type : float3, name : tintColor },
        { type : float4, name : baseColorFactor },
        { type : int, name : steps },
        { type : bool, name : useTint },
        { type : mat3, name : uvTransform },
        { type : float[4], name : weights },
        { type : sampler2d, name : albedo }
    ],
    requires : [ uv0 ]
}''', fragment: _fragmentParams)));
    final params = {for (final p in m.parameters) p.name: p};
    expect(params['amount']!.uniformType, UniformType.floatType);
    expect(params['tintColor']!.uniformType, UniformType.float3);
    expect(params['baseColorFactor']!.uniformType, UniformType.float4);
    expect(params['steps']!.uniformType, UniformType.intType);
    expect(params['useTint']!.uniformType, UniformType.boolType);
    expect(params['uvTransform']!.uniformType, UniformType.mat3);
    expect(params['weights']!.uniformType, UniformType.floatType);
    expect(params['weights']!.count, 4);
    expect(params['albedo']!.isSampler, isTrue);
    expect(params['albedo']!.samplerType, TextureSamplerType.sampler2d);
    m.dispose();
  });

  test('raster state and specular anti-aliasing header keys reach the material', () {
    final m = load(FilamentMatc.compile(surface('''
material {
    name : Raster,
    blending : masked,
    maskThreshold : 0.3,
    culling : front,
    colorWrite : false,
    depthWrite : false,
    depthCulling : false,
    doubleSided : true,
    specularAntiAliasing : true
}''')));
    expect(m.blendingMode, BlendingMode.masked);
    expect(m.maskThreshold, closeTo(0.3, 1e-6));
    expect(m.isColorWriteEnabled, isFalse);
    expect(m.isDepthWriteEnabled, isFalse);
    expect(m.isDepthCullingEnabled, isFalse);
    expect(m.isDoubleSided, isTrue);
    expect(m.hasSpecularAntiAliasing, isTrue);
    m.dispose();
  });

  test('a header syntax error reports matc\'s message with its line', () {
    const source = 'material {\n    name : Broken,\n    shadingModel lit\n}\nfragment {\n$_fragmentBasic\n}\n';
    final result = FilamentMatc.compile(source);
    expect(result.ok, isFalse);
    expect(result.package, isNull);
    expect(result.errorText, contains('line:3'));
    expect(result.diagnostics.any((d) => d.severity == MatcSeverity.error && d.line == 3), isTrue,
        reason: result.log);
  });

  test('a GLSL error in the fragment is reported at its .mat line', () {
    final source = surface('material { name : Glsl }', fragment: '''
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = notDeclaredAnywhere;
    }''');
    final line = source.split('\n').indexWhere((l) => l.contains('notDeclaredAnywhere')) + 1;
    final result = FilamentMatc.compile(source);
    expect(result.ok, isFalse);
    expect(result.errorText, contains('notDeclaredAnywhere'));
    expect(result.diagnostics.where((d) => d.severity == MatcSeverity.error).map((d) => d.line), contains(line),
        reason: result.log);
  });

  test('an unknown header key compiles with matc\'s warning', () {
    final result = FilamentMatc.compile(surface('material { name : Unknown, notAMaterialKey : true }'));
    expect(result.ok, isTrue, reason: result.log);
    expect(
        result.diagnostics.any((d) =>
            d.severity == MatcSeverity.warning && d.message.contains('Ignoring config entry (unknown key): "notAMaterialKey"')),
        isTrue,
        reason: result.log);
  });

  test('defaultName names a material whose header has none; the header name wins', () {
    final unnamed = load(FilamentMatc.compile(surface('material { shadingModel : lit }'), defaultName: 'FromAsset'));
    expect(unnamed.name, 'FromAsset');
    unnamed.dispose();
    final named = load(FilamentMatc.compile(surface('material { name : FromHeader }'), defaultName: 'FromAsset'));
    expect(named.name, 'FromHeader');
    named.dispose();
  });

  test('#include resolves from includeDirectory, and fails without it', () {
    final dir = Directory.systemTemp.createTempSync('matc_include_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/common.glsl').writeAsStringSync('float lumaOf(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }\n');
    final source = surface('material { name : Inc }', fragment: '''
    #include "common.glsl"
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = vec4(vec3(lumaOf(vec3(0.2, 0.4, 0.6))), 1.0);
    }''');
    final included = FilamentMatc.compile(source, includeDirectory: dir.path, fileName: 'Inc.mat');
    load(included).dispose();
    final missing = FilamentMatc.compile(source);
    expect(missing.ok, isFalse);
    expect(missing.errorText, contains('common.glsl'));
  });

  test("an invalid header value is one error with matc's list of valid values, printed once", () {
    final result = FilamentMatc.compile(surface('material { name : Bogus, blending : bogus }'));
    expect(result.ok, isFalse);
    final errors = result.diagnostics.where((d) => d.severity == MatcSeverity.error).toList();
    expect(errors, hasLength(1), reason: result.log);
    expect(errors.single.message, contains("Value 'bogus' is invalid. Valid values are:"));
    expect(errors.single.message, contains('multiply'));
    expect(RegExp('is invalid').allMatches(result.log), hasLength(1));
  });

  test('matc diagnostics parse line numbers from its message formats', () {
    final parsed = MatcDiagnostic.parseLog(
      'Ignoring config entry (unknown key): "foo"\n'
      'ERROR: 0:12: \'x\' : undeclared identifier\n'
      'WARNING: 0:7: something odd\n'
      'Unknown identifier \'fragmen\' at line:9 position:1\n'
      'JsonishParser error\n'
      'Syntax error, unable to parse pair at line:3 position:18\n'
      '  got lexeme type: STRING\n',
      failed: true,
    );
    expect(parsed.map((d) => (d.severity, d.line)), [
      (MatcSeverity.warning, null),
      (MatcSeverity.error, 12),
      (MatcSeverity.warning, 7),
      (MatcSeverity.error, 9),
      (MatcSeverity.error, 3),
    ]);
    expect(parsed.last.message.split('\n'), hasLength(3));
  });
}

const _fragmentBasic = '''
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = vec4(0.8, 0.3, 0.2, 0.7);
    }''';

const _fragmentUnlit = '''
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = vec4(0.8, 0.3, 0.2, 1.0);
    }''';

const _fragmentRefraction = '''
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = vec4(0.9, 0.9, 1.0, 1.0);
        material.transmission = 1.0;
        material.thickness = 0.1;
    }''';

const _fragmentParams = '''
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        vec3 c = materialParams.useTint ? materialParams.tintColor : materialParams.baseColorFactor.rgb;
        vec2 uv = (materialParams.uvTransform * vec3(getUV0(), 1.0)).xy;
        float w = materialParams.weights[0] + float(materialParams.steps) * materialParams.amount;
        material.baseColor = vec4(c * texture(materialParams_albedo, uv).rgb * w, 1.0);
    }''';
