import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Monospace GLSL Source Editor with line number gutter and parameter autocomplete.
class MaterialGlslEditorWidget extends StatefulWidget {
  final MaterialEditorViewModel viewModel;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ScrollController? scrollController;

  const MaterialGlslEditorWidget({
    super.key,
    required this.viewModel,
    required this.controller,
    required this.focusNode,
    this.scrollController,
  });

  @override
  State<MaterialGlslEditorWidget> createState() => MaterialGlslEditorWidgetState();
}

class MaterialGlslEditorWidgetState extends State<MaterialGlslEditorWidget> {
  late final ScrollController _scrollController;
  final ScrollController _gutterScrollController = ScrollController();

  List<String> _autocompleteSuggestions = [];
  bool _showAutocomplete = false;
  int _selectedSuggestionIndex = 0;

  static const List<String> _glslKeywords = [
    'material.baseColor',
    'material.roughness',
    'material.metallic',
    'material.normal',
    'material.emissive',
    'material.ambientOcclusion',
    'material.clearCoat',
    'material.clearCoatRoughness',
    'prepareMaterial(material);',
    'shadingModel : lit',
    'shadingModel : unlit',
    'shadingModel : cloth',
    'shadingModel : subsurface',
    'blending : opaque',
    'blending : transparent',
    'blending : masked',
    'blending : add',
    'vec4(1.0, 1.0, 1.0, 1.0)',
    'vec3(0.0, 0.0, 1.0)',
    'vec2(0.0, 0.0)',
    'texture(materialParams_albedoMap, getUV0())',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    widget.controller.addListener(_onTextChanged);
  }

  bool _isSyncingScroll = false;

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    _gutterScrollController.dispose();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (_isSyncingScroll) return false;
    if (_gutterScrollController.hasClients) {
      if ((_gutterScrollController.offset - notification.metrics.pixels).abs() > 0.5) {
        _isSyncingScroll = true;
        _gutterScrollController.jumpTo(notification.metrics.pixels);
        _isSyncingScroll = false;
      }
    }
    return false;
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    if (widget.viewModel.currentCode != text) {
      widget.viewModel.updateCodeFromEditor(text);
    }
    _checkAutocomplete(text);
  }

  void _checkAutocomplete(String text) {
    if (!widget.focusNode.hasFocus) {
      if (_showAutocomplete) {
        setState(() => _showAutocomplete = false);
      }
      return;
    }
    final selection = widget.controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      if (_showAutocomplete) setState(() => _showAutocomplete = false);
      return;
    }

    final pos = selection.baseOffset;
    if (pos <= 0 || pos > text.length) {
      if (_showAutocomplete) setState(() => _showAutocomplete = false);
      return;
    }

    int start = pos - 1;
    while (start >= 0 && RegExp(r'[a-zA-Z0-9_.]').hasMatch(text[start])) {
      start--;
    }
    start++;

    final currentToken = text.substring(start, pos).toLowerCase();
    if (currentToken.length >= 2) {
      final declaredParams = widget.viewModel.extractDeclaredParameters();
      final allCandidates = <String>{..._glslKeywords, ...declaredParams}.toList();

      final matches = allCandidates
          .where((k) => k.toLowerCase().contains(currentToken))
          .take(8)
          .toList();

      setState(() {
        _autocompleteSuggestions = matches;
        _showAutocomplete = matches.isNotEmpty;
        _selectedSuggestionIndex = 0;
      });
    } else {
      if (_showAutocomplete) {
        setState(() => _showAutocomplete = false);
      }
    }
  }

  void _insertSuggestion(String suggestion) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final pos = selection.baseOffset;

    int start = pos - 1;
    while (start >= 0 && RegExp(r'[a-zA-Z0-9_.]').hasMatch(text[start])) {
      start--;
    }
    start++;

    final newText = text.replaceRange(start, pos, suggestion);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + suggestion.length),
    );
    setState(() => _showAutocomplete = false);
    widget.focusNode.requestFocus();
  }

  /// Jumps the editor cursor to a specific 1-indexed line number.
  void jumpToLine(int line1Indexed) {
    final text = widget.controller.text;
    final lines = text.split('\n');
    if (line1Indexed < 1) line1Indexed = 1;
    if (line1Indexed > lines.length) line1Indexed = lines.length;

    int charOffset = 0;
    for (int i = 0; i < line1Indexed - 1; i++) {
      charOffset += lines[i].length + 1; // +1 for newline
    }

    final targetLineLength = lines[line1Indexed - 1].length;
    widget.controller.selection = TextSelection(
      baseOffset: charOffset,
      extentOffset: charOffset + targetLineLength,
    );
    widget.focusNode.requestFocus();

    // Scroll roughly to line
    if (_scrollController.hasClients) {
      final double estimatedLineHeight = 20.0;
      final targetScroll = (line1Indexed - 1) * estimatedLineHeight;
      _scrollController.animateTo(
        targetScroll.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = widget.controller.text;
    final lines = text.split('\n');
    final lineCount = lines.isEmpty ? 1 : lines.length;

    return Stack(
      children: [
        Container(
          color: theme.colorScheme.background,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Line Number Gutter
              Container(
                width: 48,
                padding: const EdgeInsets.only(top: 8, right: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.card,
                  border: Border(
                    right: BorderSide(color: theme.colorScheme.border),
                  ),
                ),
                child: ListView.builder(
                  controller: _gutterScrollController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: lineCount,
                  itemBuilder: (context, index) {
                    final lineNum = index + 1;
                    final hasIssue = widget.viewModel.issues.any((i) => i.line == lineNum);
                    return SizedBox(
                      height: 20,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (hasIssue)
                            Container(
                              width: 4,
                              height: 12,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.destructive,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          Text(
                            '$lineNum',
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: EditorTypography.monoFamily,
                              color: hasIssue
                                  ? theme.colorScheme.destructive
                                  : theme.colorScheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Code Area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onScrollNotification,
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      scrollController: _scrollController,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(
                        fontFamily: EditorTypography.monoFamily,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Autocomplete Overlay
        if (_showAutocomplete && _autocompleteSuggestions.isNotEmpty)
          Positioned(
            left: 60,
            bottom: 20,
            child: Card(
              child: Container(
                width: 320,
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Suggestions', style: TextStyle(fontSize: 10)).muted(),
                          const Text('Tab / Click to insert', style: TextStyle(fontSize: 10)).muted(),
                        ],
                      ),
                    ),
                    const Divider(),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _autocompleteSuggestions.length,
                        itemBuilder: (context, index) {
                          final item = _autocompleteSuggestions[index];
                          final isSelected = index == _selectedSuggestionIndex;
                          return Clickable(
                            onPressed: () => _insertSuggestion(item),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              color: isSelected
                                  ? theme.colorScheme.primary.withValues(alpha: 0.15)
                                  : null,
                              child: Text(
                                item,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: EditorTypography.monoFamily,
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.foreground,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
