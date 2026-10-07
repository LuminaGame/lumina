import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';

void main() {
  GlbMeshData makeFakeMesh({
    required List<double> minBounds,
    required List<double> maxBounds,
  }) {
    return GlbMeshData(
      positions: Float32List.fromList([
        minBounds[0], minBounds[1], minBounds[2],
        maxBounds[0], maxBounds[1], maxBounds[2],
        minBounds[0], maxBounds[1], minBounds[2],
      ]),
      indices: Uint32List.fromList([0, 1, 2]),
      minBounds: minBounds,
      maxBounds: maxBounds,
    );
  }

  test('SubEditorMeshComponent carries component id, transforms, and glbMesh', () {
    final mesh = makeFakeMesh(
      minBounds: [-1.0, -1.0, -1.0],
      maxBounds: [1.0, 1.0, 1.0],
    );
    final comp = SubEditorMeshComponent(
      id: 'mesh_body',
      name: 'Mesh',
      glbMesh: mesh,
      location: [0.0, 0.0, -0.9],
      rotation: [0.0, -90.0, 0.0],
      scale: [1.0, 1.0, 1.0],
    );

    expect(comp.id, 'mesh_body');
    expect(comp.name, 'Mesh');
    expect(comp.glbMesh, mesh);
    expect(comp.location, [0.0, 0.0, -0.9]);
    expect(comp.rotation, [0.0, -90.0, 0.0]);
    expect(comp.scale, [1.0, 1.0, 1.0]);
    expect(comp.isVisible, isTrue);
  });

  testWidgets('SubEditor3DViewport accepts meshComponents and renders without errors', (tester) async {
    final mesh1 = makeFakeMesh(
      minBounds: [-0.3, 0.0, -0.2],
      maxBounds: [0.3, 1.4, 0.2],
    );
    final mesh2 = makeFakeMesh(
      minBounds: [-0.15, 1.4, -0.1],
      maxBounds: [0.15, 1.8, 0.15],
    );

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SubEditor3DViewport(
            title: 'Blueprint Actor 3D Preview',
            meshComponents: [
              SubEditorMeshComponent(
                id: 'body',
                name: 'Mesh_Body',
                glbMesh: mesh1,
                location: [0.0, 0.0, 0.0],
              ),
              SubEditorMeshComponent(
                id: 'face',
                name: 'Mesh_Face',
                glbMesh: mesh2,
                location: [0.0, 0.0, 0.0],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(SubEditor3DViewport), findsOneWidget);
    // CustomPaint fallback renders when native Filament is unmounted in widget test
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
