import 'dart:io' show sleep;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

import '../smoke/smoke_helper.dart';

/// Guide buffers: normal + roughness, diffuse and specular albedo written by
/// the lit shaders in the colour pass, and the specular hit distance traced
/// with ray queries (Vulkan).
void main() {
  test('options default off and round-trip; the noop backend accepts them', () {
    expect(const GuideBufferOptions().enabled, isFalse);
    expect(const GuideBufferOptions().specularHitDistance, isTrue);
    final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    final view = engine.createView();
    try {
      view.guideBufferOptions = const GuideBufferOptions(
        enabled: true,
        specularHitDistance: false,
      );
      expect(
        view.guideBufferOptions,
        const GuideBufferOptions(enabled: true, specularHitDistance: false),
      );
      final renderer = engine.createRenderer();
      final swapChain = engine.createHeadlessSwapChain(32, 32);
      if (renderer.beginFrame(swapChain)) {
        renderer.render(view);
        renderer.endFrame();
      }
      swapChain.dispose();
      renderer.dispose();
    } finally {
      view.dispose();
      engine.dispose();
    }
  });

  group('guide buffers on Vulkan', () {
    const size = 256;
    SmokeRig? rig;
    final materials = <FilamentMaterial>[];
    final instances = <FilamentMaterialInstance>[];
    final quads = <SmokeQuad>[];
    final readbacks = <GuideBufferReadback>[];

    setUp(() {
      RayTracing.requestExtensions();
      FilamentEngine? engine;
      try {
        engine = FilamentEngine.create(backend: FilamentBackend.vulkan);
      } catch (_) {
        engine = null;
      }
      if (engine == null) return;
      rig = SmokeRig.adopt(engine, width: size, height: size);
      rig!.addSun();
    });

    tearDown(() {
      for (final r in readbacks) {
        r.dispose();
      }
      readbacks.clear();
      if (rig != null) {
        for (final e in rig!.entities) {
          rig!.engine.destroyEntity(e);
        }
        rig!.entities.clear();
      }
      for (final mi in instances) {
        mi.dispose();
      }
      instances.clear();
      for (final m in materials) {
        m.dispose();
      }
      materials.clear();
      for (final q in quads) {
        q.dispose();
      }
      quads.clear();
      rig?.dispose();
      rig = null;
      RayTracing.clearExtensionRequest();
    });

    bool skipWithoutVulkan() {
      if (rig == null) {
        markTestSkipped('needs a Vulkan device');
        return true;
      }
      return false;
    }

    /// A lit material with baseColor / metallic / roughness parameters, opaque
    /// or blended.
    FilamentMaterial pbrMaterial(
      FilamentEngine engine, {
      bool transparent = false,
    }) {
      FilamentMaterialBuilder.initEngine();
      final b = FilamentMaterialBuilder.create();
      b.setName(transparent ? 'GuideTestTransparent' : 'GuideTestPbr');
      b.setShading(FilamatShading.lit);
      b.setDoubleSided(true);
      if (transparent) b.blending(BlendingMode.transparent);
      b.requireAttribute(VertexAttribute.position.value);
      b.requireAttribute(VertexAttribute.tangents.value);
      b.addParameter('baseColor', UniformType.float3);
      b.addParameter('metallic', UniformType.floatType);
      b.addParameter('roughness', UniformType.floatType);
      b.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor = vec4(materialParams.baseColor, ${transparent ? '0.5' : '1.0'});
            ${transparent ? 'material.baseColor.rgb *= material.baseColor.a;' : ''}
            material.metallic = materialParams.metallic;
            material.roughness = materialParams.roughness;
        }
      ''');
      final bytes = b.build();
      b.dispose();
      if (bytes == null) throw StateError('filamat build failed');
      final m = FilamentMaterial.fromBuffer(
        engine: engine,
        filamatBuffer: bytes,
      );
      materials.add(m);
      return m;
    }

    /// A quad of [sizeUnits] facing +Z, placed by [transform] (column-major).
    int addQuad(
      SmokeRig r,
      FilamentMaterial material, {
      required (double, double, double) color,
      double metallic = 0,
      double roughness = 0.5,
      double sizeUnits = 4,
      List<double> transform = const [
        1,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        1,
      ],
    }) {
      final quad = SmokeQuad.create(r.engine, size: sizeUnits, tangents: true);
      quads.add(quad);
      final mi = material.createInstance()
        ..setFloat3('baseColor', color.$1, color.$2, color.$3)
        ..setFloat('metallic', metallic)
        ..setFloat('roughness', roughness);
      instances.add(mi);
      final e = addQuadRenderable(r, quad, mi, extent: sizeUnits);
      FilamentTransformManager(r.engine).setTransform(e, transform);
      return e;
    }

    GuideBufferReadback attach(SmokeRig r, GuideBuffer which) {
      final rb = GuideBufferReadback.attach(
        engine: r.engine,
        view: r.view,
        which: which,
        width: size,
        height: size,
      );
      readbacks.add(rb);
      return rb;
    }

    Future<Map<GuideBuffer, List<double>>> centreGuides(
      SmokeRig r,
      List<GuideBufferReadback> rbs,
    ) async {
      final out = <GuideBuffer, List<double>>{};
      for (final rb in rbs) {
        final data = await rb.read(r.renderer);
        out[rb.which] = rb.at(data, size ~/ 2, size ~/ 2);
      }
      return out;
    }

    test(
      'a dielectric plane facing the camera: normal, roughness and albedos',
      () async {
        if (skipWithoutVulkan()) return;
        final r = rig!;
        r.camera.lookAt(
          eyeX: 0,
          eyeY: 0,
          eyeZ: 3,
          centerX: 0,
          centerY: 0,
          centerZ: 0,
        );
        addQuad(
          r,
          pbrMaterial(r.engine),
          color: (0.8, 0.2, 0.1),
          metallic: 0,
          roughness: 0.5,
        );
        r.view.guideBufferOptions = const GuideBufferOptions(
          enabled: true,
          specularHitDistance: false,
        );
        final rbs = [
          for (final g in [
            GuideBuffer.normalRoughness,
            GuideBuffer.diffuseAlbedo,
            GuideBuffer.specularAlbedo,
          ])
            attach(r, g),
        ];
        r.renderFrame(warmup: 2);
        final g = await centreGuides(r, rbs);
        smokeLog('dielectric guides: $g');
        final n = g[GuideBuffer.normalRoughness]!;
        expect(n[0], closeTo(0, 0.02));
        expect(n[1], closeTo(0, 0.02));
        expect(n[2], closeTo(1, 0.02));
        expect(n[3], closeTo(0.5, 0.01));
        final d = g[GuideBuffer.diffuseAlbedo]!;
        expect(d[0], closeTo(0.8, 2 / 255));
        expect(d[1], closeTo(0.2, 2 / 255));
        expect(d[2], closeTo(0.1, 2 / 255));
        final s = g[GuideBuffer.specularAlbedo]!;
        // F0 = 0.04 (reflectance 0.5) at normal incidence: a grey split-sum albedo
        expect(s[0], inInclusiveRange(0.02, 0.1));
        expect(s[0], closeTo(s[1], 2 / 255));
        expect(s[1], closeTo(s[2], 2 / 255));
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'a metal has no diffuse albedo and a tinted specular albedo',
      () async {
        if (skipWithoutVulkan()) return;
        final r = rig!;
        r.camera.lookAt(
          eyeX: 0,
          eyeY: 0,
          eyeZ: 3,
          centerX: 0,
          centerY: 0,
          centerZ: 0,
        );
        addQuad(
          r,
          pbrMaterial(r.engine),
          color: (0.9, 0.6, 0.2),
          metallic: 1,
          roughness: 0.3,
        );
        r.view.guideBufferOptions = const GuideBufferOptions(
          enabled: true,
          specularHitDistance: false,
        );
        final rbs = [
          attach(r, GuideBuffer.diffuseAlbedo),
          attach(r, GuideBuffer.specularAlbedo),
        ];
        r.renderFrame(warmup: 2);
        final g = await centreGuides(r, rbs);
        smokeLog('metal guides: $g');
        final d = g[GuideBuffer.diffuseAlbedo]!;
        expect(d[0] + d[1] + d[2], lessThan(3 / 255));
        final s = g[GuideBuffer.specularAlbedo]!;
        expect(s[0], greaterThan(s[1]));
        expect(s[1], greaterThan(s[2]));
        expect(s[0], greaterThan(0.6));
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'a transparent quad in front leaves the opaque guides in place',
      () async {
        if (skipWithoutVulkan()) return;
        final r = rig!;
        r.camera.lookAt(
          eyeX: 0,
          eyeY: 0,
          eyeZ: 3,
          centerX: 0,
          centerY: 0,
          centerZ: 0,
        );
        addQuad(r, pbrMaterial(r.engine), color: (0.8, 0.2, 0.1));
        addQuad(
          r,
          pbrMaterial(r.engine, transparent: true),
          color: (0.1, 0.9, 0.1),
          sizeUnits: 1,
          transform: [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1],
        );
        r.view.guideBufferOptions = const GuideBufferOptions(
          enabled: true,
          specularHitDistance: false,
        );
        final rbs = [
          attach(r, GuideBuffer.normalRoughness),
          attach(r, GuideBuffer.diffuseAlbedo),
        ];
        final frame = r.renderFrame(warmup: 2);
        final (cr, cg, _) = pixelAt(frame, size, size ~/ 2, size ~/ 2);
        expect(
          cg,
          greaterThan(cr),
          reason: 'the green transparent quad is visible in the colour',
        );
        final g = await centreGuides(r, rbs);
        expect(g[GuideBuffer.normalRoughness]![2], closeTo(1, 0.02));
        expect(g[GuideBuffer.diffuseAlbedo]![0], closeTo(0.8, 2 / 255));
        expect(g[GuideBuffer.diffuseAlbedo]![1], closeTo(0.2, 2 / 255));
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'the specular hit distance of a floor facing a wall matches the mirror path',
      () async {
        if (skipWithoutVulkan()) return;
        final r = rig!;
        if (!r.engine.supportsRayQuery) {
          markTestSkipped('this GPU or driver has no Vulkan ray query support');
          return;
        }
        // floor: the quad turned to face +Y (rotation of -90 degrees about X), 20 units wide
        addQuad(
          r,
          pbrMaterial(r.engine),
          color: (0.5, 0.5, 0.5),
          sizeUnits: 20,
          transform: [1, 0, 0, 0, 0, 0, -1, 0, 0, 1, 0, 0, 0, 0, 0, 1],
        );
        // wall: facing +Z at z = -3, 20 units wide, centred 5 units up
        addQuad(
          r,
          pbrMaterial(r.engine),
          color: (0.5, 0.5, 0.5),
          sizeUnits: 20,
          transform: [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 5, -3, 1],
        );
        // the camera looks at the floor point (0, 0, 1) from (0, 2, 3): 45 degrees down
        r.camera.lookAt(
          eyeX: 0,
          eyeY: 2,
          eyeZ: 3,
          centerX: 0,
          centerY: 0,
          centerZ: 1,
        );
        r.scene.rayTracingEnabled = true;
        r.view.guideBufferOptions = const GuideBufferOptions(enabled: true);
        final rb = attach(r, GuideBuffer.specularHitDistance);
        r.renderFrame(warmup: 2);
        final data = await rb.read(r.renderer);
        final centre = rb.at(data, size ~/ 2, size ~/ 2)[0];
        // mirror direction (0, 1, -1)/sqrt(2) from (0, 0, 1) reaches z = -3 after 4 * sqrt(2)
        final expected = 4 * math.sqrt2;
        smokeLog(
          'specular hit distance at the centre: ${centre.toStringAsFixed(3)} (analytic ${expected.toStringAsFixed(3)})',
        );
        expect(centre, closeTo(expected, expected * 0.05));
        // the top row looks above the wall's top edge? no: the wall fills the view's top; a sky
        // pixel only appears without geometry, so check a pixel of the floor near the bottom
        final near = rb.at(data, size ~/ 2, size - 4)[0];
        expect(
          near,
          greaterThan(0),
          reason: 'floor pixels have a hit distance',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test('sky pixels have no guides', () async {
      if (skipWithoutVulkan()) return;
      final r = rig!;
      r.camera.lookAt(
        eyeX: 0,
        eyeY: 0,
        eyeZ: 3,
        centerX: 0,
        centerY: 0,
        centerZ: 0,
      );
      addQuad(r, pbrMaterial(r.engine), color: (0.8, 0.2, 0.1), sizeUnits: 0.5);
      r.scene.rayTracingEnabled = true;
      r.view.guideBufferOptions = const GuideBufferOptions(enabled: true);
      final rbs = [
        attach(r, GuideBuffer.normalRoughness),
        attach(r, GuideBuffer.specularHitDistance),
      ];
      r.renderFrame(warmup: 2);
      final normals = await rbs[0].read(r.renderer);
      final hits = await rbs[1].read(r.renderer);
      expect(rbs[0].at(normals, 4, 4), [0.0, 0.0, 0.0, 0.0]);
      expect(rbs[1].at(hits, 4, 4)[0], 0.0);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('guides off: the colour output is unchanged', () async {
      if (skipWithoutVulkan()) return;
      final r = rig!;
      r.camera.lookAt(
        eyeX: 0,
        eyeY: 0,
        eyeZ: 3,
        centerX: 0,
        centerY: 0,
        centerZ: 0,
      );
      addQuad(r, pbrMaterial(r.engine), color: (0.8, 0.2, 0.1));
      final off = r.renderFrame(warmup: 3);
      r.view.guideBufferOptions = const GuideBufferOptions(
        enabled: true,
        specularHitDistance: false,
      );
      final on = r.renderFrame(warmup: 3);
      var maxDiff = 0;
      for (var i = 0; i < off.length; i++) {
        maxDiff = math.max(maxDiff, (off[i] - on[i]).abs());
      }
      expect(
        maxDiff,
        lessThanOrEqualTo(2),
        reason: 'writing guides must not change the shaded colour',
      );
      expect(Uint8List.fromList(off).length, size * size * 4);
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  test('guide buffer cost at 1920x1080 is measured', () {
    RayTracing.requestExtensions();
    FilamentEngine? engine;
    try {
      engine = FilamentEngine.create(backend: FilamentBackend.vulkan);
    } catch (_) {
      engine = null;
    }
    if (engine == null) {
      RayTracing.clearExtensionRequest();
      markTestSkipped('needs a Vulkan device');
      return;
    }
    final r = SmokeRig.adopt(engine, width: 1920, height: 1080);
    r.addSun();
    final props = [
      loadGltfIntoScene(r, 'Props/AC_units/ac_unit_a_300x300.glb'),
      loadGltfIntoScene(
        r,
        'Props/Banana Bunch/banana_bunch_medium.glb',
        frameCamera: false,
      ),
      loadGltfIntoScene(
        r,
        'Props/Access_cards/access_card_blue.glb',
        frameCamera: false,
      ),
    ];
    try {
      r.scene.rayTracingEnabled = engine.supportsRayQuery;
      // Each frame is rendered and waited for (flushAndWait), so CPU and GPU work add up and
      // the difference between two settings bounds the GPU cost of what changed. Filament's
      // per-frame GPU timer on Vulkan covers only the first command buffer of a frame.
      double medianGpuMs() {
        r.renderFrame(warmup: 10);
        final times = <double>[];
        var attempts = 0;
        while (times.length < 60 && attempts++ < 2000) {
          final sw = Stopwatch()..start();
          if (!r.renderer.beginFrame(r.swapChain)) {
            sleep(const Duration(milliseconds: 4));
            continue;
          }
          r.renderer.render(r.view);
          r.renderer.endFrame();
          r.engine.flushAndWait();
          times.add(sw.elapsedMicroseconds / 1000.0);
        }
        expect(times.length, 60, reason: 'the renderer accepted the frames');
        times.sort();
        return times[times.length ~/ 2];
      }

      final off = medianGpuMs();
      // The frame graph culls guides nobody reads: export every guide, as a consumer would.
      final readbacks = [
        for (final g in GuideBuffer.values)
          GuideBufferReadback.attach(
            engine: engine,
            view: r.view,
            which: g,
            width: 1920,
            height: 1080,
          ),
      ];
      r.view.guideBufferOptions = const GuideBufferOptions(
        enabled: true,
        specularHitDistance: false,
      );
      final guides = medianGpuMs();
      r.view.guideBufferOptions = const GuideBufferOptions(enabled: true);
      final withHits = medianGpuMs();
      for (final rb in readbacks) {
        rb.dispose();
      }
      smokeLog(
        'rendered + waited frame at 1920x1080: guides off ${off.toStringAsFixed(3)} ms, '
        'guides ${guides.toStringAsFixed(3)} ms (+${(guides - off).toStringAsFixed(3)}), '
        'guides + hit distance ${withHits.toStringAsFixed(3)} ms (+${(withHits - off).toStringAsFixed(3)})',
      );
      expect(guides - off, lessThan(3.0));
    } finally {
      for (final p in props) {
        p.dispose(r.scene);
      }
      r.dispose();
      RayTracing.clearExtensionRequest();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
