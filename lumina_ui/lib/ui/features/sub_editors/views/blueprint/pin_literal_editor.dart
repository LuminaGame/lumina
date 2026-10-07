import 'package:flutter/services.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// The inline editor for an unconnected input pin's literal, by pin type:
/// a switch for booleans, a number field for integers and floats, a text
/// field for strings and names, X/Y for Vector2D, X/Y/Z (cm) for vectors,
/// Roll/Pitch/Yaw (°) for rotators, a swatch plus hex field for colours
/// (stored `[r, g, b, a]`), the location / rotation / scale triple for
/// transforms, a read-only struct badge for hit results and a dropdown (or
/// text) for enums. Each field commits on Enter or
/// when it loses focus, so one typed value is one undo step.
class BlueprintPinLiteralEditor extends StatelessWidget {
  final String keyPrefix;
  final LuminaPinType type;
  final Object? value;
  final ValueChanged<Object?> onCommit;

  /// Wider fields for the Details panel.
  final bool expanded;

  /// Optional dropdown choices (e.g. Widget Blueprint classes for Create Widget).
  final List<String>? options;

  const BlueprintPinLiteralEditor({
    super.key,
    required this.keyPrefix,
    required this.type,
    required this.value,
    required this.onCommit,
    this.options,
    this.expanded = false,
  });

  static bool supports(LuminaPinType type) => const {
        LuminaPinType.boolean,
        LuminaPinType.integer,
        LuminaPinType.float,
        LuminaPinType.string,
        LuminaPinType.name,
        LuminaPinType.vector,
        LuminaPinType.vector2D,
        LuminaPinType.rotator,
        LuminaPinType.color,
        LuminaPinType.transform,
        LuminaPinType.hitResult,
        LuminaPinType.structEnum,
        LuminaPinType.enumeration,
      }.contains(type);

  /// Width the inline editor takes on a node, for the node's layout.
  static double inlineWidth(LuminaPinType type, [List<String>? options]) {
    if (options != null && options.isNotEmpty) {
      return options.every((o) => o.endsWith('.lmas')) ? 140 : 108;
    }
    return switch (type) {
      LuminaPinType.boolean => 26,
      LuminaPinType.integer || LuminaPinType.float => 56,
      LuminaPinType.string || LuminaPinType.name => 96,
      LuminaPinType.vector2D => 104,
      LuminaPinType.vector || LuminaPinType.rotator => 170,
      LuminaPinType.color => 96,
      LuminaPinType.transform => 176,
      LuminaPinType.hitResult => 62,
      LuminaPinType.structEnum => 96,
      LuminaPinType.enumeration => 96,
      _ => 0,
    };
  }

  /// `[r, g, b, a]` (0–1) as `#RRGGBBAA`.
  static String colorToHex(List<double> c) {
    String h(double v) => (v.clamp(0.0, 1.0) * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#${h(c[0])}${h(c[1])}${h(c[2])}${h(c[3])}';
  }

  /// `#RRGGBB` or `#RRGGBBAA` (with or without `#`) as `[r, g, b, a]`; null
  /// when the text is not a colour.
  static List<double>? hexToColor(String text) {
    final hex = text.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(hex)) return null;
    double at(int i) => int.parse(hex.substring(i, i + 2), radix: 16) / 255.0;
    return [at(0), at(2), at(4), hex.length == 8 ? at(6) : 1.0];
  }

  static List<double> _nums(Object? v, int n) {
    final list = v is List ? v : const [];
    return [for (var i = 0; i < n; i++) i < list.length && list[i] is num ? (list[i] as num).toDouble() : 0.0];
  }

