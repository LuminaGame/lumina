import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../view_models/theme_editor_view_model.dart';
import 'package:lumina/lumina.dart';

/// Property inspector showing all editable properties for the active tree selection.
class ThemePropertyInspector extends StatelessWidget {
  final ThemeEditorViewModel viewModel;

  const ThemePropertyInspector({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final sel = viewModel.selection;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.card,
        border: Border(top: BorderSide(color: colorScheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.muted.withValues(alpha: 0.3),
              border: Border(bottom: BorderSide(color: colorScheme.border)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.slidersHorizontal, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _titleForSelection(sel),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: _buildInspectorBody(context, sel),
            ),
          ),
        ],
      ),
    );
  }

  String _titleForSelection(ThemeTreeSelection sel) {
    switch (sel.category) {
      case 'tokens':
        return 'Color Palette Tokens';
      case 'radius':
        return 'Geometry & Border Radius';
      case 'typography':
        return 'Typography Settings';
      case 'component':
        return '${_capitalize(sel.targetKey ?? 'Component')} Style Properties';
      case 'custom':
        return 'Custom Style: ${sel.targetKey}';
      default:
        return 'Properties';
    }
  }

  Widget _buildInspectorBody(BuildContext context, ThemeTreeSelection sel) {
    switch (sel.category) {
      case 'tokens':
        return _buildColorTokensInspector();
      case 'radius':
        return _buildRadiusInspector();
      case 'typography':
        return _buildTypographyInspector();
      case 'component':
        final compKey = sel.targetKey;
        if (compKey == null) return const SizedBox.shrink();
        final style = viewModel.componentStyleOf(compKey);
        if (style == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No custom style override for this component.'),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    onPressed: () => viewModel.createComponentStyle(compKey),
                    child: const Text('Create Style Override'),
                  ),
                ],
              ),
            ),
          );
        }
        return _buildComponentStyleInspector(compKey, style);
      case 'custom':
        final customKey = sel.targetKey;
        if (customKey == null) return const SizedBox.shrink();
        final customStyle = viewModel.doc.customStyles[customKey];
        if (customStyle == null) return const SizedBox.shrink();
        return _buildCustomStyleInspector(customStyle);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildColorTokensInspector() {
    final colors = viewModel.doc.colors;
    final keys = [
      'background',
      'foreground',
      'primary',
      'primaryForeground',
      'secondary',
      'secondaryForeground',
      'muted',
      'mutedForeground',
      'accent',
      'accentForeground',
      'destructive',
      'destructiveForeground',
      'card',
      'cardForeground',
      'popover',
      'popoverForeground',
      'border',
      'input',
      'ring',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final k in keys) ...[
          _buildColorRow(k, colors[k] ?? 0xFF888888),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildColorRow(String token, int argb) {
    final color = Color(argb);
    final hex = '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0x33FFFFFF)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            token,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          hex,
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(width: 8),
        OutlineButton(
          density: ButtonDensity.compact,
          child: const Text('Edit', style: TextStyle(fontSize: 11)),
          onPressed: () {
            // Quick cycle through a few vibrant colors or toggle brightness
            final newColor = (argb ^ 0x00223344) | 0xFF000000;
            viewModel.setColor(token, newColor);
          },
        ),
      ],
    );
  }

  Widget _buildRadiusInspector() {
    final r = viewModel.doc.radius;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Corner Radius:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            Text('${r.toStringAsFixed(1)} px', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
          ],
        ),
        const SizedBox(height: 6),
        Slider(
          value: SliderValue.single(r),
          min: 0.0,
          max: 24.0,
          onChanged: (v) => viewModel.setRadius(v.value),
        ),
      ],
    );
  }

  Widget _buildTypographyInspector() {
    final doc = viewModel.doc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Base Font Size:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            Text('${doc.baseFontSize.toStringAsFixed(1)} pt', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
          ],
        ),
        const SizedBox(height: 6),
        Slider(
          value: SliderValue.single(doc.baseFontSize),
          min: 10.0,
          max: 20.0,
          onChanged: (v) => viewModel.setTypography(baseFontSize: v.value),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Headline Font Size:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            Text('${doc.headlineFontSize.toStringAsFixed(1)} pt', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
          ],
        ),
        const SizedBox(height: 6),
        Slider(
          value: SliderValue.single(doc.headlineFontSize),
          min: 16.0,
          max: 36.0,
          onChanged: (v) => viewModel.setTypography(headlineFontSize: v.value),
        ),
      ],
    );
  }

  Widget _buildComponentStyleInspector(String compKey, LuminaComponentStyle style) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (style.backgroundColor != null) ...[
          _buildColorRow('Background', style.backgroundColor!),
          const SizedBox(height: 8),
        ],
        if (style.foregroundColor != null) ...[
          _buildColorRow('Foreground / Text', style.foregroundColor!),
          const SizedBox(height: 8),
        ],
        if (style.borderColor != null) ...[
          _buildColorRow('Border', style.borderColor!),
          const SizedBox(height: 8),
        ],
        if (style.borderRadius != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Border Radius:', style: TextStyle(fontSize: 12)),
              Text('${style.borderRadius!.toStringAsFixed(1)} px', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
            ],
          ),
          Slider(
            value: SliderValue.single(style.borderRadius!),
            min: 0.0,
            max: 30.0,
            onChanged: (v) {
              viewModel.updateComponentStyle(compKey, style.copyWith(borderRadius: v.value));
            },
          ),
          const SizedBox(height: 8),
        ],
        if (style.paddingHorizontal != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Padding Horizontal:', style: TextStyle(fontSize: 12)),
              Text('${style.paddingHorizontal!.toStringAsFixed(0)} px', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
            ],
          ),
          Slider(
            value: SliderValue.single(style.paddingHorizontal!),
            min: 0.0,
            max: 32.0,
            onChanged: (v) {
              viewModel.updateComponentStyle(compKey, style.copyWith(paddingHorizontal: v.value));
            },
          ),
          const SizedBox(height: 8),
        ],
        if (style.fontSize != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Font Size:', style: TextStyle(fontSize: 12)),
              Text('${style.fontSize!.toStringAsFixed(1)} pt', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
            ],
          ),
          Slider(
            value: SliderValue.single(style.fontSize!),
            min: 10.0,
            max: 24.0,
            onChanged: (v) {
              viewModel.updateComponentStyle(compKey, style.copyWith(fontSize: v.value));
            },
          ),
          const SizedBox(height: 12),
        ],
        DestructiveButton(
          density: ButtonDensity.compact,
          onPressed: () => viewModel.removeComponentStyle(compKey),
          child: const Text('Reset Style to Global Defaults'),
        ),
      ],
    );
  }

  Widget _buildCustomStyleInspector(LuminaCustomStyle custom) {
    final style = custom.style;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text('Target Component: ', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0x338B5CF6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                custom.targetComponent,
                style: const TextStyle(fontSize: 11, color: Color(0xFFA78BFA), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (style.backgroundColor != null) ...[
          _buildColorRow('Background', style.backgroundColor!),
          const SizedBox(height: 8),
        ],
        if (style.foregroundColor != null) ...[
          _buildColorRow('Foreground', style.foregroundColor!),
          const SizedBox(height: 8),
        ],
        if (style.borderRadius != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Border Radius:', style: TextStyle(fontSize: 12)),
              Text('${style.borderRadius!.toStringAsFixed(1)} px', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
            ],
          ),
          Slider(
            value: SliderValue.single(style.borderRadius!),
            min: 0.0,
            max: 30.0,
            onChanged: (v) {
              viewModel.updateCustomStyle(custom.name, custom.copyWith(style: style.copyWith(borderRadius: v.value)));
            },
          ),
          const SizedBox(height: 8),
        ],
        DestructiveButton(
          density: ButtonDensity.compact,
          onPressed: () => viewModel.removeCustomStyle(custom.name),
          child: const Text('Delete Custom Style'),
        ),
      ],
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
