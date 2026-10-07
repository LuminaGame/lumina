import 'dart:math' as math;
import 'package:lumina/src/world/subsystem/world_subsystem.dart';

/// Opaque identifier for an active or expired timer managed by [LuminaTimerManager].
class LuminaTimerHandle {
  final int id;
  bool _isValid;

  LuminaTimerHandle._(this.id) : _isValid = true;

  /// Whether this handle currently references a valid registered timer.
  bool get isValid => _isValid;

  /// Clears the validity of this local handle reference.
  void invalidate() {
    _isValid = false;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LuminaTimerHandle && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'LuminaTimerHandle(id: $id, isValid: $_isValid)';
}

class _TimerEntry {
  final LuminaTimerHandle handle;
  final void Function() callback;
  final double rate;
  final bool looping;
  double remainingTime;
  bool isPaused = false;
  bool isNextTick = false;

  _TimerEntry({
    required this.handle,
    required this.callback,
    required this.rate,
    required this.looping,
    required this.remainingTime,
    this.isNextTick = false,
  });
}

/// Central world subsystem managing game-time timers and delayed invocations driven exclusively by world ticks.
class LuminaTimerManager extends LuminaWorldSubsystem {
  final Map<int, _TimerEntry> _timers = {};
  final List<_TimerEntry> _pendingAdditions = [];
  int _nextId = 1;

  /// Schedules [callback] to fire after [rate] seconds of game time.
  LuminaTimerHandle setTimer(
    void Function() callback, {
    required double rate,
    bool looping = false,
    double firstDelay = -1.0,
  }) {
    if (rate <= 0.0) {
      throw ArgumentError.value(rate, 'rate', 'Timer rate must be greater than zero');
    }

    final handle = LuminaTimerHandle._(_nextId++);
    final initialDelay = firstDelay >= 0.0 ? firstDelay : rate;
    final entry = _TimerEntry(
      handle: handle,
      callback: callback,
      rate: rate,
      looping: looping,
      remainingTime: initialDelay,
    );

    _pendingAdditions.add(entry);
    return handle;
  }

  /// Schedules [callback] to execute on the immediately following world tick.
  LuminaTimerHandle setTimerForNextTick(void Function() callback) {
    final handle = LuminaTimerHandle._(_nextId++);
    final entry = _TimerEntry(
      handle: handle,
      callback: callback,
      rate: 0.0,
      looping: false,
      remainingTime: 0.0,
      isNextTick: true,
    );

    _pendingAdditions.add(entry);
    return handle;
  }

  /// Cancels the timer referenced by [handle].
  void clearTimer(LuminaTimerHandle handle) {
    handle.invalidate();
    _timers.remove(handle.id);
    _pendingAdditions.removeWhere((e) => e.handle.id == handle.id);
  }

  /// Cancels all active, paused, and pending timers.
  void clearAllTimers() {
    for (final entry in _timers.values) {
      entry.handle.invalidate();
    }
    for (final entry in _pendingAdditions) {
      entry.handle.invalidate();
    }
    _timers.clear();
    _pendingAdditions.clear();
  }

  /// Pauses the timer referenced by [handle], freezing its remaining time.
  void pauseTimer(LuminaTimerHandle handle) {
    final entry = _timers[handle.id] ?? _findPending(handle.id);
    if (entry != null) {
      entry.isPaused = true;
    }
  }

  /// Resumes a paused timer referenced by [handle].
  void unpauseTimer(LuminaTimerHandle handle) {
    final entry = _timers[handle.id] ?? _findPending(handle.id);
    if (entry != null) {
      entry.isPaused = false;
    }
  }

  _TimerEntry? _findPending(int id) {
    for (final entry in _pendingAdditions) {
      if (entry.handle.id == id) return entry;
    }
    return null;
  }

  /// Checks if [handle] is currently active and not paused.
  bool isTimerActive(LuminaTimerHandle handle) {
    final entry = _timers[handle.id] ?? _findPending(handle.id);
    return entry != null && !entry.isPaused;
  }

  /// Checks if [handle] is currently paused.
  bool isTimerPaused(LuminaTimerHandle handle) {
    final entry = _timers[handle.id] ?? _findPending(handle.id);
    return entry != null && entry.isPaused;
  }

  /// Returns the remaining time in seconds for [handle], or -1.0 if not found.
  double getTimerRemaining(LuminaTimerHandle handle) {
    final entry = _timers[handle.id] ?? _findPending(handle.id);
    if (entry == null) return -1.0;
    return entry.remainingTime;
  }

  /// Returns the elapsed time in seconds into the current interval for [handle], or -1.0 if not found.
  double getTimerElapsed(LuminaTimerHandle handle) {
    final entry = _timers[handle.id] ?? _findPending(handle.id);
    if (entry == null) return -1.0;
    return entry.rate - entry.remainingTime;
  }

  /// Returns the configured interval rate in seconds for [handle], or -1.0 if not found.
  double getTimerRate(LuminaTimerHandle handle) {
    final entry = _timers[handle.id] ?? _findPending(handle.id);
    if (entry == null) return -1.0;
    return entry.rate;
  }

  /// Total count of active timers currently tracked.
  int get activeTimerCount => _timers.length + _pendingAdditions.length;

  @override
  void onWorldTick(double deltaTime) {
    // 1. Flush pending additions into active timers
    if (_pendingAdditions.isNotEmpty) {
      for (final entry in _pendingAdditions) {
        _timers[entry.handle.id] = entry;
      }
      _pendingAdditions.clear();
    }

    // 2. Snapshot current active timers to ensure safe reentrancy
    final activeSnapshot = _timers.values.toList();
    final toFire = <(_TimerEntry, int)>[];

    for (final entry in activeSnapshot) {
      if (entry.isPaused) continue;

      if (entry.isNextTick) {
        toFire.add((entry, 1));
        _timers.remove(entry.handle.id);
        continue;
      }

      entry.remainingTime -= deltaTime;
      if (entry.remainingTime <= 0.0) {
        if (!entry.looping) {
          toFire.add((entry, 1));
          _timers.remove(entry.handle.id);
        } else {
          // Looping catch-up (bounded to 1000 fires per tick)
          final fires = math.min(1000, 1 + ((-entry.remainingTime) / entry.rate).floor());
          entry.remainingTime += fires * entry.rate;
          if (entry.remainingTime <= 0.0) {
            entry.remainingTime = entry.rate;
          }
          toFire.add((entry, fires));
        }
      }
    }

    // 3. Dispatch callbacks with live presence and handle validity check
    for (final item in toFire) {
      final entry = item.$1;
      final count = item.$2;

      if (!entry.handle.isValid) continue;

      if (!entry.looping) {
        entry.handle.invalidate();
        for (int k = 0; k < count; k++) {
          entry.callback();
        }
      } else {
        if (_timers.containsKey(entry.handle.id)) {
          for (int k = 0; k < count; k++) {
            if (!_timers.containsKey(entry.handle.id) || !entry.handle.isValid) break;
            entry.callback();
          }
        }
      }
    }
  }

  @override
  void onWorldShutdown() {
    clearAllTimers();
  }
}
