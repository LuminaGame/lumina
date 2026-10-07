import 'package:lumina_core/lumina_core.dart' show ObservableValue;

import 'package:lumina/src/world/subsystem/world_subsystem.dart';

/// Manages active UMG widgets added to the viewport in a [LuminaWorld].
class LuminaWidgetSubsystem extends LuminaWorldSubsystem {
  final List<Map<String, Object?>> _widgets = [];

  /// The active widgets list, replaced whenever widgets are added, removed,
  /// reordered, or their visibility changes. The widget layer
  /// (lumina_widgets) listens to it.
  final ObservableValue<List<Map<String, Object?>>> activeWidgets =
      ObservableValue<List<Map<String, Object?>>>(const []);

  /// Read-only snapshot of current active widgets sorted by zOrder ascending.
  List<Map<String, Object?>> get widgets => List.unmodifiable(_widgets);

  /// Adds a widget to the viewport.
  void addWidget(Map<String, Object?> widget) {
    if (!_widgets.contains(widget)) {
      _widgets.add(widget);
      _sortAndNotify();
    }
  }

  /// Removes a widget from the viewport.
  void removeWidget(Map<String, Object?> widget) {
    if (_widgets.remove(widget)) {
      _sortAndNotify();
    }
  }

  /// Notifies listeners that widget properties (e.g. visibility, zOrder, text) changed.
  void notifyChanged() {
    _sortAndNotify();
  }

  void _sortAndNotify() {
    _widgets.sort((a, b) {
      final za = (a['zOrder'] as num?)?.toInt() ?? 0;
      final zb = (b['zOrder'] as num?)?.toInt() ?? 0;
      return za.compareTo(zb);
    });
    activeWidgets.value = List.unmodifiable(_widgets);
  }

  @override
  void onWorldShutdown() {
    _widgets.clear();
    activeWidgets.value = const [];
    super.onWorldShutdown();
  }
}
