import 'dart:typed_data';

import 'package:flutter/widgets.dart' as widgets show Table, TableRow;
import 'package:lumina/lumina.dart' show LuminaUmgElement, LuminaUmgElementBinding, LuminaUserWidgets, LuminaThemeDocument;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import '../../models/umg_document.dart';
import '../../services/umg_widget_codegen.dart';
import 'umg_components.dart';
import 'umg_text_style.dart';
import 'umg_theme_helper.dart';

/// Renders a [UmgDocument] using real shadcn_flutter widgets and layout.
/// Used by the Play-In-Editor (PIE) viewport overlay and widget previews.
///
/// [runtimeValues] is the widget instance map `Create Widget` built: every designer element is wrapped in a
/// [LuminaUmgElement] and reads its live state (`elements[<name>]`) through
/// [LuminaUmgElementBinding], exactly as the generated widget classes do, so
/// a `Set Text (Text)` on one Text block rebuilds only that block. The
/// instance's legacy top-level `text` / `percent` (the deprecated
/// `Set Text (Widget)` / `Set Percent (Widget)`) still apply to elements
/// without their own state.
class UmgRuntimeView extends StatelessWidget {
  final UmgDocument document;
  final Map<String, Object?>? runtimeValues;
  final Map<String, Uint8List>? textureBytes;
  final void Function(String nodeId, String action)? onAction;

  /// The project uses plain Flutter widgets: shadcn
  /// components show the "requires the shadcn widget library" placeholder,
  /// as the built game cannot render them.
  final bool plainLibrary;
  final LuminaThemeDocument? theme;
  final Map<String, LuminaThemeDocument>? loadedThemes;

  const UmgRuntimeView({
    super.key,
    required this.document,
    this.runtimeValues,
    this.textureBytes,
    this.onAction,
    this.plainLibrary = false,
    this.theme,
    this.loadedThemes,
  });

  @override
  Widget build(BuildContext context) {
    final activeTheme = theme ?? LuminaThemeDocument.defaultShadcnDark();
    return Theme(
      data: UmgThemeHelper.themeDataFromLuminaDoc(activeTheme),
      child: _buildNode(document.root),
    );
  }

  /// The element event, into the instance's graph script
  /// (Play-In-Editor runs it in the VM); nothing in a designer preview.
  void _fire(UmgNode node, String event, [Map<String, Object?> args = const {}]) =>
      LuminaUserWidgets.fire(runtimeValues, node.name, event, args);

  Widget _buildNode(UmgNode node) {
    if (identical(node, document.root)) return _buildBody(node, null);
    return LuminaUmgElement(
      key: ValueKey('umg_rt_element_${node.id}'),
      instance: runtimeValues,
      name: node.name,
      builder: (context, e) => _buildBody(node, e),
    );
  }

