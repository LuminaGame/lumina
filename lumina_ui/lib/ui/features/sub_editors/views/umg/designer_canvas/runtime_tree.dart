part of '../designer_canvas.dart';

/// Maps document nodes to real shadcn_flutter widgets (same registry as
/// [UmgWidgetCodegen], executed live).
class _UmgRuntimeTree extends StatelessWidget {
  final UmgEditorViewModel vm;
  final GlobalKey Function(String id) keyFor;
  final VoidCallback onInteraction;

  /// A plain-Flutter project previews the runtime's widgets.
  final bool plainWidgets;

  const _UmgRuntimeTree({required this.vm, required this.keyFor, required this.onInteraction, required this.plainWidgets});

  @override
  Widget build(BuildContext context) => Theme(
        data: vm.activeThemeData,
        child: _build(vm.document.root),
      );

  Widget _measured(UmgNode node, Widget child) {
    return KeyedSubtree(
      key: ValueKey('umg_rt_${node.id}'),
      child: SizedBox.expand(key: keyFor(node.id), child: child),
    );
  }

  Widget _measuredTight(UmgNode node, Widget child) {
    return KeyedSubtree(
      key: ValueKey('umg_rt_${node.id}'),
      child: Container(key: keyFor(node.id), child: child),
    );
  }

  Color _color(UmgNode n, String fallback) => UmgWidgetCodegen.parseHexColor(n.props['color']?.toString() ?? '') ?? UmgWidgetCodegen.parseHexColor(fallback)!;

  double _num(dynamic v, double fallback) => v is num ? v.toDouble() : (double.tryParse(v?.toString() ?? '') ?? fallback);

  EdgeInsets _padding(UmgSlot s) => EdgeInsets.fromLTRB(s.paddingLeft, s.paddingTop, s.paddingRight, s.paddingBottom);

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


