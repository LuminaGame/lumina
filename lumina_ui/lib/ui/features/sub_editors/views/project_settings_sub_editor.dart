import 'package:file_picker/file_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart' show ProjectSettingsSection;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/build_pipeline_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/project_icon_rasterizer.dart';
import 'package:lumina_ui/ui/features/sub_editors/sub_editor_binding.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/project_settings_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/project_settings/key_binding_dialog.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/project_settings/web_loading_style_section.dart';

part 'project_settings/sub_editor/state.dart';
part 'project_settings/sub_editor/layout.dart';
part 'project_settings/sub_editor/description.dart';
part 'project_settings/sub_editor/categories.dart';
part 'project_settings/sub_editor/input.dart';
part 'project_settings/sub_editor/packaging.dart';

/// Project Settings: split view over the real `.lmproject`.
///
/// Left: searchable category list with validation badges. Right: the
/// category's editors. Footer: dirty indicator, Revert, Apply & Save. Every
/// control edits the view model's working copy instantly; only Apply writes
/// the manifest and pushes graphics settings to the editor.
class ProjectSettingsSubEditor extends StatefulWidget {
  final String assetName;
  final String? projectDirPath;
  final LuminaProject? initialProject;
  final void Function(LuminaProject saved)? onApplied;
  final VoidCallback? onClose;
  final SubEditorBindCallback? onBind;
  final ProjectSettingsViewModel? viewModel;

  /// The plugins' pages, as (plugin, section).
  final List<(String, ProjectSettingsSection)> pluginSections;

  /// Package Project's code-generation pass; the editor passes its own
  /// save-and-generate so unsaved actors are packaged too.
  final CookCodeGenerator? codeGenerator;

  const ProjectSettingsSubEditor({
    super.key,
    required this.assetName,
    this.projectDirPath,
    this.initialProject,
    this.onApplied,
    this.onClose,
    this.onBind,
    this.viewModel,
    this.codeGenerator,
    this.pluginSections = const [],
  });

  @override
  State<ProjectSettingsSubEditor> createState() => _ProjectSettingsSubEditorState();
}

class _ProjectSettingsSubEditorState extends _ProjectSettingsSubEditorStateBase
    with
        _ProjectSettingsLayout,
        _ProjectSettingsDescription,
        _ProjectSettingsCategories,
        _ProjectSettingsInput,
        _ProjectSettingsPackaging {

  @override
  void initState() {
    super.initState();
    _ownsVm = widget.viewModel == null;
    _vm = widget.viewModel ??
        ProjectSettingsViewModel(
          projectDirPath: widget.projectDirPath ?? '',
          initialProject: widget.initialProject,
          codeGenerator: widget.codeGenerator,
        );
    _vm.onApplied = widget.onApplied;
    if (widget.pluginSections.isNotEmpty) _vm.pluginSections = widget.pluginSections;
    _vm.addListener(_onVmChanged);
    widget.onBind?.call(_vm, _vm.apply, () => _vm.isDirty);
    if (_ownsVm && widget.projectDirPath != null && widget.projectDirPath!.isNotEmpty) {
      _vm.load();
    }
  }

  void _onVmChanged() {
    if (!mounted) return;
    setState(() {});
  }

  /// The view model driving this editor (integration tests reach the live
  /// instance through the widget state).
  @visibleForTesting
  ProjectSettingsViewModel get viewModelForTest => _vm;

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    _searchController.dispose();
    _packagingScroll.dispose();
    if (_ownsVm) _vm.dispose();
    super.dispose();
  }

  /// A controller whose text follows [value] unless the field is focused.
  @override
  TextEditingController _controllerFor(String id, String value) {
    final c = _controllers.putIfAbsent(id, () => TextEditingController(text: value));
    final f = _focus.putIfAbsent(id, () => FocusNode());
    if (!f.hasFocus && c.text != value) {
      c.text = value;
    }
    return c;
  }

  @override
  FocusNode _focusFor(String id) => _focus.putIfAbsent(id, () => FocusNode());

  // ---------------------------------------------------------------- layout

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _vm.isLoading
              ? const Center(child: CircularProgressIndicator())
              : !_vm.hasProject
                  ? _buildLoadError()
                  : Row(
                      children: [
                        _buildNav(),
                        const VerticalDivider(width: 1),
                        Expanded(child: _buildCategoryBody()),
                      ],
                    ),
        ),
        const Divider(height: 1),
        _buildFooter(),
      ],
    );
  }
}
