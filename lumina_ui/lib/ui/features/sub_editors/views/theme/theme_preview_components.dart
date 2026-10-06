import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../view_models/theme_editor_view_model.dart';
import 'package:lumina/lumina.dart';

/// Component preview builders for the Theme Sub-Editor showcase.
class ThemePreviewComponents {
  const ThemePreviewComponents._();

  /// Buttons showcase with primary, secondary, outline, and destructive variants.
  static Widget buildButtons(ThemeEditorViewModel vm, LuminaThemeDocument doc) {
    final style = vm.componentStyleOf('button');
    final btnBg = style?.bgColor ?? doc.colorOf('primary');
    final btnFg = style?.fgColor ?? doc.colorOf('primaryForeground');
    final btnRadius = style?.borderRadius ?? doc.radius;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Primary button
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: style?.paddingHorizontal ?? 16.0,
            vertical: style?.paddingVertical ?? 8.0,
          ),
          decoration: BoxDecoration(
            color: btnBg,
            borderRadius: BorderRadius.circular(btnRadius),
          ),
          child: Text(
            'Primary Action',
            style: TextStyle(
              color: btnFg,
              fontSize: style?.fontSize ?? doc.baseFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Secondary
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: style?.paddingHorizontal ?? 16.0,
            vertical: style?.paddingVertical ?? 8.0,
          ),
          decoration: BoxDecoration(
            color: doc.colorOf('secondary'),
            borderRadius: BorderRadius.circular(btnRadius),
          ),
          child: Text(
            'Secondary',
            style: TextStyle(
              color: doc.colorOf('secondaryForeground'),
              fontSize: style?.fontSize ?? doc.baseFontSize,
            ),
          ),
        ),

