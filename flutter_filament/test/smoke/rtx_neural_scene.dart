import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';

import 'smoke_helper.dart';

/// Four `test-assets/` props side by side on a lit floor, and an orbit around them.
class GuideScene {
  GuideScene._(
    this.rig,
    this.props,
    this.floor,
    this.floorInstance,
    this.floorQuad,
  );

  final SmokeRig rig;
  final List<LoadedGltf> props;
  final FilamentMaterial floor;
  final FilamentMaterialInstance floorInstance;
  final SmokeQuad floorQuad;

  static GuideScene build(SmokeRig r) {
    final props = [
      loadGltfIntoScene(
        r,
        'Props/AC_units/ac_unit_a_300x300.glb',
        frameCamera: false,
      ),
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
      loadGltfIntoScene(
        r,
        'Props/AC_units/aircon_small.glb',
        frameCamera: false,
      ),
    ];
    final tm = FilamentTransformManager(r.engine);
    var x = -2.4;
    for (final p in props) {
      final box = p.asset.getBoundingBox();
      final size = math.max(
        box.max.x - box.min.x,
        math.max(box.max.y - box.min.y, box.max.z - box.min.z),
      );
      final scale = 1.3 / size;
      tm.setTransform(p.asset.rootEntity, [
        scale, 0, 0, 0, //
        0, scale, 0, 0,
        0, 0, scale, 0,
        x - box.center.x * scale, -box.min.y * scale, -box.center.z * scale, 1,
      ]);
      x += 1.6;
    }
    final floor = buildLitMaterial(r.engine);
    final floorInstance = floor.createInstance()
      ..setFloat3('baseColor', 0.6, 0.6, 0.62);
    final floorQuad = SmokeQuad.create(r.engine, size: 12, tangents: true);
    final floorEntity = addQuadRenderable(
      r,
      floorQuad,
      floorInstance,
      extent: 12,
    );
    // the quad faces +Z; turned -90 degrees about X it faces +Y
    tm.setTransform(floorEntity, [
      1,
      0,
      0,
      0,
      0,
      0,
      -1,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      1,
    ]);
    r.camera.setProjection(
      fovDegrees: 45,
      aspect: r.width / r.height,
      near: 0.05,
      far: 100,
    );
    return GuideScene._(r, props, floor, floorInstance, floorQuad);
  }

  void orbit(double t) {
    final angle = -0.5 + t;
    rig.camera.lookAt(
      eyeX: 5.5 * math.sin(angle),
      eyeY: 2.2,
      eyeZ: 5.5 * math.cos(angle),
      centerX: 0,
      centerY: 0.4,
      centerZ: 0,
    );
  }

  void dispose() {
    rig.releaseEntities();
    floorInstance.dispose();
    floor.dispose();
    floorQuad.dispose();
    for (final p in props) {
      p.dispose(rig.scene);
    }
  }
}

/// The views the guide buffer smoke shows: the colour, or one guide mapped to colours.
enum GuideView {
  colour,
  normal,
  roughness,
  diffuseAlbedo,
  specularAlbedo,
  specularHitDistance;

  GuideBuffer? get guide => switch (this) {
    GuideView.colour => null,
    GuideView.normal || GuideView.roughness => GuideBuffer.normalRoughness,
    GuideView.diffuseAlbedo => GuideBuffer.diffuseAlbedo,
    GuideView.specularAlbedo => GuideBuffer.specularAlbedo,
    GuideView.specularHitDistance => GuideBuffer.specularHitDistance,
  };

  Future<Uint8List> render(
    SmokeRig r,
    Map<GuideBuffer, GuideBufferReadback> readbacks,
    Uint8List colour,
  ) async {
    final which = guide;
    if (which == null) return colour;
    final rb = readbacks[which]!;
    final data = await rb.read(r.renderer);
    final out = Uint8List(r.width * r.height * 4);
    for (var y = 0; y < r.height; y++) {
      for (var x = 0; x < r.width; x++) {
        final v = rb.at(data, x, y);
        final (cr, cg, cb) = _colour(v);
        final o = (y * r.width + x) * 4;
        out[o] = (cr.clamp(0.0, 1.0) * 255).round();
        out[o + 1] = (cg.clamp(0.0, 1.0) * 255).round();
        out[o + 2] = (cb.clamp(0.0, 1.0) * 255).round();
        out[o + 3] = 255;
      }
    }
    return out;
  }

  (double, double, double) _colour(List<double> v) {
    switch (this) {
      case GuideView.normal:
        if (v[0] == 0 && v[1] == 0 && v[2] == 0) return (0, 0, 0);
        return (v[0] * 0.5 + 0.5, v[1] * 0.5 + 0.5, v[2] * 0.5 + 0.5);
      case GuideView.roughness:
        return (v[3], v[3], v[3]);
      case GuideView.diffuseAlbedo:
        return (v[0], v[1], v[2]);
      case GuideView.specularAlbedo:
        return (v[0] * 4, v[1] * 4, v[2] * 4);
      case GuideView.specularHitDistance:
        // white near, dark at 10 m; blue where the mirror ray leaves the scene; black: no surface
        final d = v[0];
        if (d <= 0) return (0, 0, 0);
        if (d >= 65000) return (0.1, 0.2, 0.6);
        final g = 1 - (d / 10).clamp(0.0, 0.9);
        return (g, g, g);
      case GuideView.colour:
        return (0, 0, 0);
    }
  }
}