  Widget _build(UmgNode node) {
    // The Container is Flutter's in both libraries; a shadcn
    // component needs the shadcn library, a plain project shows why not.
    if (node.type == UmgWidgetType.container) {
      final bytes = vm.textureBytesFor(node.id);
      final child = node.children.isEmpty ? null : node.children.first;
      return umgContainer(
        node,
        null,
        image: bytes == null ? null : MemoryImage(bytes),
        child: child == null ? null : Padding(padding: _padding(child.slot), child: _measuredTight(child, _build(child))),
      );
    }
    if (node.type.isShadcn) {
      if (plainWidgets) return umgRequiresShadcn(node);
      return umgShadcnComponent(
        node,
        null,
        children: [for (final c in node.children) Padding(padding: _padding(c.slot), child: _measuredTight(c, _build(c)))],
        onChanged: (_) => onInteraction(),
        onPressed: onInteraction,
      );
    }
    if (plainWidgets) {
      final plain = _buildPlain(node);
      if (plain != null) return plain;
    }
    switch (node.type) {
      case UmgWidgetType.viewport:
        // The live preview with the design-time content.
        return umgViewportElement(
            key: ValueKey('umg_rt_viewport_${node.id}'), instance: null, name: node.name, props: node.props, projectDir: vm.projectDirPath);
      case UmgWidgetType.canvasPanel:
        return _buildCanvas(node);
      case UmgWidgetType.overlay:
        return Stack(children: node.children.map(_overlayChild).toList());
      case UmgWidgetType.widgetSwitcher:
        final idx = (node.props['activeIndex'] as num?)?.toInt() ?? 0;
        return IndexedStack(index: node.children.isEmpty ? 0 : idx.clamp(0, node.children.length - 1), children: node.children.map(_overlayChild).toList());
      case UmgWidgetType.horizontalBox:
      case UmgWidgetType.verticalBox:
        final isRow = node.type == UmgWidgetType.horizontalBox;
        final children = node.children.map((c) => _boxChild(c, isRow)).toList();
        return LuminaUmgBox(direction: isRow ? Axis.horizontal : Axis.vertical, children: children);
      case UmgWidgetType.gridPanel:
        final columns = ((node.props['columns'] as num?)?.toInt() ?? 2).clamp(1, 32);
        final rows = <widgets.TableRow>[];
        for (var i = 0; i < node.children.length; i += columns) {
          rows.add(widgets.TableRow(
            children: List.generate(columns, (j) {
              final idx = i + j;
              if (idx >= node.children.length) return const SizedBox.shrink();
              final c = node.children[idx];
              return Padding(padding: _padding(c.slot), child: _measuredTight(c, _build(c)));
            }),
          ));
        }
        return widgets.Table(children: rows);
      case UmgWidgetType.scrollBox:
        final horizontal = node.props['orientation'] == 'horizontal';
        final children = node.children.map((c) => Padding(padding: _padding(c.slot), child: _measuredTight(c, _build(c)))).toList();
        return SingleChildScrollView(
          scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
          child: horizontal ? Row(mainAxisSize: MainAxisSize.min, children: children) : Column(mainAxisSize: MainAxisSize.min, children: children),
        );
      case UmgWidgetType.sizeBox:
        return SizedBox(
          width: _num(node.props['width'], 200),
          height: _num(node.props['height'], 100),
          child: node.children.isEmpty ? null : Padding(padding: _padding(node.children.first.slot), child: _measured(node.children.first, _build(node.children.first))),
        );
      case UmgWidgetType.border:
        return Card(
          filled: true,
          fillColor: _color(node, '#1B1B22'),
          padding: EdgeInsets.all(_num(node.props['padding'], 8)),
          child: node.children.isEmpty
              ? const SizedBox.expand()
              : Padding(padding: _padding(node.children.first.slot), child: _measured(node.children.first, _build(node.children.first))),
        );
      case UmgWidgetType.button:
        return UmgThemeHelper.buildThemedButton(
          node: node,
          theme: vm.themeForNode(node),
          onPressed: onInteraction,
          child: umgText(node.props['label']?.toString() ?? 'Button', node.props, null),
        );
      case UmgWidgetType.text:
        return umgText(node.props['text']?.toString() ?? '', node.props, null);
      case UmgWidgetType.image:
        final bytes = vm.textureBytesFor(node.id);
        if (bytes == null) {
          return Container(
            // the prototype's `white/7` idiom: translucent so it keeps its weight on any surface
            decoration: BoxDecoration(border: Border.all(color: EditorColors.mutedForeground.withValues(alpha: 0.6)), color: const Color(0x11FFFFFF)),
            child: const Center(child: Icon(LucideIcons.image, size: 20, color: EditorColors.mutedForeground)),
          );
        }
        return Image.memory(
          bytes,
          fit: _drawAsFit(node.props['drawAs']),
          color: _color(node, '#FFFFFF'),
          colorBlendMode: BlendMode.modulate,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const Center(child: Icon(LucideIcons.imageOff, size: 20, color: EditorColors.logError)),
        );
      case UmgWidgetType.progressBar:
        return Progress(progress: _num(node.props['percent'], 0.5).clamp(0.0, 1.0), color: _color(node, '#4ADE80'));
      case UmgWidgetType.slider:
        return Slider(value: SliderValue.single(_num(node.props['value'], 0.5).clamp(0.0, 1.0)), onChanged: (_) => onInteraction());
      case UmgWidgetType.checkBox:
        return Checkbox(
          state: node.props['checked'] == true ? CheckboxState.checked : CheckboxState.unchecked,
          onChanged: (_) => onInteraction(),
          trailing: umgText(node.props['label']?.toString() ?? '', node.props, null),
        );
      case UmgWidgetType.editableText:
        return TextField(
          key: ValueKey('umg_rt_field_${node.id}_${node.props['text']}_${node.props['hint']}'),
          initialValue: node.props['text']?.toString() ?? '',
          placeholder: Text(node.props['hint']?.toString() ?? ''),
          style: umgTextStyle(node.props, null, outlineRing: true),
          onChanged: (_) => onInteraction(),
        );
      case UmgWidgetType.comboBox:
        final options = umgItems(node.props['options']);
        final selected = node.props['selected']?.toString();
        return Select<String>(
          value: options.contains(selected) ? selected : null,
          onChanged: (_) => onInteraction(),
          itemBuilder: (context, item) => umgText(item, node.props, null),
          popup: SelectPopup(
            items: SelectItemList(children: [for (final o in options) SelectItemButton(value: o, child: Text(o))]),
          ).call,
        );
      default:
        return const SizedBox.shrink(); // Container and shadcn: handled above
    }
  }