  @override
  Widget build(BuildContext context) {
    if (options != null && options!.isNotEmpty) {
      final current = value?.toString();
      final hasCurrent = current != null && current.isNotEmpty;
      final effectiveItems = [
        ...options!,
        if (hasCurrent && !options!.contains(current)) current,
      ];
      final known = effectiveItems.contains(current);

      // Asset pins (sounds, montages, materials, particles,
      // levels, save classes) offer project `.lmas` paths: the shared
      // searchable picker with thumbnails resolves each path to
      // its scanned asset through the editor's AssetPickerScope.
      if (effectiveItems.every((o) => o.endsWith('.lmas'))) {
        return SizedBox(
          width: expanded ? 200 : 140,
          child: AssetPickerSelect(
            key: ValueKey('${keyPrefix}_select'),
            keyPrefix: keyPrefix,
            assets: [
              for (final path in effectiveItems)
                RealAssetInfo(fileName: path.split('/').last, relativePath: path, type: AssetType.unknown, bytes: 0),
            ],
            selectedPath: hasCurrent ? current : null,
            placeholder: 'Select...',
            thumbnailSize: 20,
            allowClear: false,
            onSelected: (a) => onCommit(a.relativePath),
          ),
        );
      }

      return SizedBox(
        width: expanded ? 180 : 108,
        height: 20,
        child: Select<String>(
          key: ValueKey('${keyPrefix}_select'),
          value: known ? current : null,
          placeholder: Text(
            hasCurrent ? current : 'Select...',
            style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
            overflow: TextOverflow.ellipsis,
          ),
          itemBuilder: (context, item) => Text(
            item,
            style: const TextStyle(fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
          onChanged: (v) {
            if (v != null) onCommit(v);
          },
          popup: SelectPopup(
            items: SelectItemList(
              children: [
                for (final opt in effectiveItems)
                  SelectItemButton(
                    key: ValueKey('${keyPrefix}_opt_$opt'),
                    value: opt,
                    child: Text(opt, style: const TextStyle(fontSize: 10)),
                  ),
              ],
            ),
          ).call,
        ),
      );
    }

    final fieldWidth = expanded ? 64.0 : 44.0;
    switch (type) {
      case LuminaPinType.boolean:
        return SizedBox(
          height: 18,
          child: Checkbox(
            key: ValueKey('${keyPrefix}_0'),
            state: value == true ? CheckboxState.checked : CheckboxState.unchecked,
            onChanged: (s) => onCommit(s == CheckboxState.checked),
          ),
        );
      case LuminaPinType.integer:
      case LuminaPinType.float:
        final isInt = type == LuminaPinType.integer;
        final n = value is num ? value as num : (isInt ? 0 : 0.0);
        return _CommitField(
          key: ValueKey('${keyPrefix}_0'),
          width: expanded ? 90 : 52,
          text: isInt ? '${n.toInt()}' : _fmt(n.toDouble()),
          numeric: true,
          onCommit: (t) {
            final parsed = isInt ? int.tryParse(t) : double.tryParse(t);
            if (parsed != null) onCommit(parsed);
          },
        );
      case LuminaPinType.string:
      case LuminaPinType.name:
        return _CommitField(
          key: ValueKey('${keyPrefix}_0'),
          width: expanded ? 160 : 92,
          text: value?.toString() ?? '',
          onCommit: onCommit,
        );
      case LuminaPinType.vector2D:
        final v = _nums(value, 2);
        return _axes(['X', 'Y'], v, [0, 1], fieldWidth, null);
      case LuminaPinType.vector:
        final v = _nums(value, 3);
        return _axes(['X', 'Y', 'Z'], v, [0, 1, 2], fieldWidth, 'cm');
      case LuminaPinType.rotator:
        // Stored [x, y, z] = [pitch, roll, yaw] (lumina's LuminaRotator);
        // shown in Roll / Pitch / Yaw order.
        final v = _nums(value, 3);
        return _axes(['R', 'P', 'Y'], v, [1, 0, 2], fieldWidth, '°');
      case LuminaPinType.color:
        final c = value is List && (value as List).length >= 3 ? _nums(value, 4) : const [1.0, 1.0, 1.0, 1.0];
        if (value is List && (value as List).length == 3) c[3] = 1.0;
        final swatch = Color.fromARGB((c[3] * 255).round(), (c[0] * 255).round(), (c[1] * 255).round(), (c[2] * 255).round());
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: ValueKey('${keyPrefix}_swatch'),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: swatch,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: EditorColors.border),
              ),
            ),
            const SizedBox(width: 4),
            _CommitField(
              key: ValueKey('${keyPrefix}_0'),
              width: expanded ? 110 : 74,
              text: colorToHex(c),
              onCommit: (t) {
                final parsed = hexToColor(t);
                if (parsed != null) onCommit(parsed);
              },
            ),
          ],
        );
      case LuminaPinType.transform:
        // Stored [lx, ly, lz, rx, ry, rz, sx, sy, sz] (cm, °, factor).
        final v = value is List && (value as List).length >= 9
            ? _nums(value, 9)
            : const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0];
        Widget triple(String label, int offset, String? unit) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 12, child: Text(label, style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground))),
                for (var i = 0; i < 3; i++) ...[
                  _CommitField(
                    key: ValueKey('${keyPrefix}_${offset + i}'),
                    width: expanded ? 54 : 42,
                    text: _fmt(v[offset + i]),
                    numeric: true,
                    onCommit: (t) {
                      final parsed = double.tryParse(t);
                      if (parsed == null) return;
                      final next = [...v];
                      next[offset + i] = parsed;
                      onCommit(next);
                    },
                  ),
                  const SizedBox(width: 2),
                ],
                if (unit != null) Text(unit, style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
              ],
            );
        // On the node only the location fits a pin row; the Details panel
        // shows all three.
        if (!expanded) return triple('L', 0, 'cm');
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [triple('L', 0, 'cm'), const SizedBox(height: 2), triple('R', 3, '°'), const SizedBox(height: 2), triple('S', 6, null)],
        );
      case LuminaPinType.hitResult:
        // A struct with no literal: it only ever comes from a trace.
        return OutlineBadge(
          key: ValueKey('${keyPrefix}_struct'),
          child: const Text('Hit Result', style: TextStyle(fontSize: 8)),
        );
      case LuminaPinType.structEnum:
      case LuminaPinType.enumeration:
        return _CommitField(
          key: ValueKey('${keyPrefix}_0'),
          width: expanded ? 160 : 92,
          text: value?.toString() ?? '',
          onCommit: onCommit,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _axes(List<String> labels, List<double> v, List<int> indices, double width, String? unit) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Text(labels[i], style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
          const SizedBox(width: 1),
          _CommitField(
            key: ValueKey('${keyPrefix}_${indices[i]}'),
            width: width,
            text: _fmt(v[indices[i]]),
            numeric: true,
            onCommit: (t) {
              final parsed = double.tryParse(t);
              if (parsed == null) return;
              final next = [...v];
              next[indices[i]] = parsed;
              onCommit(next);
            },
          ),
          const SizedBox(width: 2),
        ],
        if (unit != null) Text(unit, style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
      ],
    );
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(1) : '$v';
}

/// A small text field that reports its text once, on Enter or focus loss,
/// and follows the stored value while it is not being edited.
class _CommitField extends StatefulWidget {
  final double width;
  final String text;
  final bool numeric;
  final ValueChanged<String> onCommit;

  const _CommitField({super.key, required this.width, required this.text, required this.onCommit, this.numeric = false});

  @override
  State<_CommitField> createState() => _CommitFieldState();
}

class _CommitFieldState extends State<_CommitField> {
  late final TextEditingController _controller = TextEditingController(text: widget.text);
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant _CommitField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && widget.text != _controller.text) _controller.text = widget.text;
  }

  void _commit() {
    if (_controller.text != widget.text) widget.onCommit(_controller.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: 20,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        style: const TextStyle(fontSize: 9, fontFamily: EditorTypography.monoFamily),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        keyboardType: widget.numeric ? const TextInputType.numberWithOptions(decimal: true, signed: true) : null,
        inputFormatters: widget.numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.eE]'))] : null,
        onSubmitted: (_) => _commit(),
      ),
    );
  }
}