  Widget _buildBody(UmgNode node, Map<String, Object?>? e) {
    // The Container and the shadcn components.
    if (node.type == UmgWidgetType.container) {
      final bytes = textureBytes?[node.id];
      final child = node.children.isEmpty ? null : node.children.first;
      return umgContainer(
        node,
        e,
        image: bytes == null ? null : MemoryImage(bytes),
        child: child == null ? null : Padding(padding: _padding(child.slot), child: _buildNode(child)),
      );
    }
    if (node.type.isShadcn) {
      if (plainLibrary) return umgRequiresShadcn(node);
      final key = umgShadcnValueKey(node.type);
      return umgShadcnComponent(
        node,
        e,
        children: [for (final c in node.children) Padding(padding: _padding(c.slot), child: _buildNode(c))],
        onChanged: key == null
            ? null
            : (v) {
                LuminaUmgElementBinding.write(runtimeValues, node.name, key.runtime, v);
                onAction?.call(node.id, 'OnValueChanged');
                _fire(node, 'OnValueChanged', {'value': v});
              },
        onPressed: LuminaUmgElementBinding.isEnabled(e)
            ? () {
                onAction?.call(node.id, 'OnClicked');
                _fire(node, 'OnClicked');
              }
            : null,
      );
    }
    switch (node.type) {
      case UmgWidgetType.canvasPanel:
        return _buildCanvas(node);
      case UmgWidgetType.overlay:
        return Stack(children: node.children.map(_overlayChild).toList());
      case UmgWidgetType.widgetSwitcher:
        final idx = LuminaUmgElementBinding.value<int>(e, 'activeIndex', (node.props['activeIndex'] as num?)?.toInt() ?? 0);
        return IndexedStack(
          index: node.children.isEmpty ? 0 : idx.clamp(0, node.children.length - 1),
          children: node.children.map(_overlayChild).toList(),
        );
      case UmgWidgetType.horizontalBox:
      case UmgWidgetType.verticalBox:
        final isRow = node.type == UmgWidgetType.horizontalBox;
        final children = node.children.map((c) => _boxChild(c, isRow)).toList();
        return isRow
            ? Row(mainAxisSize: MainAxisSize.max, crossAxisAlignment: CrossAxisAlignment.stretch, children: children)
            : Column(mainAxisSize: MainAxisSize.max, crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
      case UmgWidgetType.gridPanel:
        final columns = ((node.props['columns'] as num?)?.toInt() ?? 2).clamp(1, 32);
        final rows = <widgets.TableRow>[];
        for (var i = 0; i < node.children.length; i += columns) {
          rows.add(widgets.TableRow(
            children: List.generate(columns, (j) {
              final idx = i + j;
              if (idx >= node.children.length) return const SizedBox.shrink();
              final c = node.children[idx];
              return Padding(padding: _padding(c.slot), child: _buildNode(c));
            }),
          ));
        }
        return widgets.Table(children: rows);
      case UmgWidgetType.scrollBox:
        final horizontal = node.props['orientation'] == 'horizontal';
        final children = node.children.map((c) => Padding(padding: _padding(c.slot), child: _buildNode(c))).toList();
        return SingleChildScrollView(
          scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
          child: horizontal ? Row(mainAxisSize: MainAxisSize.min, children: children) : Column(mainAxisSize: MainAxisSize.min, children: children),
        );
      case UmgWidgetType.sizeBox:
        return SizedBox(
          width: _double(e, node, 'width', 200),
          height: _double(e, node, 'height', 100),
          child: node.children.isEmpty ? null : Padding(padding: _padding(node.children.first.slot), child: _buildNode(node.children.first)),
        );
      case UmgWidgetType.border:
        return Card(
          filled: true,
          fillColor: _color(e, node, 'color', '#1B1B22'),
          padding: EdgeInsets.all(_double(e, node, 'padding', 8)),
          child: node.children.isEmpty
              ? const SizedBox.expand()
              : Padding(padding: _padding(node.children.first.slot), child: _buildNode(node.children.first)),
        );
      case UmgWidgetType.button:
        final label = _string(e, node, 'label', 'Button');
        final resolvedTheme = UmgThemeHelper.resolveThemeForNode(
          node: node,
          documentTheme: theme ?? LuminaThemeDocument.defaultShadcnDark(),
          loadedThemes: loadedThemes ?? const {},
        );
        return UmgThemeHelper.buildThemedButton(
          node: node,
          theme: resolvedTheme,
          onPressed: LuminaUmgElementBinding.isEnabled(e)
              ? () {
                  onAction?.call(node.id, 'clicked');
                  _fire(node, 'OnClicked');
                }
              : null,
          onHover: (hovering) => _fire(node, hovering ? 'OnHovered' : 'OnUnhovered'),
          child: umgText(label, node.props, e),
        );
      case UmgWidgetType.text:
        final legacy = (e == null) ? _legacyText() : null;
        final String text;
        if (legacy != null && legacy.isNotEmpty) {
          text = legacy;
        } else {
          text = _string(e, node, 'text', '');
        }
        return umgText(text, node.props, e);
      case UmgWidgetType.image:
        final bytes = textureBytes?[node.id];
        if (bytes == null) {
          return Container(
            decoration: BoxDecoration(
              border: Border.all(color: EditorColors.mutedForeground.withValues(alpha: 0.6)),
              color: EditorColors.placeholderFill,
            ),
            child: const Center(child: Icon(LucideIcons.image, size: 20, color: EditorColors.mutedForeground)),
          );
        }
        return Image.memory(
          bytes,
          fit: _drawAsFit(node.props['drawAs']),
          color: _color(e, node, 'color', '#FFFFFF'),
          colorBlendMode: BlendMode.modulate,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const Center(child: Icon(LucideIcons.imageOff, size: 20, color: EditorColors.logError)),
        );
      case UmgWidgetType.progressBar:
        final legacy = (e == null) ? _legacyPercent() : null;
        final pct = legacy ?? _double(e, node, 'percent', 0.5);
        return Progress(progress: pct.clamp(0.0, 1.0), color: _color(e, node, 'fillColor', node.props['color']?.toString() ?? '#4ADE80'));
      case UmgWidgetType.slider:
        return Slider(
          value: SliderValue.single(_double(e, node, 'value', 0.5).clamp(0.0, 1.0)),
          onChanged: (v) {
            LuminaUmgElementBinding.write(runtimeValues, node.name, 'value', v.value);
            onAction?.call(node.id, 'changed');
            _fire(node, 'OnValueChanged', {'value': v.value});
          },
        );
      case UmgWidgetType.checkBox:
        final checked = LuminaUmgElementBinding.value<bool>(e, 'isChecked', node.props['checked'] == true);
        return Checkbox(
          state: checked ? CheckboxState.checked : CheckboxState.unchecked,
          onChanged: (v) {
            LuminaUmgElementBinding.write(runtimeValues, node.name, 'isChecked', v == CheckboxState.checked);
            onAction?.call(node.id, 'toggled');
            _fire(node, 'OnValueChanged', {'value': v == CheckboxState.checked});
          },
          trailing: umgText(_string(e, node, 'label', ''), node.props, e),
        );
      case UmgWidgetType.editableText:
        return TextField(
          key: ValueKey('umg_rt_field_${node.id}'),
          initialValue: node.props['text']?.toString() ?? '',
          placeholder: Text(_string(e, node, 'hintText', node.props['hint']?.toString() ?? '')),
          style: umgTextStyle(node.props, e, outlineRing: true),
          onChanged: (v) {
            LuminaUmgElementBinding.write(runtimeValues, node.name, 'text', v);
            onAction?.call(node.id, 'text_changed');
            _fire(node, 'OnValueChanged', {'value': v});
          },
          onSubmitted: (v) => _fire(node, 'OnTextCommitted', {'text': v, 'commit_method': 'OnEnter'}),
        );
      case UmgWidgetType.comboBox:
        final designer = (node.props['options']?.toString() ?? '')
            .split(',')
            .map((o) => o.trim())
            .where((o) => o.isNotEmpty)
            .toList();
        final options = LuminaUmgElementBinding.options(e, designer);
        final selected = LuminaUmgElementBinding.value<String?>(e, 'selectedOption', node.props['selected']?.toString());
        return Select<String>(
          value: options.contains(selected) ? selected : null,
          onChanged: (v) {
            LuminaUmgElementBinding.write(runtimeValues, node.name, 'selectedOption', v);
            onAction?.call(node.id, 'selected');
            _fire(node, 'OnValueChanged', {'value': v});
          },
          itemBuilder: (context, item) => umgText(item, node.props, e),
          popup: SelectPopup(
            items: SelectItemList(children: [for (final o in options) SelectItemButton(value: o, child: Text(o))]),
          ).call,
        );
      default:
        return const SizedBox.shrink(); // Container and shadcn: handled above
    }
  }

  Widget _buildCanvas(UmgNode node) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : document.logicalSize.width,
          constraints.hasBoundedHeight ? constraints.maxHeight : document.logicalSize.height,
        );
        final children = List<UmgNode>.from(node.children)
          ..sort((a, b) => a.slot.zOrder.compareTo(b.slot.zOrder));
        return Stack(
          key: ValueKey('umg_canvas_stack_${node.id}'),
          clipBehavior: Clip.none,
          children: [
            for (final c in children)
              () {
                final r = UmgLayout.resolveCanvasRect(c.slot, size);
                return Positioned(
                  key: ValueKey('umg_canvas_child_${c.id}'),
                  left: r.left,
                  top: r.top,
                  width: c.slot.sizeToContent ? null : r.width,
                  height: c.slot.sizeToContent ? null : r.height,
                  child: _buildNode(c),
                );
              }(),
          ],
        );
      },
    );
  }

  Widget _overlayChild(UmgNode c) {
    final s = c.slot;
    final child = _buildNode(c);
    if (s.hAlign == UmgAlign.fill && s.vAlign == UmgAlign.fill) {
      return Positioned.fill(child: Padding(padding: _padding(s), child: child));
    }
    final sized = (s.hAlign == UmgAlign.fill || s.vAlign == UmgAlign.fill)
        ? SizedBox(
            width: s.hAlign == UmgAlign.fill ? double.infinity : null,
            height: s.vAlign == UmgAlign.fill ? double.infinity : null,
            child: child,
          )
        : child;
    return Positioned.fill(
      child: Padding(
        padding: _padding(s),
        child: Align(alignment: _alignment(s), child: sized),
      ),
    );
  }

  Widget _boxChild(UmgNode c, bool isRow) {
    final s = c.slot;
    Widget child = _buildNode(c);
    final cross = isRow ? s.vAlign : s.hAlign;
    if (cross != UmgAlign.fill) {
      child = Align(
        alignment: isRow ? Alignment(0, _alignValue(cross)) : Alignment(_alignValue(cross), 0),
        child: child,
      );
    }
    child = Padding(padding: _padding(s), child: child);
    if (s.fill) {
      child = Expanded(flex: (s.flex * 100).round().clamp(1, 100000), child: child);
    }
    return child;
  }

  /// The deprecated instance-level `text` (`Set Text (Widget)`).
  String? _legacyText() {
    final v = runtimeValues?['text'];
    return v?.toString();
  }

  /// The deprecated instance-level `percent` (`Set Percent (Widget)`).
  double? _legacyPercent() {
    final v = runtimeValues?['percent'];
    return v is num ? v.toDouble() : null;
  }

  // Element-state reads: the runtime value under [key], else the designer's.
  String _string(Map<String, Object?>? e, UmgNode n, String key, String fallback) =>
      LuminaUmgElementBinding.value<String>(e, key, n.props[key]?.toString() ?? fallback);

  double _double(Map<String, Object?>? e, UmgNode n, String key, double fallback) =>
      LuminaUmgElementBinding.value<double>(e, key, _num(n.props[key], fallback));

  Color _color(Map<String, Object?>? e, UmgNode n, String key, String fallback) =>
      LuminaUmgElementBinding.color(
        e,
        key,
        UmgWidgetCodegen.parseHexColor(n.props[key]?.toString() ?? '') ?? UmgWidgetCodegen.parseHexColor(fallback)!,
      );

  double _num(dynamic v, double fallback) =>
      v is num ? v.toDouble() : (double.tryParse(v?.toString() ?? '') ?? fallback);

  EdgeInsets _padding(UmgSlot s) =>
      EdgeInsets.fromLTRB(s.paddingLeft, s.paddingTop, s.paddingRight, s.paddingBottom);

  Alignment _alignment(UmgSlot s) => Alignment(_alignValue(s.hAlign), _alignValue(s.vAlign));

  double _alignValue(UmgAlign a) {
    switch (a) {
      case UmgAlign.start:
        return -1;
      case UmgAlign.center:
      case UmgAlign.fill:
        return 0;
      case UmgAlign.end:
        return 1;
    }
  }



  BoxFit _drawAsFit(dynamic v) {
    switch (v?.toString()) {
      case 'box':
        return BoxFit.fill;
      case 'border':
        return BoxFit.cover;
      default:
        return BoxFit.contain;
    }
  }
}
