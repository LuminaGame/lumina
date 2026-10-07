import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:lumina/lumina_runtime.dart';
import 'package:lumina_widgets/src/umg/element_binding.dart';

/// Builds the compiled Flutter widget of one widget instance (the map
/// `Create Widget` made) — what `widgets/widget_registry.g.dart` registers
/// for every widget class of a game.
typedef LuminaWidgetBuilder = Widget Function(BuildContext context, Map<String, Object?> instance);

/// The compiled widget classes of a running game: the generated
/// `widgets/widget_registry.g.dart` registers each class's description (into
/// [LuminaWidgetClassRegistry], so `Create Widget` seeds its elements) together
/// with the builder that renders an instance of it in a [LuminaWidgetLayer].
abstract final class LuminaWidgetBuilderRegistry {
  static final Map<String, LuminaWidgetBuilder> _builders = {};

  /// Registers [cls] under [name] with the [builder] that renders it.
  static void register(String name, LuminaBlueprintWidgetClass cls, LuminaWidgetBuilder builder) {
    LuminaWidgetClassRegistry.register(cls);
    _builders[name] = builder;
  }

  /// The builder of [className], or null (an unknown class renders as a
  /// fallback card naming it).
  static LuminaWidgetBuilder? builderFor(String? className) => className == null ? null : _builders[className];

  static bool has(String className) => _builders.containsKey(className);

  static void unregister(String name) {
    _builders.remove(name);
    LuminaWidgetClassRegistry.unregister(name);
  }

  /// Forgets every builder and every class.
  static void clear() {
    _builders.clear();
    LuminaWidgetClassRegistry.clear();
  }
}

/// Renders the widgets a world's [LuminaWidgetSubsystem] shows: the
/// game host stacks it over [LuminaGameWidget], the editor over its PIE
/// viewport. Widgets are laid out full-screen in `zOrder` order; `Hidden` and
/// `Collapsed` instances are skipped; each instance is built through
/// [resolveBuilder], then [LuminaWidgetBuilderRegistry], and an unknown class
/// renders as a small card naming it. Element nodes writing an instance's
/// state refresh only the elements that changed.
class LuminaWidgetLayer extends StatefulWidget {
  /// Renders the widgets of [world]; null renders nothing.
  const LuminaWidgetLayer({super.key, required this.world, this.resolveBuilder, this.fallbackBuilder}) : game = null;

  /// Renders the widgets of [game]'s world, following the game as it mounts
  /// and stops (the world exists only after [LuminaGame.mountGame]).
  const LuminaWidgetLayer.forGame({super.key, required LuminaGame this.game, this.resolveBuilder, this.fallbackBuilder})
      : world = null;

  final LuminaWorld? world;
  final LuminaGame? game;

  /// Takes precedence over the registry: the editor renders a class from its
  /// designer document instead of a compiled Dart class.
  final LuminaWidgetBuilder? Function(String className)? resolveBuilder;

  /// Replaces the default fallback card for classes nobody can build.
  final LuminaWidgetBuilder? fallbackBuilder;

  @override
  State<LuminaWidgetLayer> createState() => _LuminaWidgetLayerState();
}

class _LuminaWidgetLayerState extends State<LuminaWidgetLayer> {
  LuminaWidgetSubsystem? _subsystem;
  StreamSubscription<LuminaPlayState>? _playState;
  final Map<Map<String, Object?>, LuminaUmgInstanceBinding> _bindings = {};
  List<Map<String, Object?>> _visible = const [];

  LuminaWorld? get _world => widget.game?.world ?? widget.world;

  @override
  void initState() {
    super.initState();
    _attachGame();
    _attachSubsystem();
  }

  @override
  void didUpdateWidget(LuminaWidgetLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.game, widget.game)) _attachGame();
    _attachSubsystem();
  }

  void _attachGame() {
    _playState?.cancel();
    _playState = widget.game?.playStateStream.listen((_) {
      if (mounted) setState(_attachSubsystem);
    });
  }

  void _attachSubsystem() {
    final subsystem = _world?.getSubsystem<LuminaWidgetSubsystem>();
    if (identical(subsystem, _subsystem)) return;
    _subsystem?.activeWidgets.removeListener(_onWidgetsChanged);
    _subsystem = subsystem;
    _subsystem?.activeWidgets.addListener(_onWidgetsChanged);
    _sync(subsystem?.activeWidgets.value ?? const []);
  }

  void _onWidgetsChanged() {
    if (!mounted) return;
    final active = _subsystem?.activeWidgets.value ?? const [];
    final visible = _visibleOf(active);
    // Same instances in the same order: only element state changed, which the
    // bound elements pick up themselves.
    final sameList = visible.length == _visible.length &&
        () {
          for (var i = 0; i < visible.length; i++) {
            if (!identical(visible[i], _visible[i])) return false;
          }
          return true;
        }();
    if (sameList) {
      for (final b in _bindings.values) {
        b.refresh();
      }
      return;
    }
    setState(() => _sync(active));
  }

  static List<Map<String, Object?>> _visibleOf(List<Map<String, Object?>> active) {
    final visible = [
      for (final item in active)
        if (item['inViewport'] != false && _isVisible(item)) item,
    ];
    // The subsystem sorts by zOrder; keep the order stable on ties.
    return visible;
  }

  static bool _isVisible(Map<String, Object?> instance) {
    final v = instance['visibility'] as String? ?? 'Visible';
    return v != 'Hidden' && v != 'Collapsed';
  }

  void _sync(List<Map<String, Object?>> active) {
    _visible = _visibleOf(active);
    final keep = <Map<String, Object?>, LuminaUmgInstanceBinding>{};
    for (final item in _visible) {
      keep[item] = _bindings[item] ?? LuminaUmgInstanceBinding(item);
    }
    for (final entry in _bindings.entries) {
      if (!keep.containsKey(entry.key)) entry.value.dispose();
    }
    _bindings
      ..clear()
      ..addAll(keep);
    for (final b in _bindings.values) {
      b.refresh();
    }
  }

  @override
  void dispose() {
    _playState?.cancel();
    _subsystem?.activeWidgets.removeListener(_onWidgetsChanged);
    for (final b in _bindings.values) {
      b.dispose();
    }
    _bindings.clear();
    super.dispose();
  }

  Widget _buildInstance(BuildContext context, Map<String, Object?> instance) {
    final className = instance['class'] as String? ?? '';
    final builder = widget.resolveBuilder?.call(className) ?? LuminaWidgetBuilderRegistry.builderFor(className);
    if (builder != null) return builder(context, instance);
    final fallback = widget.fallbackBuilder;
    if (fallback != null) return fallback(context, instance);
    return _LuminaUnknownWidgetCard(className: className);
  }

  @override
  Widget build(BuildContext context) {
    if (_visible.isEmpty) return const SizedBox.shrink();
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final instance in _visible)
          Positioned.fill(
            key: ObjectKey(instance),
            child: LuminaUmgInstanceScope(
              binding: _bindings[instance]!,
              child: Builder(builder: (context) => _buildInstance(context, instance)),
            ),
          ),
      ],
    );
  }
}

/// What an instance of a class no registry knows looks like: a small card
/// naming the class in the bottom-left corner, as the editor's PIE showed.
class _LuminaUnknownWidgetCard extends StatelessWidget {
  const _LuminaUnknownWidgetCard({required this.className});

  final String className;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xCC1B1B22),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF3A3A44)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              className.isEmpty ? 'Widget' : className,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF4F4F5), decoration: TextDecoration.none),
            ),
          ),
        ),
      ),
    );
  }
}
