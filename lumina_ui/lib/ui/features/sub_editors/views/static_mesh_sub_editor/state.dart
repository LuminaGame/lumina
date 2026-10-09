part of '../static_mesh_sub_editor.dart';

/// The editor's state shared by its toolbar and panels.
abstract class _StaticMeshSubEditorStateBase extends State<StaticMeshSubEditor> {
  late final StaticMeshEditorViewModel _viewModel;
  late final bool _ownsViewModel;

  final GlobalKey _collisionBtnKey = GlobalKey();
  final GlobalKey _forcedLodBtnKey = GlobalKey();
  int _activeLeftTab = 0; // 0: Stats, 1: LODs, 2: Hierarchy
  GlbNode? _selectedNode;
}
