import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../view_models/theme_editor_view_model.dart';
import 'theme_custom_style_dialog.dart';
import 'theme_property_inspector.dart';

/// Left panel of the Theme Sub-Editor: Tree view of theme objects, tokens,
/// and custom styles on top, with property inspector on the bottom.
class ThemeTreePanel extends StatelessWidget {
  final ThemeEditorViewModel viewModel;

  const ThemeTreePanel({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.card,
        border: Border(right: BorderSide(color: colorScheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: colorScheme.muted.withValues(alpha: 0.3),
              border: Border(bottom: BorderSide(color: colorScheme.border)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.workflow, size: 14),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Theme Objects',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                OutlineButton(
                  density: ButtonDensity.compact,
                  onPressed: () => ThemeCustomStyleDialog.show(context, viewModel),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.plus, size: 12),
                      SizedBox(width: 4),
                      Text('Custom Style', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Upper Tree View
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionHeader('Global Tokens'),
                  _buildTreeItem(
                    id: 'colors',
                    category: 'tokens',
                    title: 'Color Palette',
                    icon: LucideIcons.palette,
                  ),
                  _buildTreeItem(
                    id: 'radius',
                    category: 'radius',
                    title: 'Geometry & Radius',
                    icon: LucideIcons.box,
                  ),
                  _buildTreeItem(
                    id: 'typography',
                    category: 'typography',
                    title: 'Typography',
                    icon: LucideIcons.type,
                  ),

                  const SizedBox(height: 10),
                  _buildSectionHeader('Component Styles'),
                  for (final comp in const [
                    'button',
                    'card',
                    'input',
                    'badge',
                    'switch',
                    'slider',
                    'checkbox',
                    'tabs',
                    'progress',
                    'dialog',
                  ])
                    _buildComponentTreeItem(comp),

                  const SizedBox(height: 10),
                  _buildSectionHeader('Custom Styles (${viewModel.doc.customStyles.length})'),
                  if (viewModel.doc.customStyles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Text(
                        'No custom styles authored yet.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF71717A)),
                      ),
                    )
                  else
                    for (final customKey in viewModel.doc.customStyles.keys)
                      _buildCustomTreeItem(customKey),
                ],
              ),
            ),
          ),

          // Lower Property Inspector
          Expanded(
            flex: 1,
            child: ThemePropertyInspector(viewModel: viewModel),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: Color(0xFF9CA3AF),
        ),
      ),
    );
  }

  Widget _buildTreeItem({
    required String id,
    required String category,
    required String title,
    required IconData icon,
    String? targetKey,
    Widget? trailing,
  }) {
    final isSelected = viewModel.selection.id == id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: GhostButton(
        density: ButtonDensity.compact,
        onPressed: () {
          viewModel.selectItem(ThemeTreeSelection(
            id: id,
            category: category,
            targetKey: targetKey,
          ));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0x223B82F6) : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF9CA3AF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? const Color(0xFFFFFFFF) : const Color(0xFFD4D4D8),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComponentTreeItem(String componentKey) {
    final hasStyle = viewModel.hasComponentStyle(componentKey);
    final capitalized = componentKey[0].toUpperCase() + componentKey.substring(1);

    return _buildTreeItem(
      id: 'component.$componentKey',
      category: 'component',
      targetKey: componentKey,
      title: capitalized,
      icon: _iconForComponent(componentKey),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: hasStyle ? const Color(0x3322C55E) : const Color(0x2271717A),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          hasStyle ? 'Custom' : 'Default',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: hasStyle ? const Color(0xFF22C55E) : const Color(0xFF71717A),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTreeItem(String customName) {
    final custom = viewModel.doc.customStyles[customName];
    final target = custom?.targetComponent ?? 'item';

    return _buildTreeItem(
      id: 'custom.$customName',
      category: 'custom',
      targetKey: customName,
      title: customName,
      icon: LucideIcons.sparkles,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: const Color(0x338B5CF6),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          target,
          style: const TextStyle(fontSize: 9, color: Color(0xFFA78BFA), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  IconData _iconForComponent(String comp) {
    switch (comp) {
      case 'button':
        return LucideIcons.mousePointerClick;
      case 'card':
        return LucideIcons.creditCard;
      case 'input':
        return LucideIcons.textCursorInput;
      case 'badge':
        return LucideIcons.tag;
      case 'switch':
        return LucideIcons.toggleRight;
      case 'slider':
        return LucideIcons.slidersHorizontal;
      case 'checkbox':
        return LucideIcons.checkCheck;
      case 'tabs':
        return LucideIcons.panelTop;
      case 'progress':
        return LucideIcons.loader;
      case 'dialog':
        return LucideIcons.messageSquare;
      default:
        return LucideIcons.component;
    }
  }
}
