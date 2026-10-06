import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../theme/editor_theme.dart';
import 'plugin_view_scope.dart';

/// [PluginControlKind.log]: `lines` (newest last) in a scrollable monospace
/// box that keeps the newest `maxLines` (default 200), `height` (default
/// 160). It follows new lines while scrolled to the bottom and stays put
/// while the user reads further up. The text is selectable.
class PluginLogControl extends StatefulWidget {
  const PluginLogControl({super.key, required this.control});

  final PluginControl control;

  static const int defaultMaxLines = 200;

  /// The lines shown: the newest `maxLines` of `lines`.
  static List<String> keptLines(PluginControl c) {
    final lines = [for (final l in c.list('lines') ?? const []) '$l'];
    final max = (c.number('maxLines')?.toInt() ?? defaultMaxLines).clamp(1, 100000);
    return lines.length <= max ? lines : lines.sublist(lines.length - max);
  }

  @override
  State<PluginLogControl> createState() => _PluginLogControlState();
}

class _PluginLogControlState extends State<PluginLogControl> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _toBottom();
  }

  @override
  void didUpdateWidget(PluginLogControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    final atBottom = !_scroll.hasClients || _scroll.offset >= _scroll.position.maxScrollExtent - 4;
    if (atBottom) _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.control;
    final lines = PluginLogControl.keptLines(c);
    final height = c.number('height')?.toDouble() ?? 160;
    final box = Container(
      height: height,
      decoration: BoxDecoration(
        color: EditorColors.viewportBackdrop,
        border: Border.all(color: EditorColors.border),
        borderRadius: BorderRadius.circular(3),
      ),
      child: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          width: double.infinity,
          child: SelectableRegion(
            selectionControls: shadcnTextSelectionHandleControls,
            child: Text(
              lines.join('\n'),
              key: ValueKey('${PluginViewScope.of(context).keyOf(c.id).value}/text'),
              style: EditorTypography.mono(fontSize: EditorTypography.captionSize, color: EditorColors.secondaryForeground),
            ),
          ),
        ),
      ),
    );
    return withPluginTooltip(c.tooltip, PluginFieldRow(label: c.label, alignTop: true, child: box));
  }
}
