import 'package:lumina_editor_data/lumina_editor.dart';

/// Represents a 3D mesh component (such as a skeletal or static mesh)
/// positioned within an actor composite preview in [SubEditor3DViewport].
class SubEditorMeshComponent {
  final String id;
  final String name;
  final GlbMeshData glbMesh;
  final List<double> location;
  final List<double> rotation;
  final List<double> scale;
  final bool isVisible;

  const SubEditorMeshComponent({
    required this.id,
    required this.name,
    required this.glbMesh,
    this.location = const [0.0, 0.0, 0.0],
    this.rotation = const [0.0, 0.0, 0.0],
    this.scale = const [1.0, 1.0, 1.0],
    this.isVisible = true,
  });
}
