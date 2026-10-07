import 'package:lumina/src/declarative/element.dart';

/// Manages the build and reconciliation cycle of [LuminaElement] trees.
class LuminaBuildOwner {
  final List<LuminaElement> _dirtyElements = [];
  bool _isFlushing = false;

  /// Whether there are elements waiting to be rebuilt.
  bool get hasDirtyElements => _dirtyElements.isNotEmpty;

  /// Schedules an element for rebuilding in the next flush.
  void scheduleBuildFor(LuminaElement element) {
    if (element.lifecycle == LuminaElementLifecycle.defunct) {
      throw StateError('Cannot schedule build for a defunct element.');
    }
    if (!_dirtyElements.contains(element)) {
      _dirtyElements.add(element);
    }
  }

  /// Flushes all scheduled element builds, sorted by depth (parents first).
  void flushBuild() {
    if (_isFlushing) return;
    _isFlushing = true;

    int iterationCount = 0;
    const maxIterations = 100;

    try {
      while (_dirtyElements.isNotEmpty) {
        iterationCount++;
        if (iterationCount > maxIterations) {
          _dirtyElements.clear();
          throw StateError(
            'Infinite rebuild loop detected in LuminaBuildOwner. '
            'An element is continuously scheduling build within build() over $maxIterations iterations.',
          );
        }

        // Sort by depth (shallowest / parents first)
        _dirtyElements.sort((a, b) => a.depth.compareTo(b.depth));

        // Pop current batch
        final batch = List<LuminaElement>.from(_dirtyElements);
        _dirtyElements.clear();

        for (final element in batch) {
          if (element.lifecycle == LuminaElementLifecycle.active && element.dirty) {
            element.rebuild();
          }
        }
      }
    } finally {
      _isFlushing = false;
    }
  }
}
