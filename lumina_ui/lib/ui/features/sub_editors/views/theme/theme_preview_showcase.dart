import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../view_models/theme_editor_view_model.dart';
import 'theme_custom_style_dialog.dart';
import 'theme_preview_components.dart';
import 'package:lumina/lumina.dart';

/// Right panel of the Theme Sub-Editor: Live preview showcase of all widgets
/// receiving styles from the theme. If a component does not have a dedicated style
/// in the theme tree, a "Create Style" button is shown directly below its preview.
class ThemePreviewShowcase extends StatefulWidget {
  final ThemeEditorViewModel viewModel;

  const ThemePreviewShowcase({super.key, required this.viewModel});

  @override
  State<ThemePreviewShowcase> createState() => _ThemePreviewShowcaseState();
}

class _ThemePreviewShowcaseState extends State<ThemePreviewShowcase> {
  bool _switchVal = true;
  bool _checkboxVal = true;
  double _sliderVal = 42.0;

  ThemeEditorViewModel get vm => widget.viewModel;
  LuminaThemeDocument get doc => vm.doc;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: doc.colorOf('background', fallback: const Color(0xFF131317)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header banner
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x22FFFFFF))),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.layoutGrid, size: 14, color: Color(0xFF38BDF8)),
                const SizedBox(width: 8),
                Text(
                  'Styled Widget Showcase (${doc.name})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  'Base: ${doc.baseTheme} · Radius: ${doc.radius}px',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontFamily: 'monospace'),
                ),
              ],
            ),
          ),

          // Scrollable Preview Canvas
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPreviewSection(
                    title: 'Buttons',
                    componentKey: 'button',
                    icon: LucideIcons.mousePointerClick,
                    child: ThemePreviewComponents.buildButtons(vm, doc),
                  ),
                  const SizedBox(height: 20),

                  _buildPreviewSection(
                    title: 'Text Inputs',
                    componentKey: 'input',
                    icon: LucideIcons.textCursorInput,
                    child: ThemePreviewComponents.buildInput(vm, doc),
                  ),
                  const SizedBox(height: 20),

                  _buildPreviewSection(
                    title: 'Cards & Containers',
                    componentKey: 'card',
                    icon: LucideIcons.creditCard,
                    child: ThemePreviewComponents.buildCard(vm, doc),
                  ),
                  const SizedBox(height: 20),

                  _buildPreviewSection(
                    title: 'Badges',
                    componentKey: 'badge',
                    icon: LucideIcons.tag,
                    child: ThemePreviewComponents.buildBadges(vm, doc),
                  ),
                  const SizedBox(height: 20),

                  _buildPreviewSection(
                    title: 'Switches & Checkboxes',
                    componentKey: 'switch',
                    icon: LucideIcons.toggleRight,
                    child: ThemePreviewComponents.buildToggle(
                      vm,
                      doc,
                      switchVal: _switchVal,
                      checkboxVal: _checkboxVal,
                      onSwitchChanged: (v) => setState(() => _switchVal = v),
                      onCheckboxChanged: (v) => setState(() => _checkboxVal = v),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildPreviewSection(
                    title: 'Slider & Progress Bar',
                    componentKey: 'slider',
                    icon: LucideIcons.slidersHorizontal,
                    child: ThemePreviewComponents.buildSlider(
                      vm,
                      doc,
                      sliderVal: _sliderVal,
                      onSliderChanged: (v) => setState(() => _sliderVal = v),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildPreviewSection(
                    title: 'Tabs',
                    componentKey: 'tabs',
                    icon: LucideIcons.panelTop,
                    child: ThemePreviewComponents.buildTabs(doc),
                  ),
                  const SizedBox(height: 20),

                  _buildPreviewSection(
                    title: 'Dialogs & Modals',
                    componentKey: 'dialog',
                    icon: LucideIcons.messageSquare,
                    child: ThemePreviewComponents.buildDialog(vm, doc),
                  ),
                  const SizedBox(height: 20),

                  _buildCustomStylesSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection({
    required String title,
    required String componentKey,
    required IconData icon,
    required Widget child,
  }) {
    final hasStyle = vm.hasComponentStyle(componentKey);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: doc.colorOf('card', fallback: const Color(0xFF1E1E24)),
        borderRadius: BorderRadius.circular(doc.radius),
        border: Border.all(color: doc.colorOf('border', fallback: const Color(0x22FFFFFF))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF38BDF8)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: doc.colorOf('foreground', fallback: const Color(0xFFFAFAFA)),
                ),
              ),
              const Spacer(),
              if (hasStyle)
                OutlineButton(
                  density: ButtonDensity.compact,
                  onPressed: () {
                    vm.selectItem(ThemeTreeSelection(
                      id: 'component.$componentKey',
                      category: 'component',
                      targetKey: componentKey,
                    ));
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.pencil, size: 11),
                      SizedBox(width: 4),
                      Text('Edit Style', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // The rendered preview
          child,

          // If there is no custom style for this component in the tree, show the Create Style button!
          if (!hasStyle) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x113B82F6),
                borderRadius: BorderRadius.circular(doc.radius * 0.7),
                border: Border.all(color: const Color(0x333B82F6)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.info, size: 13, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Inheriting global theme colors. Create a dedicated style override for fine-grained tuning.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                    ),
                  ),
                  PrimaryButton(
                    key: ValueKey('create_style_btn_$componentKey'),
                    density: ButtonDensity.compact,
                    onPressed: () => vm.createComponentStyle(componentKey),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.plus, size: 12),
                        const SizedBox(width: 4),
                        Text('Create $title Style', style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomStylesSection() {
    final customStyles = doc.customStyles;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: doc.colorOf('card', fallback: const Color(0xFF1E1E24)),
        borderRadius: BorderRadius.circular(doc.radius),
        border: Border.all(color: doc.colorOf('border', fallback: const Color(0x22FFFFFF))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.sparkles, size: 14, color: Color(0xFFA78BFA)),
              const SizedBox(width: 8),
              Text(
                'Custom Named Styles (${customStyles.length})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: doc.colorOf('foreground', fallback: const Color(0xFFFAFAFA)),
                ),
              ),
              const Spacer(),
              PrimaryButton(
                density: ButtonDensity.compact,
                onPressed: () => ThemeCustomStyleDialog.show(context, vm),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.plus, size: 12),
                    SizedBox(width: 4),
                    Text('New Custom Style', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (customStyles.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0x11FFFFFF),
                borderRadius: BorderRadius.circular(doc.radius),
              ),
              child: const Center(
                child: Text(
                  'No custom styles defined. Create custom styles to assign to special widgets.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final entry in customStyles.entries)
                  _buildCustomStyleCard(entry.key, entry.value),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCustomStyleCard(String name, LuminaCustomStyle custom) {
    final style = custom.style;
    final bg = style.bgColor ?? doc.colorOf('primary');
    final fg = style.fgColor ?? doc.colorOf('primaryForeground');
    final r = style.borderRadius ?? doc.radius;

    return Container(
      constraints: const BoxConstraints(minWidth: 160),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(doc.radius),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0x338B5CF6),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  custom.targetComponent,
                  style: const TextStyle(fontSize: 9, color: Color(0xFFA78BFA), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: style.paddingHorizontal ?? 12.0,
              vertical: style.paddingVertical ?? 6.0,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(r),
              border: style.borderColor != null ? Border.all(color: style.bColor!) : null,
            ),
            child: Text(
              name,
              style: TextStyle(color: fg, fontSize: style.fontSize ?? doc.baseFontSize),
            ),
          ),
          const SizedBox(height: 8),
          GhostButton(
            density: ButtonDensity.compact,
            onPressed: () {
              vm.selectItem(ThemeTreeSelection(
                id: 'custom.$name',
                category: 'custom',
                targetKey: name,
              ));
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.pencil, size: 10),
                SizedBox(width: 4),
                Text('Edit', style: TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
