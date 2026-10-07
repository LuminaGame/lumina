import 'package:flutter/foundation.dart';

import 'package:lumina/src/world/subsystem/world_subsystem.dart';

/// Manages active UMG widgets added to the viewport in a [LuminaWorld].
class LuminaWidgetSubsystem extends LuminaWorldSubsystem {
  final List<Map<String, Object?>> _widgets = [];

  /// ValueNotifier emitting the active widgets list whenever widgets are added,
  /// removed, reordered, or visibility changes.
  final ValueNotifier<List<Map<String, Object?>>> activeWidgets =
      ValueNotifier<List<Map<String, Object?>>>(const []);

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
