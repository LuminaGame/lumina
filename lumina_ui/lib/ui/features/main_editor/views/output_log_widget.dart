import 'package:flutter/services.dart';
import 'package:lumina/lumina.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../../core/theme/editor_theme.dart';
import '../view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/core/widgets/editor_context_menu.dart';

class OutputLogWidget extends StatefulWidget {
  final EditorViewModel viewModel;

  const OutputLogWidget({super.key, required this.viewModel});

  @override
  State<OutputLogWidget> createState() => _OutputLogWidgetState();
}

class _OutputLogWidgetState extends State<OutputLogWidget> {
  /// The level shown, kept on the view model so the import panel's "Show
  /// errors" can set it.
  String get _activeFilter => widget.viewModel.outputLogFilter.value;

  /// The log follows its newest line while scrolled to the bottom — a
  /// streamed game or build log stays in view; scrolling up to read stops
  /// following.
  final ScrollController _scroll = ScrollController();
  bool _follow = true;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    widget.viewModel.outputLogFilter.addListener(_onFilterChanged);
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final p = _scroll.position;
      _follow = p.pixels >= p.maxScrollExtent - 24;
    });
  }

  @override
  void dispose() {
    widget.viewModel.outputLogFilter.removeListener(_onFilterChanged);
    _scroll.dispose();
    _command.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    if (mounted) setState(() {});
  }

  void _followTail(int count) {
    if (count == _lastCount) return;
    _lastCount = count;
    if (!_follow) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _copyAllLogs(List<EngineLogEntry> filteredLogs) {
    final text = filteredLogs
        .map((l) => '${l.timestamp} [${l.source}] ${l.message}')
        .join('\n');
    Clipboard.setData(ClipboardData(text: text));
  }

  void _copySingleLog(EngineLogEntry entry) {
    final text = '${entry.timestamp} [${entry.source}] ${entry.message}';
    Clipboard.setData(ClipboardData(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final logs = widget.viewModel.logs;
    final filtered = _activeFilter == 'all'
        ? logs
        : logs.where((l) => l.level == _activeFilter).toList();
    _followTail(filtered.length);

    return Column(
      children: [
        // Output Log Toolbar Header
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: EditorColors.cardHeader,
          child: Row(
            children: [
              for (final filter in ['all', 'info', 'warning', 'error', 'success'])
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Button(
                    style: _activeFilter == filter
                        ? const ButtonStyle.primary()
                        : const ButtonStyle.ghost(),
                    onPressed: () => widget.viewModel.outputLogFilter.value = filter,
                    child: Text(
                      filter.toUpperCase(),
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              const Spacer(),

              // Copy All Logs Button
              GhostButton(
                onPressed: () => _copyAllLogs(filtered),
                child: const Row(
                  children: [
                    Icon(LucideIcons.copy, size: 10, color: EditorColors.primary),
                    SizedBox(width: 4),
                    Text('Copy All', style: TextStyle(fontSize: 9, color: EditorColors.primary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Clear Log Button
              GhostButton(
                onPressed: () => widget.viewModel.clearLogs(),
                child: const Row(
                  children: [
                    Icon(LucideIcons.trash2, size: 10, color: EditorColors.logError),
                    SizedBox(width: 4),
                    Text('Clear Log', style: TextStyle(fontSize: 9, color: EditorColors.logError)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Selectable Log Items Viewport
        Expanded(
          // shadcn_flutter 0.0.54 installs no Material ancestors, so Material's
          // SelectionArea (which needs MaterialLocalizations) is replaced by the
          // widgets-layer region with shadcn's handle-less controls.
          child: SelectableRegion(
            selectionControls: shadcnTextSelectionHandleControls,
            child: ListView.builder(
              key: const ValueKey('output_log_list'),
              controller: _scroll,
              padding: const EdgeInsets.all(4),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final entry = filtered[index];
                return EditorContextMenu(
                  items: [
                    MenuButton(
                      leading: const Icon(LucideIcons.copy, size: 12),
                      onPressed: (ctx) => _copySingleLog(entry),
                      child: const Text('Copy Log Line', style: TextStyle(fontSize: 10)),
                    ),
                    MenuButton(
                      leading: const Icon(LucideIcons.copy, size: 12, color: Colors.cyan),
                      onPressed: (ctx) => _copyAllLogs(filtered),
                      child: const Text('Copy All Filtered Logs', style: TextStyle(fontSize: 10)),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: EditorColors.border, width: 0.5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(_getLogLevelIcon(entry.level), size: 11, color: _getLogLevelColor(entry.level)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          entry.timestamp,
                          style: const TextStyle(fontSize: 9, fontFamily: EditorTypography.monoFamily, color: EditorColors.mutedForeground),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '[${entry.source}]',
                          style: const TextStyle(fontSize: 9, fontFamily: EditorTypography.monoFamily, fontWeight: FontWeight.bold, color: EditorColors.primary),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.message,
                            style: TextStyle(fontSize: 9, fontFamily: EditorTypography.monoFamily, color: _getLogLevelColor(entry.level)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // The console command line (plugin console commands;
        // `help` lists them). Enter runs, Up / Down walk the history.
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: const BoxDecoration(
            color: EditorColors.cardHeader,
            border: Border(top: BorderSide(color: EditorColors.border, width: 0.5)),
          ),
          child: Row(
            children: [
              const Text('>', style: TextStyle(fontSize: 10, fontFamily: EditorTypography.monoFamily, color: EditorColors.primary)),
              const SizedBox(width: 6),
              Expanded(
                child: Focus(
                  onKeyEvent: _onCommandKey,
                  child: TextField(
                    key: const ValueKey('output_log_command'),
                    controller: _command,
                    placeholder: const Text('Console command (help)', style: TextStyle(fontSize: 9)),
                    style: const TextStyle(fontSize: 9.5, fontFamily: EditorTypography.monoFamily),
                    onSubmitted: (_) => _runCommand(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  final TextEditingController _command = TextEditingController();
  final List<String> _history = [];
  int _historyIndex = 0;

  void _runCommand() {
    final line = _command.text.trim();
    if (line.isEmpty) return;
    if (_history.isEmpty || _history.last != line) _history.add(line);
    _historyIndex = _history.length;
    _command.clear();
    widget.viewModel.runConsoleCommand(line);
  }

  KeyEventResult _onCommandKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _history.isEmpty) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _historyIndex = (_historyIndex - 1).clamp(0, _history.length - 1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _historyIndex = (_historyIndex + 1).clamp(0, _history.length);
    } else {
      return KeyEventResult.ignored;
    }
    final text = _historyIndex < _history.length ? _history[_historyIndex] : '';
    _command.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    return KeyEventResult.handled;
  }

  IconData _getLogLevelIcon(String level) {
    switch (level) {
      case 'warning':
        return LucideIcons.triangleAlert;
      case 'error':
        return LucideIcons.circleX;
      case 'success':
        return LucideIcons.circleCheck;
      default:
        return LucideIcons.info;
    }
  }

  Color _getLogLevelColor(String level) {
    switch (level) {
      case 'warning':
        return EditorColors.logWarning;
      case 'error':
        return EditorColors.logError;
      case 'success':
        return EditorColors.logSuccess;
      default:
        return EditorColors.foreground;
    }
  }
}