        // Outline
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: style?.paddingHorizontal ?? 16.0,
            vertical: style?.paddingVertical ?? 8.0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(btnRadius),
            border: Border.all(color: doc.colorOf('border')),
          ),
          child: Text(
            'Outline Button',
            style: TextStyle(
              color: doc.colorOf('foreground'),
              fontSize: style?.fontSize ?? doc.baseFontSize,
            ),
          ),
        ),

        // Destructive
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: style?.paddingHorizontal ?? 16.0,
            vertical: style?.paddingVertical ?? 8.0,
          ),
          decoration: BoxDecoration(
            color: doc.colorOf('destructive'),
            borderRadius: BorderRadius.circular(btnRadius),
          ),
          child: Text(
            'Destructive',
            style: TextStyle(
              color: doc.colorOf('destructiveForeground'),
              fontSize: style?.fontSize ?? doc.baseFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Text inputs showcase with icons and borders.
  static Widget buildInput(ThemeEditorViewModel vm, LuminaThemeDocument doc) {
    final style = vm.componentStyleOf('input');
    final bg = style?.bgColor ?? doc.colorOf('input');
    final border = style?.bColor ?? doc.colorOf('border');
    final r = style?.borderRadius ?? doc.radius;

    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: EdgeInsets.symmetric(
        horizontal: style?.paddingHorizontal ?? 12.0,
        vertical: style?.paddingVertical ?? 8.0,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 14, color: doc.colorOf('mutedForeground')),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sample Input Field Text…',
              style: TextStyle(
                color: doc.colorOf('foreground'),
                fontSize: style?.fontSize ?? doc.baseFontSize,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Card preview showing title, typography, and background elevation.
  static Widget buildCard(ThemeEditorViewModel vm, LuminaThemeDocument doc) {
    final style = vm.componentStyleOf('card');
    final bg = style?.bgColor ?? doc.colorOf('card');
    final border = style?.bColor ?? doc.colorOf('border');
    final r = style?.borderRadius ?? (doc.radius * 1.5);

    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: EdgeInsets.symmetric(
        horizontal: style?.paddingHorizontal ?? 16.0,
        vertical: style?.paddingVertical ?? 16.0,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Card Title Preview',
            style: TextStyle(
              fontSize: doc.headlineFontSize * 0.8,
              fontWeight: FontWeight.bold,
              color: doc.colorOf('cardForeground'),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This card component adopts background, borders, and typography according to the active theme document.',
            style: TextStyle(
              fontSize: doc.baseFontSize * 0.9,
              color: doc.colorOf('mutedForeground'),
            ),
          ),
        ],
      ),
    );
  }

  /// Badges showcase with default, primary, and alert styles.
  static Widget buildBadges(ThemeEditorViewModel vm, LuminaThemeDocument doc) {
    final style = vm.componentStyleOf('badge');
    final bg = style?.bgColor ?? doc.colorOf('secondary');
    final fg = style?.fgColor ?? doc.colorOf('secondaryForeground');
    final r = style?.borderRadius ?? (doc.radius * 2);

    return Wrap(
      spacing: 8,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: style?.paddingHorizontal ?? 10.0,
            vertical: style?.paddingVertical ?? 4.0,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(r),
          ),
          child: Text('Default Badge', style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: doc.colorOf('primary'),
            borderRadius: BorderRadius.circular(r),
          ),
          child: Text('Primary Badge', style: TextStyle(color: doc.colorOf('primaryForeground'), fontSize: 11, fontWeight: FontWeight.w600)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: doc.colorOf('destructive'),
            borderRadius: BorderRadius.circular(r),
          ),
          child: Text('Alert Badge', style: TextStyle(color: doc.colorOf('destructiveForeground'), fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  /// Toggle controls showcase (switch and checkbox).
  static Widget buildToggle(
    ThemeEditorViewModel vm,
    LuminaThemeDocument doc, {
    required bool switchVal,
    required bool checkboxVal,
    required ValueChanged<bool> onSwitchChanged,
    required ValueChanged<bool> onCheckboxChanged,
  }) {
    return Row(
      children: [
        Switch(
          value: switchVal,
          onChanged: onSwitchChanged,
        ),
        const SizedBox(width: 10),
        Text('Active Switch', style: TextStyle(fontSize: 12, color: doc.colorOf('foreground'))),
        const SizedBox(width: 28),
        Checkbox(
          state: checkboxVal ? CheckboxState.checked : CheckboxState.unchecked,
          onChanged: (v) => onCheckboxChanged(v == CheckboxState.checked),
        ),
        const SizedBox(width: 10),
        Text('Checkbox Option', style: TextStyle(fontSize: 12, color: doc.colorOf('foreground'))),
      ],
    );
  }

  /// Slider & progress bar showcase.
  static Widget buildSlider(
    ThemeEditorViewModel vm,
    LuminaThemeDocument doc, {
    required double sliderVal,
    required ValueChanged<double> onSliderChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Slider (${sliderVal.toStringAsFixed(0)}%)', style: TextStyle(fontSize: 12, color: doc.colorOf('foreground'))),
          ],
        ),
        const SizedBox(height: 6),
        Slider(
          value: SliderValue.single(sliderVal),
          min: 0.0,
          max: 100.0,
          onChanged: (v) => onSliderChanged(v.value),
        ),
        const SizedBox(height: 14),
        Text('Progress Bar (65%)', style: TextStyle(fontSize: 12, color: doc.colorOf('foreground'))),
        const SizedBox(height: 6),
        const Progress(progress: 0.65),
      ],
    );
  }

  /// Tabs component preview.
  static Widget buildTabs(LuminaThemeDocument doc) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: doc.colorOf('primary'),
            borderRadius: BorderRadius.circular(doc.radius * 0.8),
          ),
          child: Text('Active Tab', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: doc.colorOf('primaryForeground'))),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0x15FFFFFF),
            borderRadius: BorderRadius.circular(doc.radius * 0.8),
          ),
          child: Text('Inactive Tab 1', style: TextStyle(fontSize: 12, color: doc.colorOf('mutedForeground'))),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(doc.radius * 0.8),
          ),
          child: Text('Inactive Tab 2', style: TextStyle(fontSize: 12, color: doc.colorOf('mutedForeground'))),
        ),
      ],
    );
  }

  /// Dialog window component preview.
  static Widget buildDialog(ThemeEditorViewModel vm, LuminaThemeDocument doc) {
    final style = vm.componentStyleOf('dialog');
    final bg = style?.bgColor ?? doc.colorOf('popover');
    final border = style?.bColor ?? doc.colorOf('border');
    final r = style?.borderRadius ?? (doc.radius * 2);

    return Container(
      constraints: const BoxConstraints(maxWidth: 380),
      padding: EdgeInsets.symmetric(
        horizontal: style?.paddingHorizontal ?? 20.0,
        vertical: style?.paddingVertical ?? 20.0,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dialog Window Mockup',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: doc.colorOf('popoverForeground'),
                ),
              ),
              const Icon(LucideIcons.x, size: 14, color: Color(0xFF9CA3AF)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Dialog surfaces inherit the popover/card tokens and custom dialog radius.',
            style: TextStyle(fontSize: 12, color: doc.colorOf('mutedForeground')),
          ),
          const SizedBox(height: 14),
          const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlineButton(density: ButtonDensity.compact, child: Text('Cancel')),
              SizedBox(width: 8),
              PrimaryButton(density: ButtonDensity.compact, child: Text('Confirm')),
            ],
          ),
        ],
      ),
    );
  }
}