  /// The `LuminaUmg*` twin of each shadcn widget below; null for types that
  /// are the same in both libraries.
  Widget? _buildPlain(UmgNode node) {
    switch (node.type) {
      case UmgWidgetType.border:
        return LuminaUmgBorder(
          color: _color(node, '#1B1B22'),
          padding: EdgeInsets.all(_num(node.props['padding'], 8)),
          child: node.children.isEmpty
              ? const SizedBox.expand()
              : Padding(padding: _padding(node.children.first.slot), child: _measured(node.children.first, _build(node.children.first))),
        );
      case UmgWidgetType.button:
        final style = LuminaUmgButtonStyle.values.where((s) => s.name == node.props['style']?.toString()).firstOrNull;
        return LuminaUmgButton(
          style: style ?? LuminaUmgButtonStyle.primary,
          onPressed: onInteraction,
          child: umgText(node.props['label']?.toString() ?? 'Button', node.props, null),
        );
      case UmgWidgetType.progressBar:
        return LuminaUmgProgressBar(progress: _num(node.props['percent'], 0.5), color: _color(node, '#4ADE80'));
      case UmgWidgetType.slider:
        return LuminaUmgSlider(value: _num(node.props['value'], 0.5).clamp(0.0, 1.0), onChanged: (_) => onInteraction());
      case UmgWidgetType.checkBox:
        return LuminaUmgCheckbox(
          value: node.props['checked'] == true,
          onChanged: (_) => onInteraction(),
          label: umgText(node.props['label']?.toString() ?? '', node.props, null),
        );
      case UmgWidgetType.editableText:
        return LuminaUmgTextField(
          key: ValueKey('umg_rt_field_${node.id}_${node.props['text']}_${node.props['hint']}'),
          initialValue: node.props['text']?.toString() ?? '',
          placeholder: node.props['hint']?.toString() ?? '',
          style: umgTextStyle(node.props, null, outlineRing: true),
          onChanged: (_) => onInteraction(),
        );
      case UmgWidgetType.comboBox:
        final options = umgItems(node.props['options']);
        final selected = node.props['selected']?.toString();
        return LuminaUmgComboBox(
          value: options.contains(selected) ? selected : null,
          options: options,
          onChanged: (_) => onInteraction(),
          style: umgTextStyle(node.props, null),
          outline: umgTextOutline(node.props, null),
        );
      default:
        return null;
    }
  }

  Widget _buildCanvas(UmgNode node) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : vm.logicalSize.width,
          constraints.hasBoundedHeight ? constraints.maxHeight : vm.logicalSize.height,
        );
        final children = List<UmgNode>.from(node.children)..sort((a, b) => a.slot.zOrder.compareTo(b.slot.zOrder));
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
                  child: c.slot.sizeToContent ? _measuredTight(c, _build(c)) : _measured(c, _build(c)),
                );
              }(),
          ],
        );
      },
    );
  }

  Widget _overlayChild(UmgNode c) {
    final s = c.slot;
    final child = _build(c);
    if (s.hAlign == UmgAlign.fill && s.vAlign == UmgAlign.fill) {
      return Positioned.fill(child: Padding(padding: _padding(s), child: _measured(c, child)));
    }
    final sized = (s.hAlign == UmgAlign.fill || s.vAlign == UmgAlign.fill)
        ? SizedBox(width: s.hAlign == UmgAlign.fill ? double.infinity : null, height: s.vAlign == UmgAlign.fill ? double.infinity : null, child: child)
        : child;
    return Positioned.fill(
      child: Padding(
        padding: _padding(s),
        child: Align(alignment: _alignment(s), child: _measuredTight(c, sized)),
      ),
    );
  }

  Widget _boxChild(UmgNode c, bool isRow) {
    final s = c.slot;
    Widget child = _measuredTight(c, _build(c));
    final cross = isRow ? s.vAlign : s.hAlign;
    if (cross != UmgAlign.fill) {
      child = Align(alignment: isRow ? Alignment(0, _alignValue(cross)) : Alignment(_alignValue(cross), 0), child: child);
    }
    child = Padding(padding: _padding(s), child: child);
    if (s.fill) {
      child = Expanded(flex: (s.flex * 100).round().clamp(1, 100000), child: child);
    }
    return child;
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
