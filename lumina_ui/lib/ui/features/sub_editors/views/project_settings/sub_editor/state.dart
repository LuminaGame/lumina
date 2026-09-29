part of '../../project_settings_sub_editor.dart';

/// State shared by the Project Settings editor's layout and category mixins.
abstract class _ProjectSettingsSubEditorStateBase extends State<ProjectSettingsSubEditor> {
  late final ProjectSettingsViewModel _vm;
  late final bool _ownsVm;
  String _activeCategory = ProjectSettingsCategory.description;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focus = {};
  final TextEditingController _searchController = TextEditingController();
  int? _capturingContext;
  int? _capturingMapping;
  final FocusNode _captureFocus = FocusNode(debugLabel: 'project_settings_key_capture');

  final ScrollController _packagingScroll = ScrollController();

  // --- Implemented by the domain mixins or [_ProjectSettingsSubEditorState]. ---

  TextEditingController _controllerFor(String id, String value);

  FocusNode _focusFor(String id);

  Widget _section(String title, List<Widget> children);

  Widget _row(String label, Widget control, {String? help});

  Widget _select(String value, List<String> options, void Function(String) onChanged, {String Function(String)? label});

  Widget _buildDescription();

  Widget _buildGraphics();

  Widget _buildInput();

  Widget _buildMapsAndModes();

  Widget _buildPhysics();

  Widget _buildUserInterface();

  Widget _buildPackaging();
}
