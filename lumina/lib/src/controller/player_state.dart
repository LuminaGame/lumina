// ignore_for_file: prefer_initializing_formals

import 'dart:math' as math;
import 'package:meta/meta.dart';

int _nextPlayerId = 0;

/// Represents player state data (score, team, name, health, etc.) with change notification.
class LuminaPlayerState {
  /// Resets the static player ID generator counter (for testing).
  @visibleForTesting
  static void resetPlayerIdCounterForTesting() {
    _nextPlayerId = 0;
  }
  String _playerName;
  final int _playerId;
  double _score;
  int _teamId;
  double _health;

  final List<void Function()> _listeners = [];

  LuminaPlayerState({
    String playerName = 'Player',
    int? playerId,
    double score = 0.0,
    int teamId = 0,
    double health = 100.0,
  })  : _playerName = playerName,
        _playerId = playerId ?? _nextPlayerId++,
        _score = score,
        _teamId = teamId,
        _health = math.max(0.0, health);

  /// The player's display name.
  String get playerName => _playerName;
  set playerName(String v) {
    if (_playerName == v) return;
    _playerName = v;
    notifyChanged();
  }

  /// Unique player ID (immutable).
  int get playerId => _playerId;

  /// Player's score.
  double get score => _score;
  set score(double v) {
    if (_score == v) return;
    _score = v;
    notifyChanged();
  }

  /// Adds [delta] to score and notifies listeners.
  void addScore(double delta) {
    score = _score + delta;
  }

  /// Player's team ID.
  int get teamId => _teamId;
  set teamId(int v) {
    if (_teamId == v) return;
    _teamId = v;
    notifyChanged();
  }

  /// Player's current health, clamped to >= 0.
  double get health => _health;
  set health(double v) {
    final clamped = math.max(0.0, v);
    if (_health == clamped) return;
    _health = clamped;
    notifyChanged();
  }

  /// Whether the player is currently alive (health > 0).
  bool get isAlive => _health > 0.0;

  /// Adds a listener callback invoked when any property changes.
  void addListener(void Function() listener) => _listeners.add(listener);

  /// Removes a listener callback.
  void removeListener(void Function() listener) => _listeners.remove(listener);

  /// Notifies all registered listeners of a state change.
  void notifyChanged() {
    for (final listener in List<void Function()>.from(_listeners)) {
      listener();
    }
  }

  /// Restores score to 0.0 and health to 100.0, firing a single notification if changed.
  void reset() {
    final scoreChanged = _score != 0.0;
    final healthChanged = _health != 100.0;
    _score = 0.0;
    _health = 100.0;
    if (scoreChanged || healthChanged) {
      notifyChanged();
    }
  }
}
