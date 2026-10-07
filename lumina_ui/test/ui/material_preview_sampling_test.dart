import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_preview_renderer.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart' show PreviewShape;

/// Regression coverage: the preview treats a colour texture as
/// sRGB (as gltfio and the thumbnail renderer do), filters and repeats it, and
/// does not decode it again for every parameter change.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory project;
  setUp(() {
    project = Directory.systemTemp.createTempSync('material_preview_sampling_');
    Directory('${project.path}/contents/textures').createSync(recursive: true);
  });
  tearDown(() {
    if (project.existsSync()) project.deleteSync(recursive: true);
  });

  String greyTexture(int value) {
    final pixels = Uint8List(16 * 16 * 4);
    for (var i = 0; i < pixels.length; i += 4) {
      pixels[i] = value;
      pixels[i + 1] = value;
      pixels[i + 2] = value;
      pixels[i + 3] = 255;
    }
    final file = File('${project.path}/contents/textures/T_Grey.lmas')
      ..writeAsBytesSync(LuminaAsset(
        assetId: 'T_Grey',
        name: 'T_Grey',
        type: AssetType.texture,
        rawPayload: TgaDecoderService.encodePng(pixels, 16, 16),
      ).toProtoBufferBytes());
    return file.path;
  }

  Future<Uint8List> compileUnlit(String baseColor) async {
    final source = '''material {
    name : "M_Sampling",
    shadingModel : unlit,
    requires : [ uv0 ],
    parameters : [ { type : sampler2d, name : baseColorMap } ]
}
fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = $baseColor;
    }
}''';
    final vm = MaterialEditorViewModel(
      assetPath: '${project.path}/contents/materials/M_Sampling.lmas',
      initialAsset: LuminaAsset(assetId: 'M', name: 'M_Sampling', type: AssetType.filamat, rawMatSource: source),
    );
    expect(await vm.compile(), isTrue, reason: vm.issues.map((i) => i.message).join('\n'));
    return vm.compiledBytes!;
  }

  /// Mean RGB of the centre of a plane shaded with [bytes], seen from above.
  Future<double> renderCentre(Uint8List bytes, List<MaterialParamModel> params) async {
    final engine = FilamentEngine.create(backend: FilamentBackend.defaultBackend)!;
    final scene = engine.createScene();
    final view = engine.createView();
    final camera = engine.createCamera(engine.createEntity());
    final renderer = engine.createRenderer();
    const w = 128, h = 128;
    final swapChain = engine.createHeadlessSwapChain(w, h);
    view
      ..scene = scene
      ..camera = camera;
    view.setViewport(0, 0, w, h);
    camera.setProjection(fovDegrees: 45, aspect: 1, near: 0.1, far: 100);
    camera.lookAt(eyeX: 0, eyeY: 3, eyeZ: 0, centerX: 0, centerY: 0, centerZ: 0, upX: 0, upY: 0, upZ: -1);

    final preview = MaterialPreviewRenderer();
    expect(preview.mount(engine: engine, scene: scene, filamatBytes: bytes, shape: PreviewShape.plane, parameters: params),
        isTrue, reason: preview.lastError);

    final pixels = calloc<ffi.Uint8>(w * h * 4);
    var rendered = 0;
    for (var attempt = 0; attempt < 40 && rendered < 4; attempt++) {
      sleep(const Duration(milliseconds: 16));
      if (renderer.beginFrame(swapChain)) {
        rendered++;
        renderer.render(view);
        if (rendered == 4) {
          c.filament_renderer_read_pixels(
              renderer.nativePointer, engine.nativePointer, 0, 0, w, h, pixels.cast(), ffi.nullptr, ffi.nullptr);
        }
        renderer.endFrame();
        engine.flushAndWait();
      }
    }
    final frame = Uint8List.fromList(pixels.asTypedList(w * h * 4));
    calloc.free(pixels);
    var sum = 0.0, n = 0;
    for (var y = h ~/ 2 - 8; y < h ~/ 2 + 8; y++) {
      for (var x = w ~/ 2 - 8; x < w ~/ 2 + 8; x++) {
        final i = (y * w + x) * 4;
        sum += (frame[i] + frame[i + 1] + frame[i + 2]) / 3;
        n++;
      }
    }
    preview.dispose();
    swapChain.dispose();
    renderer.dispose();
    view.dispose();
    scene.dispose();
    engine.dispose();
    return sum / n;
  }

  MaterialParamModel sampler(String name, String? path) => MaterialParamModel(
        name: name,
        type: MaterialParamType.sampler2dType,
        isSampler: true,
      )..resolvedTexturePath = path;

  test('a colour texture shades like a constant of its linear value (it is sRGB)', () async {
    const srgb = 64;
    final linear = math.pow((srgb / 255 + 0.055) / 1.055, 2.4).toDouble();
    final path = greyTexture(srgb);

    final textured = await renderCentre(
      await compileUnlit('texture(materialParams_baseColorMap, getUV0())'),
      [sampler('baseColorMap', path)],
    );
    final constant = await renderCentre(
      await compileUnlit('vec4(vec3(${linear.toStringAsFixed(6)}), 1.0)'),
      [sampler('baseColorMap', null)],
    );
    expect(constant, greaterThan(5), reason: 'the plane is in view');
    expect((textured - constant).abs(), lessThan(8),
        reason: 'sRGB $srgb is linear ${linear.toStringAsFixed(3)}: textured $textured vs constant $constant');
  });

  test('colour samplers are sRGB, data samplers linear; sampling is filtered and repeats', () {
    expect(MaterialPreviewRenderer.isColorSampler('baseColorMap'), isTrue);
    expect(MaterialPreviewRenderer.isColorSampler('albedo'), isTrue);
    expect(MaterialPreviewRenderer.isColorSampler('emissiveMap'), isTrue);
    expect(MaterialPreviewRenderer.isColorSampler('normalMap'), isFalse);
    expect(MaterialPreviewRenderer.isColorSampler('metallicRoughnessMap'), isFalse);
    expect(MaterialPreviewRenderer.isColorSampler('specularMap'), isFalse);
    const s = MaterialPreviewRenderer.textureSampler;
    expect((s.filterMin, s.filterMag, s.wrapS, s.wrapT),
        (SamplerMinFilter.linear, SamplerMagFilter.linear, SamplerWrapMode.repeat, SamplerWrapMode.repeat));
  });

  test('a parameter change rebinds only the textures whose file changed', () async {
    final bytes = await compileUnlit('texture(materialParams_baseColorMap, getUV0())');
    final engine = FilamentEngine.create(backend: FilamentBackend.defaultBackend)!;
    final scene = engine.createScene();
    final preview = MaterialPreviewRenderer();
    final first = greyTexture(200);
    final params = [sampler('baseColorMap', first)];
    expect(preview.mount(engine: engine, scene: scene, filamatBytes: bytes, shape: PreviewShape.sphere, parameters: params),
        isTrue);
    expect(preview.boundFormat('baseColorMap'), TextureFormat.srgb8A8);

    final decoded = MaterialPreviewRenderer.decodeCount;
    preview.applyParameters(params);
    preview.applyParameters(params);
    expect(MaterialPreviewRenderer.decodeCount, decoded, reason: 'same file, nothing to decode');

    final second = File(first).copySync('${project.path}/contents/textures/T_Other.lmas').path;
    preview.applyParameters([sampler('baseColorMap', second)]);
    expect(MaterialPreviewRenderer.decodeCount, decoded + 1, reason: 'a reassigned texture is decoded and bound');

    preview.dispose();
    scene.dispose();
    engine.dispose();
  });
}
