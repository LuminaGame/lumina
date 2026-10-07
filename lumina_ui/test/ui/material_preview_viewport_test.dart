import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_preview_renderer.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/preview_mesh_factory.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/material_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Regression coverage: the Material Editor preview must drive a
/// real shaded primitive (native path) and, in software fallback, shade with
/// the material's parameters instead of a flat cyan wireframe.
const _source = '''material {
    name : "M_Preview",
    parameters : [
        { type : float, name : roughness, default : 0.25 },
        { type : float, name : metallic, default : 1.0 },
        { type : float4, name : baseColor, default : [0.9, 0.2, 0.1, 1.0] }
    ],
}
fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
    }
}''';

void main() {
  group('PreviewMeshFactory', () {
    for (final shape in [PreviewShape.sphere, PreviewShape.cube, PreviewShape.cylinder, PreviewShape.plane]) {
      test('$shape produces a closed, well-formed triangle mesh', () {
        final mesh = PreviewMeshFactory.build(shape);
        expect(mesh.positions.length % 3, 0);
        expect(mesh.normals.length, mesh.positions.length);
        expect(mesh.uv0.length, mesh.vertexCount * 2);
        expect(mesh.indices.length % 3, 0);
        expect(mesh.triangleCount, greaterThan(0));
        for (final i in mesh.indices) {
          expect(i, lessThan(mesh.vertexCount));
        }
        for (var v = 0; v < mesh.vertexCount; v++) {
          final nx = mesh.normals[v * 3], ny = mesh.normals[v * 3 + 1], nz = mesh.normals[v * 3 + 2];
          expect(math.sqrt(nx * nx + ny * ny + nz * nz), closeTo(1.0, 1e-5));
          for (var a = 0; a < 3; a++) {
            expect(mesh.positions[v * 3 + a], inInclusiveRange(mesh.minBounds[a] - 1e-6, mesh.maxBounds[a] + 1e-6));
          }
        }
      });
    }

    test('sphere is dense enough to look smooth and mesh falls back to sphere', () {
      expect(PreviewMeshFactory.sphere().vertexCount, greaterThan(400));
      expect(PreviewMeshFactory.build(PreviewShape.mesh).vertexCount, PreviewMeshFactory.sphere().vertexCount);
      expect(PreviewMeshFactory.cube().triangleCount, 12);
      expect(PreviewMeshFactory.plane().triangleCount, 2);
    });
  });

  group('MaterialPreviewRenderer packing', () {
    test('tangent frame maps +Z onto the normal and is a unit quaternion with w >= 0', () {
      for (final n in [
        [0.0, 1.0, 0.0],
        [0.0, -1.0, 0.0],
        [1.0, 0.0, 0.0],
        [0.3, 0.4, 0.866],
      ]) {
        final q = MaterialPreviewRenderer.tangentFrameFromNormal(n[0], n[1], n[2]);
        expect(q.length, closeTo(1.0, 1e-9));
        expect(q.w, greaterThanOrEqualTo(0.0));
        final m = q.asRotationMatrix();
        final z = m.getColumn(2);
        final len = math.sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]);
        expect(z.x, closeTo(n[0] / len, 1e-6));
        expect(z.y, closeTo(n[1] / len, 1e-6));
        expect(z.z, closeTo(n[2] / len, 1e-6));
      }
    });

    test('interleaved vertex layout is 28 bytes per vertex with positions first', () {
      final mesh = PreviewMeshFactory.plane();
      final bytes = MaterialPreviewRenderer.packVertices(mesh);
      expect(bytes.length, mesh.vertexCount * 28);
      final data = ByteData.view(bytes.buffer);
      expect(data.getFloat32(0, Endian.host), mesh.positions[0]);
      expect(data.getFloat32(28, Endian.host), mesh.positions[3]);
      expect(data.getFloat32(20, Endian.host), mesh.uv0[0]);
    });
  });

  group('software fallback shading', () {
    test('base colour and scalars are read from the material parameters', () {
      final params = [
        MaterialParamModel(name: 'roughness', type: MaterialParamType.floatType, value: 0.25),
        MaterialParamModel(name: 'metallic', type: MaterialParamType.floatType, value: 1.0),
        MaterialParamModel(name: 'baseColor', type: MaterialParamType.colorType, value: [0.9, 0.2, 0.1, 1.0]),
      ];
      final c = previewBaseColorFromParams(params);
      expect((c.r * 255).round(), (0.9 * 255).round());
      expect((c.g * 255).round(), (0.2 * 255).round());
      expect(previewScalarFromParams(params, 'Roughness', 0.6), 0.25);
      expect(previewScalarFromParams(params, 'missing', 0.6), 0.6);
      expect(previewBaseColorFromParams(const []), const Color(0xFF00BCD4));
    });

    test('facets facing the light are brighter than facets facing away', () {
      const base = Color(0xFFCC3319);
      final lit = previewShadeColor(base, 1.0, roughness: 0.3);
      final dark = previewShadeColor(base, 0.0, roughness: 0.3);
      expect(lit.r + lit.g + lit.b, greaterThan(dark.r + dark.g + dark.b));
      expect(dark.r, greaterThan(0.0), reason: 'ambient keeps the dark side visible');
      // A rough surface has a weaker highlight than a glossy one.
      final glossy = previewShadeColor(base, 1.0, roughness: 0.0);
      final rough = previewShadeColor(base, 1.0, roughness: 1.0);
      expect(glossy.g, greaterThan(rough.g));
    });
  });

  test('only a real filamat package may reach the native renderer (garbage would abort Filament)', () {
    expect(SubEditor3DViewport.usesNativePreview(glbMesh: null, previewMaterialBytes: null), isFalse);
    expect(SubEditor3DViewport.usesNativePreview(glbMesh: null, previewMaterialBytes: Uint8List(0)), isFalse);
    final garbage = Uint8List.fromList([0x46, 0x49, 0x4C, 0x41, 0x01, 0x02, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
    expect(MaterialPreviewRenderer.isFilamatPackage(garbage), isFalse);
    expect(SubEditor3DViewport.usesNativePreview(glbMesh: null, previewMaterialBytes: garbage), isFalse);
    final fakePackage = Uint8List.fromList([0x53, 0x52, 0x45, 0x56, 0x5F, 0x54, 0x41, 0x4D, 4, 0, 0, 0, 77, 0, 0, 0, 0]);
    expect(MaterialPreviewRenderer.isFilamatPackage(fakePackage), isTrue);
    expect(MaterialPreviewRenderer.packageMaterialVersion(fakePackage), 77);
    expect(SubEditor3DViewport.usesNativePreview(glbMesh: null, previewMaterialBytes: fakePackage), isTrue);
  });

  testWidgets('MaterialSubEditor hands the compiled package and parameters to the 3D preview', (tester) async {
    final asset = LuminaAsset(
      assetId: 'M_Preview',
      name: 'M_Preview',
      type: AssetType.filamat,
      rawMatSource: _source,
    );
    // Real filamat compile (CPU only) so the preview receives a genuine package.
    final vm = MaterialEditorViewModel(
      assetPath: 'contents/materials/M_Preview.lmas',
      initialAsset: asset,
    );
    final compiled = await tester.runAsync(() => vm.compile());
    expect(compiled, isTrue);
    expect(MaterialPreviewRenderer.isFilamatPackage(vm.compiledBytes), isTrue);

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SizedBox(width: 1400, height: 800, child: MaterialSubEditor(assetName: 'M_Preview', viewModel: vm)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final viewport = tester.widget<SubEditor3DViewport>(find.byType(SubEditor3DViewport));
    expect(viewport.previewMaterialBytes, same(vm.compiledBytes));
    expect(viewport.previewMaterialParams.map((p) => p.name), containsAll(['roughness', 'metallic', 'baseColor']));
    expect(
      SubEditor3DViewport.usesNativePreview(glbMesh: viewport.glbMesh, previewMaterialBytes: viewport.previewMaterialBytes),
      isTrue,
      reason: 'material assets have no GLB payload but must still get the shaded native preview',
    );

    // Editing a parameter bumps the revision so the instance is re-synced.
    final before = viewport.previewMaterialRevision;
    vm.parameters.first.value = 0.9;
    vm.notifyListeners();
    await tester.pump(const Duration(milliseconds: 50));
    final after = tester.widget<SubEditor3DViewport>(find.byType(SubEditor3DViewport)).previewMaterialRevision;
    expect(after, greaterThan(before));
  });
}
