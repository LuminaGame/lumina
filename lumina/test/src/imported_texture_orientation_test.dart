// An imported textured mesh draws its texture upright: the image's top-left
// corner on the quad's top-left corner, whatever format the quad came from
// (glTF, or OBJ / FBX / Collada converted by Assimp) and whether it draws the
// glTF material gltfio builds or the imported material compiled with matc.
//
// The reference is absolute: a quad whose texture has four coloured
// quadrants, rendered on the default backend and read back. Screen up and
// right are taken from where the quad lands, not from the read-back row order.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

Directory get _assets => Directory(Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets');

/// The texture's quadrants, as the image is written (row 0 at the top).
enum Quadrant { topLeft, topRight, bottomLeft, bottomRight }

const _colours = {
  Quadrant.topLeft: [230, 20, 20], // red
  Quadrant.topRight: [20, 210, 30], // green
  Quadrant.bottomLeft: [20, 40, 230], // blue
  Quadrant.bottomRight: [235, 225, 20], // yellow
};

/// Which quadrant colour a lit, tone-mapped sample is.
Quadrant? classify(List<int> rgb) {
  final [r, g, b] = rgb;
  if (r + g + b < 30) return null;
  final max = [r, g, b].reduce((a, c) => a > c ? a : c);
  final hi = [r > 0.55 * max, g > 0.55 * max, b > 0.55 * max];
  if (hi[0] && hi[1] && !hi[2]) return Quadrant.bottomRight;
  if (hi[0] && !hi[1] && !hi[2]) return Quadrant.topLeft;
  if (!hi[0] && hi[1] && !hi[2]) return Quadrant.topRight;
  if (!hi[0] && !hi[1] && hi[2]) return Quadrant.bottomLeft;
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory src;

  setUpAll(() {
    root = Directory.systemTemp.createTempSync('lumina_uv_orientation_');
    File('${root.path}/P.lmproject').writeAsStringSync(jsonEncode(const LuminaProject(projectName: 'P').toMap()));
    src = Directory('${root.path}/src')..createSync();
    final image = img.Image(width: 64, height: 64);
    for (final MapEntry(key: q, value: c) in _colours.entries) {
      final x0 = q == Quadrant.topLeft || q == Quadrant.bottomLeft ? 0 : 32;
      final y0 = q == Quadrant.topLeft || q == Quadrant.topRight ? 0 : 32;
      img.fillRect(image, x1: x0, y1: y0, x2: x0 + 31, y2: y0 + 31, color: img.ColorRgb8(c[0], c[1], c[2]));
    }
    File('${src.path}/quadrants.png').writeAsBytesSync(img.encodePng(image));
  });

  tearDownAll(() => root.deleteSync(recursive: true));

  // The quad: x -1..1, y 0..2, facing +Z. Source-convention UVs put the
  // image's top-left at the quad's top-left corner (-1, 2, 0).
  final sources = <String, String Function()>{
    'quad_gltf.glb': () => _writeGltfQuad('${src.path}/quad_gltf.glb', File('${src.path}/quadrants.png').readAsBytesSync()),
    'quad_obj.obj': () {
      File('${src.path}/quad_obj.mtl').writeAsStringSync('newmtl Quadrants\nKd 1 1 1\nmap_Kd quadrants.png\n');
      return (File('${src.path}/quad_obj.obj')
            ..writeAsStringSync('mtllib quad_obj.mtl\nv -1 0 0\nv 1 0 0\nv 1 2 0\nv -1 2 0\n'
                'vt 0 0\nvt 1 0\nvt 1 1\nvt 0 1\nusemtl Quadrants\nf 1/1 2/2 3/3\nf 1/1 3/3 4/4\n'))
          .path;
    },
    'quad_fbx.fbx': () => (File('${src.path}/quad_fbx.fbx')..writeAsStringSync(_fbxQuad('quadrants.png'))).path,
    'quad_dae.dae': () => (File('${src.path}/quad_dae.dae')..writeAsStringSync(_colladaQuad('quadrants.png'))).path,
  };

  bool skip(String file) {
    if (!file.endsWith('.glb') && !FlutterAssimp.isAvailable) {
      markTestSkipped('Assimp bridge not loaded');
      return true;
    }
    if (file.endsWith('.dae') && !FlutterAssimp.isSupportedFormat('dae')) {
      markTestSkipped('Assimp bridge built without Collada');
      return true;
    }
    return false;
  }

  const width = 128;
  const height = 128;

  late FilamentEngine engine;
  late FilamentScene scene;
  late FilamentView view;
  late int cameraEntity;
  late FilamentCamera camera;
  late FilamentRenderer renderer;
  late FilamentSwapChain swapChain;
  late LuminaWorld world;

  setUp(() {
    engine = FilamentEngine.create()!;
    scene = engine.createScene();
    view = engine.createView();
    cameraEntity = engine.createEntity();
    camera = engine.createCamera(cameraEntity);
    renderer = engine.createRenderer();
    swapChain = engine.createHeadlessSwapChain(width, height);
    view.scene = scene;
    view.camera = camera;
    view.setViewport(0, 0, width, height);
    renderer.setClearOptions(r: 0.0, g: 0.0, b: 0.0, a: 1.0);
    world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
    // Travels along -Z: straight onto the quad's front.
    world.persistentLevel.registerActor(LuminaActor(
      root: LuminaDirectionalLightComponent(color: Vector3(1.0, 1.0, 1.0), intensity: 100000.0, castShadows: false),
    ));
    LuminaAssets.projectDir = root.path;
  });

  tearDown(() {
    LuminaAssets.projectDir = null;
    world.cleanup();
    view.dispose();
    scene.dispose();
    engine.destroyEntity(cameraEntity);
    camera.dispose();
    renderer.dispose();
    swapChain.dispose();
    engine.dispose();
  });

  /// Imports [file] (once) and returns the project paths of its mesh and its
  /// textured material.
  final imported = <String, ({String mesh, String material})>{};
  Future<({String mesh, String material})> importQuad(String file) async {
    if (imported[file] case final done?) return done;
    await AssetRepository().importExternalFile(projectPath: root.path, sourceFilePath: sources[file]!());
    final stem = file.substring(0, file.indexOf('.'));
    String rel(File f) => f.path.replaceAll(r'\', '/').substring(root.path.replaceAll(r'\', '/').length + 1);
    final files = Directory('${root.path}/contents').listSync(recursive: true).whereType<File>().toList();
    final mesh = files.singleWhere((f) => f.path.replaceAll(r'\', '/').endsWith('/meshes/static/$stem.entity.glb'));
    final material = files.singleWhere((f) {
      if (!f.path.endsWith('.lmas') || !f.path.replaceAll(r'\', '/').contains('/materials/$stem/')) return false;
      final asset = LuminaAsset.fromBytes(f.readAsBytesSync());
      return asset.type == AssetType.filamat && asset.references.any((r) => r.slotName == 'baseColorMap');
    });
    return imported[file] = (mesh: rel(mesh), material: rel(material));
  }

  /// Compiles the imported material with matc and stores the package, as the
  /// Material Editor's Compile + Save does.
  void compile(String material) {
    final f = File('${root.path}/$material');
    final asset = LuminaAsset.fromBytes(f.readAsBytesSync());
    if (asset.rawPayload != null && asset.rawPayload!.isNotEmpty) return;
    final result = FilamentMatc.compile(asset.rawMatSource, fileName: '${asset.name}.mat', defaultName: asset.name);
    expect(result.ok, isTrue, reason: result.log);
    f.writeAsBytesSync(LuminaAsset(
      assetId: asset.assetId,
      name: asset.name,
      type: asset.type,
      rawPayload: result.package,
      rawMatSource: asset.rawMatSource,
      references: asset.references,
      metadata: asset.metadata,
    ).toProtoBufferBytes());
  }

  /// Draws [mesh] (with [material] in place of its own when given) and
  /// returns the quadrant colour found at each corner of the quad on screen.
  Future<Map<Quadrant, Quadrant?>> drawnCorners(String mesh, {String? material}) async {
    final actor = LuminaStaticMeshActor(meshAssetPath: mesh, materialOverrideAsset: material);
    world.persistentLevel.registerActor(actor);
    world.beginPlay();
    await actor.meshComponent.loaded.timeout(const Duration(seconds: 20));
    if (material != null) {
      for (var i = 0; i < 500 && actor.meshComponent.materialOverride() == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(actor.meshComponent.materialOverride(), isNotNull, reason: 'the compiled material is drawn');
    }
    final bounds = actor.meshComponent.localBounds!;
    final centre = bounds.center;
    final size = bounds.max.y - bounds.min.y;
    // Aim below and left of the quad, so it lands in the upper right of the
    // frame: that tells which read-back rows and columns are up and right.
    final target = centre - Vector3(size * 0.3, size * 0.3, 0);
    camera.setProjection(fovDegrees: 60.0, aspect: 1.0, near: size * 0.05, far: size * 20, direction: FovDirection.vertical);
    camera.lookAt(
      eyeX: target.x, eyeY: target.y, eyeZ: centre.z + size * 2.2,
      centerX: target.x, centerY: target.y, centerZ: centre.z,
    );
    world.tick(1 / 60);
    final pixels = Uint8List(width * height * 4);
    for (var i = 0; i < 4; i++) {
      if (renderer.beginFrame(swapChain)) {
        renderer.render(view);
        renderer.readPixels(x: 0, y: 0, width: width, height: height, outPixels: pixels);
        renderer.endFrame();
      }
      engine.flushAndWait();
    }
    List<int> at(int x, int y) => [for (var c = 0; c < 3; c++) pixels[(y * width + x) * 4 + c]];
    var x0 = width, x1 = -1, y0 = height, y1 = -1;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (at(x, y).reduce((a, b) => a + b) < 30) continue;
        if (x < x0) x0 = x;
        if (x > x1) x1 = x;
        if (y < y0) y0 = y;
        if (y > y1) y1 = y;
      }
    }
    expect(x1, greaterThan(x0), reason: 'the quad is lit and in frame');
    // The quad sits in the upper right: its rows are nearer the "up" end.
    final upIsHighRow = (y0 + y1) / 2 > height / 2;
    final rightIsHighColumn = (x0 + x1) / 2 > width / 2;
    int col(double f) => (rightIsHighColumn ? x0 + (x1 - x0) * f : x1 - (x1 - x0) * f).round();
    int row(double f) => (upIsHighRow ? y1 - (y1 - y0) * f : y0 + (y1 - y0) * f).round(); // f from the top
    return {
      Quadrant.topLeft: classify(at(col(0.25), row(0.25))),
      Quadrant.topRight: classify(at(col(0.75), row(0.25))),
      Quadrant.bottomLeft: classify(at(col(0.25), row(0.75))),
      Quadrant.bottomRight: classify(at(col(0.75), row(0.75))),
    };
  }

  const upright = {
    Quadrant.topLeft: Quadrant.topLeft,
    Quadrant.topRight: Quadrant.topRight,
    Quadrant.bottomLeft: Quadrant.bottomLeft,
    Quadrant.bottomRight: Quadrant.bottomRight,
  };

  for (final file in sources.keys) {
    final format = file.substring(file.indexOf('.') + 1).toUpperCase();
    test('a $format quad draws its own material with the texture upright', () async {
      if (skip(file)) return;
      final quad = await importQuad(file);
      expect(await drawnCorners(quad.mesh), upright);
    });

    test('a $format quad draws its compiled imported material with the texture upright', () async {
      if (skip(file)) return;
      final quad = await importQuad(file);
      compile(quad.material);
      expect(await drawnCorners(quad.mesh, material: quad.material), upright);
    });
  }

  test("an FBX import's texture coordinates match a glTF of the same model", () async {
    final fbx = File('${_assets.path}/fixtures/blackjack_blender2.FBX');
    final reference = File('${_assets.path}/fixtures/blackjack_blender2.glb');
    if (!fbx.existsSync() || !reference.existsSync()) return markTestSkipped('test-assets fixtures missing');
    if (!FlutterAssimp.isAvailable) return markTestSkipped('Assimp bridge not loaded');
    await AssetRepository().importExternalFile(projectPath: root.path, sourceFilePath: fbx.path);
    final mesh = File('${root.path}/contents/meshes/static/blackjack_blender2.entity.glb');

    final ref = _uvsByCorner(reference.readAsBytesSync());
    final got = _uvsByCorner(mesh.readAsBytesSync());
    var same = 0, flipped = 0, total = 0;
    for (final MapEntry(key: position, value: uvs) in got.entries) {
      final want = ref[position];
      if (want == null) continue;
      for (final (u, v) in uvs) {
        total++;
        if (want.contains((u, v))) same++;
        if (want.contains((u, (1000 - v)))) flipped++;
      }
    }
    expect(total, greaterThan(got.length * 0.9), reason: 'the vertices are found in the reference');
    expect(same / total, greaterThan(0.99), reason: 'UVs equal the glTF reference ($same of $total; flipped $flipped)');
    expect(flipped / total, lessThan(0.2));
  });
}

/// The world-space vertices of every mesh in [glb] (node matrices applied),
/// normalised into their bounding box and rounded to 1/1000, each with the
/// set of texture coordinates (×1000, rounded) drawn there.
Map<(int, int, int), Set<(int, int)>> _uvsByCorner(Uint8List glb) {
  final data = ByteData.sublistView(glb);
  final jsonLength = data.getUint32(12, Endian.little);
  final json = jsonDecode(utf8.decode(glb.sublist(20, 20 + jsonLength))) as Map<String, dynamic>;
  final binStart = 20 + jsonLength + 8;
  List<List<double>> read(int index) {
    final acc = (json['accessors'] as List)[index] as Map;
    final view = (json['bufferViews'] as List)[acc['bufferView'] as int] as Map;
    final width = acc['type'] == 'VEC3' ? 3 : 2;
    final stride = (view['byteStride'] as int?) ?? width * 4;
    final start = binStart + ((view['byteOffset'] as int?) ?? 0) + ((acc['byteOffset'] as int?) ?? 0);
    return [
      for (var i = 0; i < (acc['count'] as int); i++)
        [for (var c = 0; c < width; c++) data.getFloat32(start + i * stride + c * 4, Endian.little)],
    ];
  }

  final points = <(Vector3, List<double>)>[];
  void visit(int index, Matrix4 parent) {
    final node = (json['nodes'] as List)[index] as Map;
    final local = node['matrix'] != null
        ? Matrix4.fromList([for (final v in node['matrix'] as List) (v as num).toDouble()])
        : Matrix4.compose(
            Vector3.array([for (final v in (node['translation'] as List?) ?? [0, 0, 0]) (v as num).toDouble()]),
            Quaternion(
              ((node['rotation'] as List?)?[0] as num? ?? 0).toDouble(),
              ((node['rotation'] as List?)?[1] as num? ?? 0).toDouble(),
              ((node['rotation'] as List?)?[2] as num? ?? 0).toDouble(),
              ((node['rotation'] as List?)?[3] as num? ?? 1).toDouble(),
            ),
            Vector3.array([for (final v in (node['scale'] as List?) ?? [1, 1, 1]) (v as num).toDouble()]),
          );
    final world = parent * local as Matrix4;
    if (node['mesh'] case final int m) {
      for (final p in ((json['meshes'] as List)[m] as Map)['primitives'] as List) {
        final attributes = (p as Map)['attributes'] as Map;
        final positions = read(attributes['POSITION'] as int);
        final uvs = read(attributes['TEXCOORD_0'] as int);
        for (var i = 0; i < positions.length; i++) {
          points.add((world.transformed3(Vector3(positions[i][0], positions[i][1], positions[i][2])), uvs[i]));
        }
      }
    }
    for (final c in (node['children'] as List?) ?? const []) {
      visit(c as int, world);
    }
  }

  final scene = (json['scenes'] as List)[(json['scene'] as int?) ?? 0] as Map;
  for (final n in scene['nodes'] as List) {
    visit(n as int, Matrix4.identity());
  }
  final lo = Vector3.all(double.infinity), hi = Vector3.all(-double.infinity);
  for (final (p, _) in points) {
    Vector3.min(lo, p, lo);
    Vector3.max(hi, p, hi);
  }
  final out = <(int, int, int), Set<(int, int)>>{};
  for (final (p, uv) in points) {
    final n = [for (var c = 0; c < 3; c++) ((p[c] - lo[c]) / (hi[c] - lo[c]) * 1000).round()];
    out.putIfAbsent((n[0], n[1], n[2]), () => {}).add(((uv[0] * 1000).round(), (uv[1] * 1000).round()));
  }
  return out;
}

/// A glTF quad written by hand: V down (glTF), so the image's top-left
/// (uv 0, 0) sits at the quad's top-left corner (-1, 2, 0). The PNG is
/// embedded and is the material's base colour texture.
String _writeGltfQuad(String path, Uint8List png) {
  const positions = [-1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 2.0, 0.0, -1.0, 2.0, 0.0];
  const uvs = [0.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0];
  const normals = [0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0];
  final imageOffset = 48 + 48 + 32 + 12;
  final pad = (4 - png.length % 4) % 4;
  final bin = ByteData(imageOffset + png.length + pad);
  var o = 0;
  for (final v in [...positions, ...normals, ...uvs]) {
    bin.setFloat32(o, v, Endian.little);
    o += 4;
  }
  for (final i in [0, 1, 2, 0, 2, 3]) {
    bin.setUint16(o, i, Endian.little);
    o += 2;
  }
  bin.buffer.asUint8List().setRange(imageOffset, imageOffset + png.length, png);
  final json = {
    'asset': {'version': '2.0'},
    'buffers': [{'byteLength': bin.lengthInBytes}],
    'bufferViews': [
      {'buffer': 0, 'byteOffset': 0, 'byteLength': 48},
      {'buffer': 0, 'byteOffset': 48, 'byteLength': 48},
      {'buffer': 0, 'byteOffset': 96, 'byteLength': 32},
      {'buffer': 0, 'byteOffset': 128, 'byteLength': 12},
      {'buffer': 0, 'byteOffset': imageOffset, 'byteLength': png.length},
    ],
    'accessors': [
      {'bufferView': 0, 'componentType': 5126, 'count': 4, 'type': 'VEC3', 'min': [-1, 0, 0], 'max': [1, 2, 0]},
      {'bufferView': 1, 'componentType': 5126, 'count': 4, 'type': 'VEC3'},
      {'bufferView': 2, 'componentType': 5126, 'count': 4, 'type': 'VEC2'},
      {'bufferView': 3, 'componentType': 5123, 'count': 6, 'type': 'SCALAR'},
    ],
    'images': [{'bufferView': 4, 'mimeType': 'image/png', 'name': 'quadrants'}],
    'samplers': [{'magFilter': 9728, 'minFilter': 9728}],
    'textures': [{'source': 0, 'sampler': 0}],
    'materials': [
      {
        'name': 'Quadrants',
        'pbrMetallicRoughness': {'baseColorTexture': {'index': 0}, 'metallicFactor': 0.0, 'roughnessFactor': 1.0},
      },
    ],
    'meshes': [
      {
        'name': 'Quad',
        'primitives': [
          {'attributes': {'POSITION': 0, 'NORMAL': 1, 'TEXCOORD_0': 2}, 'indices': 3, 'material': 0},
        ],
      },
    ],
    'nodes': [{'mesh': 0, 'name': 'Quad'}],
    'scenes': [{'nodes': [0]}],
    'scene': 0,
  };
  var jsonBytes = utf8.encode(jsonEncode(json));
  jsonBytes = Uint8List.fromList([...jsonBytes, ...List.filled((4 - jsonBytes.length % 4) % 4, 0x20)]);
  ByteData u32s(List<int> v) {
    final d = ByteData(v.length * 4);
    for (var i = 0; i < v.length; i++) {
      d.setUint32(i * 4, v[i], Endian.little);
    }
    return d;
  }

  final total = 12 + 8 + jsonBytes.length + 8 + bin.lengthInBytes;
  File(path).writeAsBytesSync([
    ...u32s([0x46546C67, 2, total]).buffer.asUint8List(),
    ...u32s([jsonBytes.length, 0x4E4F534A]).buffer.asUint8List(),
    ...jsonBytes,
    ...u32s([bin.lengthInBytes, 0x004E4942]).buffer.asUint8List(),
    ...bin.buffer.asUint8List(),
  ]);
  return path;
}

/// An ASCII FBX 7.4 quad (Y up) whose material's diffuse texture is [texture].
String _fbxQuad(String texture) => '''; FBX 7.4.0 project file
FBXHeaderExtension:  {
	FBXHeaderVersion: 1003
	FBXVersion: 7400
}
GlobalSettings:  {
	Version: 1000
	Properties70:  {
		P: "UpAxis", "int", "Integer", "",1
		P: "UpAxisSign", "int", "Integer", "",1
		P: "FrontAxis", "int", "Integer", "",2
		P: "FrontAxisSign", "int", "Integer", "",1
		P: "CoordAxis", "int", "Integer", "",0
		P: "CoordAxisSign", "int", "Integer", "",1
		P: "UnitScaleFactor", "double", "Number", "",100
	}
}
Objects:  {
	Geometry: 1000, "Geometry::Quad", "Mesh" {
		Vertices: *12 {
			a: -1,0,0,1,0,0,1,2,0,-1,2,0
		}
		PolygonVertexIndex: *4 {
			a: 0,1,2,-4
		}
		GeometryVersion: 124
		LayerElementNormal: 0 {
			Version: 101
			Name: ""
			MappingInformationType: "ByPolygonVertex"
			ReferenceInformationType: "Direct"
			Normals: *12 {
				a: 0,0,1,0,0,1,0,0,1,0,0,1
			}
		}
		LayerElementUV: 0 {
			Version: 101
			Name: "UVMap"
			MappingInformationType: "ByPolygonVertex"
			ReferenceInformationType: "IndexToDirect"
			UV: *8 {
				a: 0,0,1,0,1,1,0,1
			}
			UVIndex: *4 {
				a: 0,1,2,3
			}
		}
		LayerElementMaterial: 0 {
			Version: 101
			Name: ""
			MappingInformationType: "AllSame"
			ReferenceInformationType: "IndexToDirect"
			Materials: *1 {
				a: 0
			}
		}
		Layer: 0 {
			Version: 100
			LayerElement:  {
				Type: "LayerElementNormal"
				TypedIndex: 0
			}
			LayerElement:  {
				Type: "LayerElementUV"
				TypedIndex: 0
			}
			LayerElement:  {
				Type: "LayerElementMaterial"
				TypedIndex: 0
			}
		}
	}
	Model: 2000, "Model::quad_fbx", "Mesh" {
		Version: 232
		Properties70:  {
		}
		Shading: T
		Culling: "CullingOff"
	}
	Material: 3000, "Material::Quadrants", "" {
		Version: 102
		ShadingModel: "lambert"
		MultiLayer: 0
		Properties70:  {
			P: "DiffuseColor", "Color", "", "A",1,1,1
		}
	}
	Texture: 4000, "Texture::quadrants", "" {
		Type: "TextureVideoClip"
		Version: 202
		TextureName: "Texture::quadrants"
		Media: "Video::quadrants"
		FileName: "$texture"
		RelativeFilename: "$texture"
	}
	Video: 5000, "Video::quadrants", "Clip" {
		Type: "Clip"
		FileName: "$texture"
		RelativeFilename: "$texture"
	}
}
Connections:  {
	C: "OO",2000,0
	C: "OO",1000,2000
	C: "OO",3000,2000
	C: "OP",4000,3000, "DiffuseColor"
	C: "OO",5000,4000
}
''';

/// A Collada quad whose material samples [texture] (V up, as Collada stores it).
String _colladaQuad(String texture) => '''<?xml version="1.0" encoding="utf-8"?>
<COLLADA xmlns="http://www.collada.org/2005/11/COLLADASchema" version="1.4.1">
  <asset><unit name="meter" meter="1"/><up_axis>Y_UP</up_axis></asset>
  <library_images><image id="quadrants_png" name="quadrants_png"><init_from>$texture</init_from></image></library_images>
  <library_effects><effect id="quadrants-fx"><profile_COMMON>
    <newparam sid="quadrants-surface"><surface type="2D"><init_from>quadrants_png</init_from></surface></newparam>
    <newparam sid="quadrants-sampler"><sampler2D><source>quadrants-surface</source></sampler2D></newparam>
    <technique sid="common"><lambert><diffuse><texture texture="quadrants-sampler" texcoord="UVMap"/></diffuse></lambert></technique>
  </profile_COMMON></effect></library_effects>
  <library_materials><material id="Quadrants-mat" name="Quadrants"><instance_effect url="#quadrants-fx"/></material></library_materials>
  <library_geometries><geometry id="quad" name="Quad"><mesh>
    <source id="pos"><float_array id="pos-a" count="12">-1 0 0 1 0 0 1 2 0 -1 2 0</float_array>
      <technique_common><accessor source="#pos-a" count="4" stride="3"><param name="X" type="float"/><param name="Y" type="float"/><param name="Z" type="float"/></accessor></technique_common></source>
    <source id="nrm"><float_array id="nrm-a" count="3">0 0 1</float_array>
      <technique_common><accessor source="#nrm-a" count="1" stride="3"><param name="X" type="float"/><param name="Y" type="float"/><param name="Z" type="float"/></accessor></technique_common></source>
    <source id="uv"><float_array id="uv-a" count="8">0 0 1 0 1 1 0 1</float_array>
      <technique_common><accessor source="#uv-a" count="4" stride="2"><param name="S" type="float"/><param name="T" type="float"/></accessor></technique_common></source>
    <vertices id="verts"><input semantic="POSITION" source="#pos"/></vertices>
    <triangles material="Quadrants" count="2"><input semantic="VERTEX" source="#verts" offset="0"/><input semantic="NORMAL" source="#nrm" offset="1"/><input semantic="TEXCOORD" source="#uv" offset="2" set="0"/>
      <p>0 0 0 1 0 1 2 0 2 0 0 0 2 0 2 3 0 3</p></triangles>
  </mesh></geometry></library_geometries>
  <library_visual_scenes><visual_scene id="scene"><node id="QuadNode" name="quad_dae">
    <instance_geometry url="#quad"><bind_material><technique_common>
      <instance_material symbol="Quadrants" target="#Quadrants-mat"><bind_vertex_input semantic="UVMap" input_semantic="TEXCOORD" input_set="0"/></instance_material>
    </technique_common></bind_material></instance_geometry>
  </node></visual_scene></library_visual_scenes>
  <scene><instance_visual_scene url="#scene"/></scene>
</COLLADA>
''';
