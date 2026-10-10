part of '../outliner_widget.dart';

/// Filter, rename, drag-hover, tap and scroll state shared by the World
/// Outliner's mixins.
abstract class _OutlinerWidgetStateBase extends State<OutlinerWidget> {
  String _filterQuery = '';
  String? _editingId;
  bool _renameHadFocus = false;
  final TextEditingController _renameController = TextEditingController();
  final FocusNode _renameFocusNode = FocusNode();

  Timer? _hoverExpandTimer;
  String? _hoverExpandId;

  String? _lastTapId;
  DateTime? _lastTapAt;
  String? _selectionAnchorId;

  // The row being renamed, or the newly selected one, is scrolled into view.
  final ScrollController _scrollController = ScrollController();
  String? _lastScrolledTo;

  EditorViewModel get _vm => widget.viewModel;
}
