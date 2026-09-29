part of '../content_browser_widget.dart';

/// Search, focus and selection state shared by the Content Browser's
/// mixins.
abstract class _ContentBrowserWidgetStateBase extends State<ContentBrowserWidget> {

  Timer? _searchDebouncer;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  /// The browser's keyboard focus (Ctrl+F, Delete). Taken on a click, never at
  /// start-up: the editor opens with the viewport focused.
  final FocusNode _browserFocusNode = FocusNode(debugLabel: 'ContentBrowser');

  final double _iconSize = 64.0;
  final Set<String> _selectedAssetPaths = {};

  /// The folder tile a single click highlighted.
  String? _selectedFolderTile;
  String? _lastSelectedAssetPath;

  /// The last "Browse to asset" request applied.
  int _handledRevealSerial = 0;

  final GlobalKey _importButtonKey = GlobalKey(debugLabel: 'content_browser_import');

  // --- Implemented by the domain mixins or [_ContentBrowserWidgetState]. ---

  String _displayName(String fileName);

  IconData _getAssetIcon(AssetType type);

  Color _getAssetColor(AssetType type);

  void _showCreateBlueprintDialog(BuildContext context, EditorViewModel? vm);
}
