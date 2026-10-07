import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

class SubEditorHierarchyWidget extends StatefulWidget {
  final List<GlbNode> rootNodes;
  final List<GlbNode> allNodes;
  final GlbNode? selectedNode;
  final ValueChanged<GlbNode?>? onNodeSelected;
  final void Function(GlbNode node, bool isVisible)? onNodeVisibilityChanged;

  const SubEditorHierarchyWidget({
    super.key,
    required this.rootNodes,
    this.allNodes = const [],
    this.selectedNode,
    this.onNodeSelected,
    this.onNodeVisibilityChanged,
  });

  @override
  State<SubEditorHierarchyWidget> createState() => _SubEditorHierarchyWidgetState();
}

class _SubEditorHierarchyWidgetState extends State<SubEditorHierarchyWidget> {
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _expandedIndices = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _expandDefaultNodes();
  }

  @override
  void didUpdateWidget(covariant SubEditorHierarchyWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rootNodes != widget.rootNodes) {
      _expandDefaultNodes();
    }
  }

  void _expandDefaultNodes() {
    // Expand root nodes and first 2 levels by default
    void expandLevel(List<GlbNode> nodes, int level) {
      if (level > 2) return;
      for (final n in nodes) {
        if (n.children.isNotEmpty) {
          _expandedIndices.add(n.index);
          expandLevel(n.children, level + 1);
        }
      }
    }
    expandLevel(widget.rootNodes, 0);
  }

  void _expandAll() {
    setState(() {
      for (final n in widget.allNodes) {
        if (n.children.isNotEmpty) {
          _expandedIndices.add(n.index);
        }
      }
      for (final r in widget.rootNodes) {
        void addAll(GlbNode node) {
          if (node.children.isNotEmpty) {
            _expandedIndices.add(node.index);
            for (final c in node.children) {
              addAll(c);
            }
          }
        }
        addAll(r);
      }
    });
  }

  void _collapseAll() {
    setState(() {
      _expandedIndices.clear();
    });
  }

  bool _nodeMatchesFilter(GlbNode node, String query) {
    if (query.isEmpty) return true;
    if (node.name.toLowerCase().contains(query)) return true;
    for (final child in node.children) {
      if (_nodeMatchesFilter(child, query)) return true;
    }
    return false;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();
    final totalNodes = widget.allNodes.isNotEmpty ? widget.allNodes.length : _countAllNodes(widget.rootNodes);

    return Container(
      color: EditorColors.cardHeader,
      child: Column(
        children: [
          // Hierarchy Header & Controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: EditorColors.border, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.network, size: 14, color: EditorColors.primary),
                    const SizedBox(width: 6),
                    const Text(
                      'Hierarchy',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: EditorColors.foreground,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: EditorColors.card,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: EditorColors.border),
                      ),
                      child: Text(
                        '$totalNodes',
                        style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
                      ),
                    ),
                    const Spacer(),
                    // Expand All
                    Tooltip(
                      tooltip: (context) => TooltipContainer(child: const Text('Expand All')),
                      child: GhostButton(
                        density: ButtonDensity.compact,
                        onPressed: _expandAll,
                        child: const Icon(LucideIcons.unfoldVertical, size: 12),
                      ),
                    ),
                    // Collapse All
                    Tooltip(
                      tooltip: (context) => TooltipContainer(child: const Text('Collapse All')),
                      child: GhostButton(
                        density: ButtonDensity.compact,
                        onPressed: _collapseAll,
                        child: const Icon(LucideIcons.foldVertical, size: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Search Input Filter
                SizedBox(
                  height: 28,
                  child: TextField(
                    controller: _searchController,
                    placeholder: const Text('Search nodes...', style: TextStyle(fontSize: 10)),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Tree View
          Expanded(
            child: widget.rootNodes.isEmpty
                ? const Center(
                    child: Text(
                      'No scene nodes found',
                      style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: _buildTreeRows(widget.rootNodes, query, 0),
                  ),
          ),
        ],
      ),
    );
  }

  int _countAllNodes(List<GlbNode> nodes) {
    int count = nodes.length;
    for (final n in nodes) {
      count += _countAllNodes(n.children);
    }
    return count;
  }

  List<Widget> _buildTreeRows(List<GlbNode> nodes, String query, int depth) {
    final List<Widget> rows = [];

    for (final node in nodes) {
      if (query.isNotEmpty && !_nodeMatchesFilter(node, query)) {
        continue;
      }

      final isExpanded = query.isNotEmpty || _expandedIndices.contains(node.index);
      final isSelected = widget.selectedNode?.index == node.index;
      final hasChildren = node.children.isNotEmpty;

      rows.add(
        _HierarchyNodeRow(
          node: node,
          depth: depth,
          isExpanded: isExpanded,
          isSelected: isSelected,
          onToggleExpand: hasChildren
              ? () {
                  setState(() {
                    if (_expandedIndices.contains(node.index)) {
                      _expandedIndices.remove(node.index);
                    } else {
                      _expandedIndices.add(node.index);
                    }
                  });
                }
              : null,
          onSelect: () {
            widget.onNodeSelected?.call(node);
          },
          onToggleVisibility: () {
            setState(() {
              final newVis = !node.isVisible;
              void setDescendants(GlbNode n, bool vis) {
                n.isVisible = vis;
                for (final c in n.children) {
                  setDescendants(c, vis);
                }
              }
              setDescendants(node, newVis);
            });
            widget.onNodeVisibilityChanged?.call(node, node.isVisible);
          },
        ),
      );

      if (hasChildren && isExpanded) {
        rows.addAll(_buildTreeRows(node.children, query, depth + 1));
      }
    }

    return rows;
  }
}

class _HierarchyNodeRow extends StatelessWidget {
  final GlbNode node;
  final int depth;
  final bool isExpanded;
  final bool isSelected;
  final VoidCallback? onToggleExpand;
  final VoidCallback onSelect;
  final VoidCallback onToggleVisibility;

  const _HierarchyNodeRow({
    required this.node,
    required this.depth,
    required this.isExpanded,
    required this.isSelected,
    this.onToggleExpand,
    required this.onSelect,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        padding: EdgeInsets.only(left: depth * 14.0 + 4, right: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? EditorColors.primary.withValues(alpha: 0.22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          border: isSelected
              ? Border.all(color: EditorColors.primary.withValues(alpha: 0.6), width: 1)
              : null,
        ),
        child: Row(
          children: [
            // Chevron Expand / Collapse
            if (node.children.isNotEmpty)
              GestureDetector(
                onTap: onToggleExpand,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    isExpanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                    size: 11,
                    color: isSelected ? EditorColors.primary : EditorColors.mutedForeground,
                  ),
                ),
              )
            else
              const SizedBox(width: 15),

            // Node Type Icon
            _getNodeTypeIcon(node.type),
            const SizedBox(width: 6),

            // Node Name
            Expanded(
              child: Text(
                node.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? EditorColors.foreground
                      : (node.isVisible ? EditorColors.foreground : EditorColors.mutedForeground.withValues(alpha: 0.5)),
                ),
              ),
            ),

            // Child Count Badge (e.g. (8) / (1))
            if (node.children.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  '(${node.children.length})',
                  style: TextStyle(
                    fontSize: 9,
                    color: isSelected ? EditorColors.primary : EditorColors.mutedForeground,
                  ),
                ),
              ),

            // Visibility Eye Toggle Icon
            GestureDetector(
              onTap: onToggleVisibility,
              child: Icon(
                node.isVisible ? LucideIcons.eye : LucideIcons.eyeOff,
                size: 11,
                color: node.isVisible
                    ? (isSelected ? EditorColors.primary : EditorColors.mutedForeground)
                    : Colors.red.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getNodeTypeIcon(GlbNodeType type) {
    switch (type) {
      case GlbNodeType.mesh:
        return const Icon(LucideIcons.box, size: 12, color: Colors.cyan);
      case GlbNodeType.group:
        return const Icon(LucideIcons.boxes, size: 12, color: EditorColors.primary);
      case GlbNodeType.light:
        return const Icon(LucideIcons.sparkles, size: 12, color: Colors.amber);
      case GlbNodeType.bone:
        return const Icon(LucideIcons.shield, size: 12, color: Colors.purple);
      case GlbNodeType.camera:
        return const Icon(LucideIcons.camera, size: 12, color: Colors.blue);
    }
  }
}
