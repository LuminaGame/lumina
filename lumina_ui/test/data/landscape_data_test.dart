import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/landscape_brush.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/landscape_asset_service.dart';

/// The pure data half: `LandscapeData` binary payload,
/// `LANDSCAPE` `.lmas` round-trip on real disk, heightmap PNG import, the
/// sculpt brush maths, the dirty-rect → mesh-section window mapping and the
/// foliage scatter rules. No GPU, no mocks: every file touched here is a real
/// file under `Directory.systemTemp`.
void main() {
  group('LandscapeData binary payload', () {
    test('129² heights + 2 foliage layers with 50 instances round-trip byte-exact', () {
      final data = LandscapeData.flat(gridResolution: 129, worldSize: 256.0, maxHeight: 100.0);
      final rnd = math.Random(7);
      for (var i = 0; i < data.vertexCount; i++) {
        data.setHeightAtIndex(i, rnd.nextDouble() * 100.0);
      }
      for (var l = 0; l < 2; l++) {
        final layer = FoliageLayer(
          meshAssetId: 'mesh_$l',
          meshAssetPath: 'contents/meshes/mesh_$l.lmas',
          name: 'Layer_$l',
          rules: FoliageRules(
            density: 30.0 + l,
            minSpacing: 1.5 + l,
            scaleMin: 0.75,
            scaleMax: 1.25,
            randomYaw: l == 0,
            alignToNormal: l == 1,
            slopeMinDegrees: 0.0,
            slopeMaxDegrees: 35.0 + l,
          ),
        );
        for (var i = 0; i < 50; i++) {
          layer.addInstance(FoliageInstance(
            x: rnd.nextDouble() * 10,
            y: rnd.nextDouble() * 10,
            z: rnd.nextDouble() * 10,
            scaleX: 1.0,
            scaleY: 1.1,
            scaleZ: 1.2,
            yaw: rnd.nextDouble(),
            nx: 0.0,
            ny: 1.0,
            nz: 0.0,
          ));
        }
        data.layers.add(layer);
      }

      final bytes = data.toBytes();
      final back = LandscapeData.fromBytes(bytes);

      expect(back.version, LandscapeData.formatVersion);
      expect(back.gridResolution, 129);
      expect(back.worldSize, 256.0);
      expect(back.maxHeight, 100.0);
      expect(back.samples, data.samples);
      expect(back.layers.length, 2);
      for (var l = 0; l < 2; l++) {
        expect(back.layers[l].meshAssetId, 'mesh_$l');
        expect(back.layers[l].meshAssetPath, 'contents/meshes/mesh_$l.lmas');
        expect(back.layers[l].name, 'Layer_$l');
        expect(back.layers[l].rules, data.layers[l].rules);
        expect(back.layers[l].instanceCount, 50);
        expect(back.layers[l].transforms, data.layers[l].transforms);
      }
      // Heights dominate the payload: raw little-endian uint16, not JSON.
      expect(bytes.length, greaterThan(129 * 129 * 2));
      expect(bytes.length, lessThan(129 * 129 * 2 + 50 * 2 * 10 * 4 + 1024));
      expect(back.toBytes(), bytes);
    });

    test('written as a real LANDSCAPE .lmas and re-read with payload + 2 foliage references', () async {
      final dir = Directory.systemTemp.createTempSync('lumina_landscape_lmas_');
      try {
        final data = LandscapeData.flat(gridResolution: 65, worldSize: 128.0, maxHeight: 50.0);
        data.setHeightAtIndex(100, 12.5);
        data.layers.add(FoliageLayer(
          meshAssetId: 'barrel',
          meshAssetPath: 'contents/meshes/barrel.lmas',
          name: 'Barrels',
        ));
        data.layers.add(FoliageLayer(
          meshAssetId: 'ac_unit',
          meshAssetPath: 'contents/meshes/ac_unit.lmas',
          name: 'AC Units',
        ));

        final path = '${dir.path}/contents/landscapes/Terrain_Main.lmas';
        await LandscapeAssetService.save(path: path, name: 'Terrain_Main', data: data);
        expect(File(path).existsSync(), isTrue);

        final asset = LuminaAsset.fromBytes(File(path).readAsBytesSync());
        expect(asset.type, AssetType.landscape);
        expect(asset.rawPayload, isNotNull);
        expect(asset.references.length, 2);
        expect(asset.references[0].slotName, 'foliage_0');
        expect(asset.references[0].assetId, 'barrel');
        expect(asset.references[1].slotName, 'foliage_1');
        expect(asset.metadata['grid_resolution'], '65');

        final reloaded = LandscapeAssetService.load(path);
        expect(reloaded, isNotNull);
        expect(reloaded!.gridResolution, 65);
        expect(reloaded.heightAtIndex(100), closeTo(12.5, reloaded.heightStep));
        expect(reloaded.layers.map((l) => l.meshAssetId).toList(), ['barrel', 'ac_unit']);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });

  group('LandscapeData v2 payload (uint16) and the 8129 ceiling', () {
    /// A v1 payload, byte-for-byte as the first format wrote it: float32
    /// heights, no storage flag. Hand-built because the encoder is gone — the
    /// point is that assets written before the bump still open.
    Uint8List writeV1(LandscapeData source) {
      final res = source.gridResolution;
      final out = Uint8List(4 + 4 + 4 + 4 + 4 + res * res * 4 + 4);
      final view = ByteData.view(out.buffer);
      out.setRange(0, 4, LandscapeData.magic);
      var o = 4;
      view.setUint32(o, LandscapeData.legacyFloatVersion, Endian.little);
      o += 4;
      view.setUint32(o, res, Endian.little);
      o += 4;
      view.setFloat32(o, source.worldSize, Endian.little);
      o += 4;
      view.setFloat32(o, source.maxHeight, Endian.little);
      o += 4;
      for (var i = 0; i < res * res; i++) {
        view.setFloat32(o, source.heightAtIndex(i), Endian.little);
        o += 4;
      }
      view.setUint32(o, 0, Endian.little); // no foliage layers
      return out;
    }

    test('a v2 payload round-trips at 1025² to the 16-bit step, and v1 float payloads still load', () {
      const res = 1025;
      final data = LandscapeData.flat(gridResolution: res, worldSize: 2048.0, maxHeight: 400.0);
      final rnd = math.Random(19);
      for (var i = 0; i < data.vertexCount; i++) {
        data.setHeightAtIndex(i, rnd.nextDouble() * 400.0);
      }

      final bytes = data.toBytes();
      // Two bytes per sample, not four.
      expect(bytes.length, greaterThan(res * res * 2));
      expect(bytes.length, lessThan(res * res * 2 + 256));

      final back = LandscapeData.fromBytes(bytes);
      expect(back.version, 2);
      expect(back.gridResolution, res);
      expect(back.samples, data.samples);
      for (var i = 0; i < data.vertexCount; i += 977) {
        expect(back.heightAtIndex(i), closeTo(data.heightAtIndex(i), data.heightStep));
      }

      final legacy = LandscapeData.fromBytes(writeV1(data));
      expect(legacy.version, LandscapeData.legacyFloatVersion);
      expect(legacy.gridResolution, res);
      expect(legacy.maxHeight, 400.0);
      for (var i = 0; i < data.vertexCount; i += 977) {
        expect(legacy.heightAtIndex(i), closeTo(data.heightAtIndex(i), data.heightStep));
      }
    });

    test('an 8129² terrain is created, sculpted, saved and reopened with the edit intact', () async {
      final dir = Directory.systemTemp.createTempSync('lumina_landscape_8129_');
      try {
        const res = LandscapeData.maxGridResolution;
        expect(res, 8129);

        final build = Stopwatch()..start();
        final data = LandscapeData.flat(gridResolution: res, worldSize: 16256.0, maxHeight: 1000.0);
        build.stop();
        expect(data.vertexCount, 66080641);
        expect(data.heightBytes, 132161282);

        // One sculpt stroke, at the centre.
        final sculpt = Stopwatch()..start();
        final rect = LandscapeBrush.stamp(
          data,
          const LandscapeBrushSettings(
            tool: LandscapeTool.sculpt,
            radius: 40.0,
            strength: 250.0,
            falloff: 0.5,
            falloffType: LandscapeFalloffType.smooth,
          ),
          0.0,
          0.0,
        );
        sculpt.stop();
        expect(rect, isNotNull);
        expect(rect!.cellCount, lessThan(data.vertexCount ~/ 1000),
            reason: 'a stroke must only touch its own dirty rect at this scale');
        final edited = data.sampleHeight(0.0, 0.0);
        expect(edited, greaterThan(200.0));

        final path = '${dir.path}/contents/landscapes/Huge.lmas';
        final save = Stopwatch()..start();
        await LandscapeAssetService.save(path: path, name: 'Huge', data: data);
        save.stop();

        final lmas = File(path);
        final sidecar = File(LandscapeData.sidecarPathFor(path));
        expect(lmas.existsSync(), isTrue);
        expect(sidecar.existsSync(), isTrue,
            reason: 'beyond the inline limit the heights stream into a sidecar');
        expect(sidecar.lengthSync(), 16 + data.heightBytes);
        expect(lmas.lengthSync(), lessThan(4096),
            reason: 'the .lmas itself stays tiny: it carries only the header and the foliage');

        final load = Stopwatch()..start();
        final reopened = LandscapeAssetService.load(path);
        load.stop();
        expect(reopened, isNotNull);
        expect(reopened!.gridResolution, res);
        expect(reopened.samplesAreExternal, isFalse);
        expect(reopened.sampleHeight(0.0, 0.0), closeTo(edited, data.heightStep));
        expect(reopened.heightMax, closeTo(data.heightMax, data.heightStep));

        // ignore: avoid_print
        print('[landscape 8129] samples=${data.vertexCount} heights=${data.heightBytes ~/ (1024 * 1024)} MB '
            'lmas=${lmas.lengthSync()} B sidecar=${sidecar.lengthSync() ~/ (1024 * 1024)} MB '
            'create=${build.elapsedMilliseconds} ms stroke=${sculpt.elapsedMilliseconds} ms '
            'save=${save.elapsedMilliseconds} ms reopen=${load.elapsedMilliseconds} ms '
            'strokeCells=${rect.cellCount}');
      } finally {
        dir.deleteSync(recursive: true);
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });

  group('Heightmap import', () {
    test('16-bit gradient PNG → heights rise across X, min 0, max == maxHeight', () async {
      final dir = Directory.systemTemp.createTempSync('lumina_landscape_png16_');
      try {
        const res = 65;
        final image = img.Image(width: res, height: res, numChannels: 1, format: img.Format.uint16);
        for (var y = 0; y < res; y++) {
          for (var x = 0; x < res; x++) {
            image.setPixelR(x, y, (x * 65535 / (res - 1)).round());
          }
        }
        final file = File('${dir.path}/gradient16.png')..writeAsBytesSync(img.encodePng(image));

        final data = LandscapeAssetService.importHeightmap(
          pngBytes: file.readAsBytesSync(),
          worldSize: 256.0,
          maxHeight: 200.0,
        );
        expect(data.gridResolution, res);
        expect(data.maxHeight, 200.0);
        for (var x = 1; x < res; x++) {
          expect(data.heightAt(x, 0), greaterThan(data.heightAt(x - 1, 0)));
        }
        expect(data.heightMin, closeTo(0.0, 1e-6));
        expect(data.heightMax, closeTo(200.0, 200.0 / 65535.0 + 1e-6));
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('8-bit grayscale PNG is accepted at a real terrain resolution', () {
      const res = 65;
      final image = img.Image(width: res, height: res, numChannels: 1);
      for (var y = 0; y < res; y++) {
        for (var x = 0; x < res; x++) {
          image.setPixelR(x, y, (y * 255 / (res - 1)).round());
        }
      }
      final data = LandscapeAssetService.importHeightmap(
        pngBytes: img.encodePng(image),
        worldSize: 64.0,
        maxHeight: 10.0,
      );
      expect(data.gridResolution, res);
      expect(data.heightAt(0, res - 1), closeTo(10.0, 10.0 / 255.0));
      expect(data.heightAt(0, 0), closeTo(0.0, data.heightStep));
    });

    test('a size that does not tile is rejected by name, with the nearest valid sizes', () {
      final odd = img.Image(width: 1000, height: 1000, numChannels: 1);
      expect(
        () => LandscapeAssetService.importHeightmap(
          pngBytes: img.encodePng(odd),
          worldSize: 100,
          maxHeight: 10,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message.toString(),
          'message',
          allOf(contains('1000'), contains('961'), contains('1025')),
        )),
      );
    });

    test('a size above the 8129 ceiling is rejected by the ceiling, not by the old 513 cap', () {
      expect(LandscapeData.maxGridResolution, 8129);
      expect(
        LandscapeData.describeInvalidResolution(8193),
        allOf(contains('8193'), contains('8129')),
      );
      // Every n*64+1 size in between is accepted.
      for (final n in [65, 129, 257, 513, 1025, 2049, 4097, 8129]) {
        expect(LandscapeData.isValidResolution(n), isTrue, reason: '$n must be a valid terrain size');
        expect(LandscapeData.describeInvalidResolution(n), isNull);
      }
      expect(LandscapeData.isValidResolution(512), isFalse);
      expect(LandscapeData.isValidResolution(8130), isFalse);
    });

    test('a 16-bit PNG keeps all 16 bits — adjacent single-step values stay distinct', () {
      const res = 65;
      final image = img.Image(width: res, height: res, numChannels: 1, format: img.Format.uint16);
      for (var y = 0; y < res; y++) {
        for (var x = 0; x < res; x++) {
          // Values one 16-bit step apart: an 8-bit round-trip would collapse
          // these into a single level.
          image.setPixelR(x, y, 30000 + x);
        }
      }
      final decoded = LandscapeAssetService.decodeHeightmapSamples(img.encodePng(image));
      expect(decoded.bitDepth, 16);
      for (var x = 1; x < res; x++) {
        expect(decoded.samples[x], decoded.samples[x - 1] + 1,
            reason: 'sample $x must keep its own 16-bit level');
      }

      final data = LandscapeAssetService.importHeightmap(
        pngBytes: img.encodePng(image),
        worldSize: 128.0,
        maxHeight: 100.0,
      );
      for (var x = 1; x < res; x++) {
        expect(data.heightAt(x, 0), greaterThan(data.heightAt(x - 1, 0)));
      }
    });
  });

  group('Sculpt brushes', () {
    LandscapeData flat() => LandscapeData.flat(gridResolution: 129, worldSize: 256.0, maxHeight: 100.0);

    test('sculpt raises the centre by strength, leaves the outer radius untouched, tight dirty rect', () {
      final data = flat();
      final rect = LandscapeBrush.stamp(
        data,
        const LandscapeBrushSettings(
          tool: LandscapeTool.sculpt,
          radius: 10.0,
          strength: 0.5,
          falloff: 0.5,
          falloffType: LandscapeFalloffType.smooth,
        ),
        0.0,
        0.0,
      );
      expect(rect, isNotNull);
      // v2 heights are uint16 of maxHeight, so assertions live at that step.
      expect(data.sampleHeight(0.0, 0.0), closeTo(0.5, data.heightStep));
      // At the brush edge the weight is zero.
      expect(data.sampleHeight(10.0, 0.0), closeTo(0.0, data.heightStep));
      expect(data.sampleHeight(30.0, 0.0), 0.0);

      // The rect covers exactly the touched cells (radius 10 m, cell 2 m).
      final cell = data.cellSize;
      final cells = (10.0 / cell).ceil();
      final centreCol = (data.gridResolution - 1) ~/ 2;
      expect(rect!.minCol, centreCol - cells);
      expect(rect.maxCol, centreCol + cells);
      expect(rect.minRow, centreCol - cells);
      expect(rect.maxRow, centreCol + cells);
    });

    test('Linear and Smooth falloff differ at mid radius; invert lowers', () {
      const mid = 3.0;
      double probe(LandscapeFalloffType type) {
        final data = flat();
        LandscapeBrush.stamp(
          data,
          LandscapeBrushSettings(tool: LandscapeTool.sculpt, radius: 10.0, strength: 1.0, falloff: 1.0, falloffType: type),
          0.0,
          0.0,
        );
        return data.sampleHeight(mid, 0.0);
      }

      final linear = probe(LandscapeFalloffType.linear);
      final smooth = probe(LandscapeFalloffType.smooth);
      final spherical = probe(LandscapeFalloffType.spherical);
      expect(linear, closeTo(0.7, 1e-3));
      expect((smooth - linear).abs(), greaterThan(0.01));
      expect((spherical - linear).abs(), greaterThan(0.01));

      final data = flat();
      const settings = LandscapeBrushSettings(
        tool: LandscapeTool.sculpt,
        radius: 10.0,
        strength: 0.4,
        falloff: 0.5,
        falloffType: LandscapeFalloffType.smooth,
      );
      LandscapeBrush.stamp(data, settings, 0.0, 0.0);
      LandscapeBrush.stamp(data, settings, 0.0, 0.0);
      expect(data.sampleHeight(0.0, 0.0), closeTo(0.8, data.heightStep));
      LandscapeBrush.stamp(data, settings.copyWith(invert: true), 0.0, 0.0);
      expect(data.sampleHeight(0.0, 0.0), closeTo(0.4, data.heightStep));
    });

    test('Flatten pulls in-radius heights toward the stroke-start height', () {
      final data = flat();
      for (var i = 0; i < data.vertexCount; i++) {
        data.setHeightAtIndex(i, 10.0 + (i % 7));
      }
      final start = data.sampleHeight(0.0, 0.0);
      for (var i = 0; i < 12; i++) {
        LandscapeBrush.stamp(
          data,
          const LandscapeBrushSettings(
            tool: LandscapeTool.flatten,
            radius: 12.0,
            strength: 0.8,
            falloff: 0.0,
            falloffType: LandscapeFalloffType.smooth,
          ),
          0.0,
          0.0,
          flattenTarget: start,
        );
      }
      expect(data.sampleHeight(0.0, 0.0), closeTo(start, 0.05));
      expect(data.sampleHeight(4.0, 2.0), closeTo(start, 0.2));
      // Outside the brush nothing moved.
      expect(data.sampleHeight(60.0, 0.0), isNot(closeTo(start, 0.001)));
    });

    test('Smooth reduces variance inside the rect and leaves the outside alone', () {
      final data = flat();
      final rnd = math.Random(3);
      for (var i = 0; i < data.vertexCount; i++) {
        data.setHeightAtIndex(i, rnd.nextDouble() * 20.0);
      }
      double variance(LandscapeData d, int c0, int r0, int c1, int r1) {
        var sum = 0.0;
        var n = 0;
        for (var r = r0; r <= r1; r++) {
          for (var c = c0; c <= c1; c++) {
            sum += d.heightAt(c, r);
            n++;
          }
        }
        final mean = sum / n;
        var v = 0.0;
        for (var r = r0; r <= r1; r++) {
          for (var c = c0; c <= c1; c++) {
            v += math.pow(d.heightAt(c, r) - mean, 2);
          }
        }
        return v / n;
      }

      final before = variance(data, 58, 58, 70, 70);
      final outsideBefore = List<double>.generate(20, (i) => data.heightAt(5 + i, 5));
      for (var i = 0; i < 6; i++) {
        LandscapeBrush.stamp(
          data,
          const LandscapeBrushSettings(
            tool: LandscapeTool.smooth,
            radius: 12.0,
            strength: 1.0,
            falloff: 0.0,
            falloffType: LandscapeFalloffType.smooth,
          ),
          0.0,
          0.0,
        );
      }
      final after = variance(data, 58, 58, 70, 70);
      expect(after, lessThan(before));
      expect(List<double>.generate(20, (i) => data.heightAt(5 + i, 5)), outsideBefore);
    });

    test('Noise is deterministic per seed and bounded by strength', () {
      final a = flat();
      final b = flat();
      const settings = LandscapeBrushSettings(
        tool: LandscapeTool.noise,
        radius: 20.0,
        strength: 0.5,
        falloff: 0.0,
        falloffType: LandscapeFalloffType.linear,
      );
      LandscapeBrush.stamp(a, settings, 0.0, 0.0, noiseSeed: 99);
      LandscapeBrush.stamp(b, settings, 0.0, 0.0, noiseSeed: 99);
      expect(a.samples, b.samples);
      final c = flat();
      LandscapeBrush.stamp(c, settings, 0.0, 0.0, noiseSeed: 100);
      expect(c.samples, isNot(a.samples));
      for (var i = 0; i < a.vertexCount; i++) {
        expect(a.heightAtIndex(i).abs(), lessThanOrEqualTo(0.5 + a.heightStep));
      }
    });
  });

  group('Dirty rect → mesh section windows', () {
    test('a brush on the corner shared by 4 tiles yields 4 row-window updates, never a full section', () {
      final data = LandscapeData.flat(gridResolution: 129, worldSize: 256.0, maxHeight: 100.0);
      final map = LandscapeSectionMap(gridResolution: 129);
      expect(map.sectionsPerSide, 2);
      expect(map.sectionCount, 4);

      // Centre of a 129² grid is column/row 64 — the seam shared by all 4 tiles.
      final rect = LandscapeBrush.stamp(
        data,
        const LandscapeBrushSettings(
          tool: LandscapeTool.sculpt,
          radius: 6.0,
          strength: 0.5,
          falloff: 0.5,
          falloffType: LandscapeFalloffType.smooth,
        ),
        0.0,
        0.0,
      )!;
      final windows = map.windowsFor(rect);
      expect(windows.length, 4);
      expect(windows.map((w) => w.sectionIndex).toSet(), {0, 1, 2, 3});
      for (final w in windows) {
        expect(w.vertexCount, lessThan(map.verticesPerSection), reason: 'row window, not a full-section upload');
        expect(w.vertexOffset % map.verticesPerRow, 0, reason: 'row-contiguous window');
        expect(w.vertexOffset + w.vertexCount, lessThanOrEqualTo(map.verticesPerSection));
      }

      // A brush well inside one tile only touches that tile.
      final single = LandscapeBrush.stamp(
        data,
        const LandscapeBrushSettings(
          tool: LandscapeTool.sculpt,
          radius: 4.0,
          strength: 0.5,
          falloff: 0.5,
          falloffType: LandscapeFalloffType.smooth,
        ),
        -60.0,
        -60.0,
      )!;
      expect(map.windowsFor(single).length, 1);
      expect(map.windowsFor(single).single.sectionIndex, 0);
    });

    test('section vertex grids duplicate the shared seam row', () {
      final map = LandscapeSectionMap(gridResolution: 129);
      expect(map.verticesPerRow, 65);
      expect(map.verticesPerSection, 65 * 65);
      expect(map.globalColumnOf(sectionIndex: 1, localCol: 0), 64);
      expect(map.globalColumnOf(sectionIndex: 0, localCol: 64), 64);
    });
  });

  group('Foliage scatter', () {
    LandscapeData terrain() => LandscapeData.flat(gridResolution: 129, worldSize: 256.0, maxHeight: 100.0);

    test('density + min spacing honoured, inside the circle, heights match the heightmap', () {
      final data = terrain();
      // A gentle slope so heights are not trivially zero.
      for (var r = 0; r < data.gridResolution; r++) {
        for (var c = 0; c < data.gridResolution; c++) {
          data.setHeight(c, r, c * 0.05);
        }
      }
      final layer = FoliageLayer(
        meshAssetId: 'grass',
        meshAssetPath: 'contents/meshes/grass.lmas',
        name: 'Grass',
        rules: const FoliageRules(
          density: 20.0,
          minSpacing: 1.5,
          scaleMin: 0.8,
          scaleMax: 1.4,
          randomYaw: true,
          alignToNormal: false,
          slopeMinDegrees: 0.0,
          slopeMaxDegrees: 60.0,
        ),
      );
      const cx = 0.0, cz = 0.0, radius = 8.0;
      final placed = LandscapeFoliagePainter.scatter(
        data: data,
        layer: layer,
        centerX: cx,
        centerZ: cz,
        radius: radius,
        random: math.Random(11),
      );
      final target = 20.0 * (math.pi * radius * radius) / 100.0;
      expect(placed.length, greaterThan(target * 0.8));
      expect(placed.length, lessThan(target * 1.2));

      for (final i in placed) {
        final d = math.sqrt(math.pow(i.x - cx, 2) + math.pow(i.z - cz, 2));
        expect(d, lessThanOrEqualTo(radius + 1e-6));
        expect(i.y, closeTo(data.sampleHeight(i.x, i.z), 1e-5));
        expect(i.scaleX, inInclusiveRange(0.8, 1.4));
        expect(i.scaleX, i.scaleY);
      }
      for (var a = 0; a < placed.length; a++) {
        for (var b = a + 1; b < placed.length; b++) {
          final d = math.sqrt(math.pow(placed[a].x - placed[b].x, 2) + math.pow(placed[a].z - placed[b].z, 2));
          expect(d, greaterThanOrEqualTo(1.5 - 1e-9));
        }
      }
    });

    test('slope filter rejects everything on a cliff steeper than the max slope', () {
      final data = LandscapeData.flat(gridResolution: 129, worldSize: 256.0, maxHeight: 10000.0);
      for (var r = 0; r < data.gridResolution; r++) {
        for (var c = 0; c < data.gridResolution; c++) {
          data.setHeight(c, r, c * 20.0); // ~84° slope at 2 m cells
        }
      }
      final layer = FoliageLayer(
        meshAssetId: 'grass',
        meshAssetPath: 'p',
        name: 'Grass',
        rules: const FoliageRules(density: 40.0, minSpacing: 0.5, slopeMaxDegrees: 30.0),
      );
      final placed = LandscapeFoliagePainter.scatter(
        data: data,
        layer: layer,
        centerX: 0.0,
        centerZ: 0.0,
        radius: 8.0,
        random: math.Random(5),
      );
      expect(placed, isEmpty);
    });

    test('align to normal matches heightmap normals; off keeps instances upright', () {
      final data = terrain();
      for (var r = 0; r < data.gridResolution; r++) {
        for (var c = 0; c < data.gridResolution; c++) {
          data.setHeight(c, r, c * 0.4);
        }
      }
      FoliageLayer makeLayer(bool align) => FoliageLayer(
            meshAssetId: 'grass',
            meshAssetPath: 'p',
            name: 'Grass',
            rules: FoliageRules(density: 10.0, minSpacing: 1.0, alignToNormal: align, slopeMaxDegrees: 80.0),
          );

      final aligned = LandscapeFoliagePainter.scatter(
        data: data,
        layer: makeLayer(true),
        centerX: 0.0,
        centerZ: 0.0,
        radius: 8.0,
        random: math.Random(21),
      );
      expect(aligned, isNotEmpty);
      for (final i in aligned) {
        final n = data.sampleNormal(i.x, i.z);
        final dot = i.nx * n.x + i.ny * n.y + i.nz * n.z;
        expect(dot, greaterThan(0.99));
        expect(i.ny, lessThan(0.9999), reason: 'the slope is real, so the normal is tilted');
      }

      final upright = LandscapeFoliagePainter.scatter(
        data: data,
        layer: makeLayer(false),
        centerX: 0.0,
        centerZ: 0.0,
        radius: 8.0,
        random: math.Random(21),
      );
      for (final i in upright) {
        expect(i.ny, closeTo(1.0, 1e-9));
        expect(i.nx, 0.0);
      }
    });

    test('erase removes only instances inside the circle and swap-remove keeps the mirror consistent', () {
      final data = terrain();
      final layer = FoliageLayer(meshAssetId: 'grass', meshAssetPath: 'p', name: 'Grass');
      for (var x = -10.0; x <= 10.0; x += 2.0) {
        layer.addInstance(FoliageInstance(
          x: x,
          y: data.sampleHeight(x, 0.0),
          z: 0.0,
          scaleX: 1.0,
          scaleY: 1.0,
          scaleZ: 1.0,
          yaw: 0.0,
          nx: 0.0,
          ny: 1.0,
          nz: 0.0,
        ));
      }
      final before = layer.instanceCount;
      expect(before, 11);

      final removed = LandscapeFoliagePainter.instancesInCircle(layer, 6.0, 0.0, 4.0);
      expect(removed, isNotEmpty);
      final keptXs = <double>[];
      for (var i = 0; i < layer.instanceCount; i++) {
        if (!removed.contains(i)) keptXs.add(layer.instanceAt(i).x);
      }
      for (final index in removed.reversed) {
        layer.removeAt(index);
      }
      expect(layer.instanceCount, before - removed.length);
      final xs = List.generate(layer.instanceCount, (i) => layer.instanceAt(i).x)..sort();
      expect(xs, (keptXs..sort()));
      expect(layer.transforms.length, layer.instanceCount * FoliageLayer.floatsPerInstance);
      for (var i = 0; i < layer.instanceCount; i++) {
        expect(layer.instanceAt(i).ny, 1.0, reason: 'no orphaned / shifted transform floats');
      }
    });
  });
}
