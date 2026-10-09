part of '../texture_sub_editor.dart';

/// The editor's state shared by its sidebars and canvas.
abstract class _TextureSubEditorStateBase extends State<TextureSubEditor> {
  late final TextureEditorViewModel _viewModel;
  late final bool _ownsViewModel;
}
