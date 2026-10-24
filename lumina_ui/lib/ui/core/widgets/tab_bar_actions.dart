import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// The actions each open workspace tab shows at the right end of the tab bar
/// while it is active. A sub-editor publishes its toolbar here through
/// [SubEditorToolbar]; the tab bar builds the active tab's.
class TabBarActionsRegistry extends ChangeNotifier {
  final Map<String, (Object, List<Widget>)> _actions = {};

  /// The actions [tabId] published; empty for a tab without any.
  List<Widget> actionsFor(String? tabId) => tabId == null ? const [] : _actions[tabId]?.$2 ?? const [];

  /// Whether [tabId] published actions.
  bool hasActions(String? tabId) => tabId != null && _actions.containsKey(tabId);

  // Toolbars publish and withdraw after a frame: one may land after the
  // workspace (and this registry) went away.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _publish(String tabId, Object owner, List<Widget> actions) {
    if (_disposed) return;
    _actions[tabId] = (owner, actions);
    notifyListeners();
  }

  /// Withdraws [owner]'s actions: a toolbar that replaced it keeps its own.
  void _withdraw(String tabId, Object owner) {
    if (_disposed || !identical(_actions[tabId]?.$1, owner)) return;
    _actions.remove(tabId);
    notifyListeners();
  }
}

/// Puts the content of the workspace tab [tabId] under [registry]: its
/// [SubEditorToolbar] publishes into the tab bar instead of drawing a row.
class TabBarActionsScope extends InheritedWidget {
  const TabBarActionsScope({super.key, required this.registry, required this.tabId, required super.child});

  final TabBarActionsRegistry registry;
  final String tabId;

  static TabBarActionsScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<TabBarActionsScope>();

  @override
  bool updateShouldNotify(TabBarActionsScope oldWidget) => registry != oldWidget.registry || tabId != oldWidget.tabId;
}

/// The part of a sub-editor toolbar that names the asset (its type badge
/// and name): drawn in the editor's own row, left out in the tab bar, whose
/// tab already names the asset.
class SubEditorToolbarTitle extends StatelessWidget {
  const SubEditorToolbarTitle({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// A sub-editor toolbar's close button: drawn in the editor's own row, left
/// out in the tab bar, whose tab has its own close.
class SubEditorToolbarClose extends StatelessWidget {
  const SubEditorToolbarClose({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// A sub-editor's toolbar. Inside a workspace tab ([TabBarActionsScope]) its
/// controls go to the right end of the tab bar, so the editor's islands start
/// right under the tabs; on its own (a modal, a test) it is the editor's row,
/// [height] tall on the [color] fill.
///
/// In the tab bar the [SubEditorToolbarTitle] and [SubEditorToolbarClose]
/// children are left out and a [Spacer] or [Expanded] gives no room: the
/// controls sit side by side at the bar's end.
class SubEditorToolbar extends StatefulWidget {
  const SubEditorToolbar({
    super.key,
    required this.children,
    this.height = 38,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    this.color = EditorColors.card,
  });

  final List<Widget> children;
  final double height;
  final EdgeInsetsGeometry padding;
  final Color color;

  /// [children] as the tab bar shows them.
  static List<Widget> tabBarChildren(List<Widget> children) => [
        for (final child in children)
          if (child is SubEditorToolbarTitle || child is SubEditorToolbarClose || child is Spacer)
            ...const <Widget>[]
          else if (child is Expanded)
            child.child
          else if (child is Flexible)
            child.child
          else
            child,
      ];

  @override
  State<SubEditorToolbar> createState() => _SubEditorToolbarState();
}

class _SubEditorToolbarState extends State<SubEditorToolbar> {
  TabBarActionsScope? _scope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = TabBarActionsScope.maybeOf(context);
    if (_scope != null && (scope?.registry != _scope!.registry || scope?.tabId != _scope!.tabId)) {
      _scope!.registry._withdraw(_scope!.tabId, this);
    }
    _scope = scope;
  }

  @override
  void dispose() {
    final scope = _scope;
    if (scope != null) {
      // After this frame: the tab bar may be building right now.
      WidgetsBinding.instance.addPostFrameCallback((_) => scope.registry._withdraw(scope.tabId, this));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = _scope;
    if (scope == null) {
      return Container(
        height: widget.height,
        padding: widget.padding,
        color: widget.color,
        child: Row(children: widget.children),
      );
    }
    // Published after this frame: the tab bar sits above the tab's content
    // and may already have been built in this one.
    final actions = SubEditorToolbar.tabBarChildren(widget.children);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_scope, scope)) scope.registry._publish(scope.tabId, this, actions);
    });
    return const SizedBox.shrink();
  }
}

/// The active tab's actions at the right end of the tab bar: the controls
/// side by side, scrolled from the right when the bar is too narrow for all.
class TabBarActions extends StatelessWidget {
  const TabBarActions({super.key, required this.registry, required this.tabId});

  final TabBarActionsRegistry registry;
  final String? tabId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: registry,
      builder: (context, _) {
        final actions = registry.actionsFor(tabId);
        if (actions.isEmpty) return const SizedBox.shrink();
        return SingleChildScrollView(
          key: const ValueKey('tab_bar_actions'),
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: actions),
          ),
        );
      },
    );
  }
}
