import 'dart:collection';
import 'package:lumina/src/controller/player_state.dart';

/// The phase of a match.
enum LuminaMatchState {
  waitingToStart,
  inProgress,
  waitingPostMatch,
}

/// The shared, observable snapshot of match state and player states.
class LuminaGameState {
  LuminaMatchState _matchState = LuminaMatchState.waitingToStart;
  final List<LuminaPlayerState> _playerArray = [];
  double _elapsedTime = 0.0;
  final List<void Function()> _listeners = [];

  /// Gets the unmodifiable list of connected player states.
  List<LuminaPlayerState> get playerArray => UnmodifiableListView(_playerArray);

  /// Gets the current match state.
  LuminaMatchState get matchState => _matchState;

  /// Gets the elapsed time of the match in seconds.
  /// Accumulates only while [matchState] is [LuminaMatchState.inProgress].
  double get elapsedTime => _elapsedTime;

  /// Whether the match has started.
  bool get hasMatchStarted =>
      _matchState == LuminaMatchState.inProgress || _matchState == LuminaMatchState.waitingPostMatch;

  /// Whether the match has ended.
  bool get hasMatchEnded => _matchState == LuminaMatchState.waitingPostMatch;

  /// Adds a player state to the game state.
  void addPlayerState(LuminaPlayerState state) {
    if (_playerArray.contains(state)) return;
    _playerArray.add(state);
    notifyChanged();
  }

  /// Removes a player state from the game state.
  void removePlayerState(LuminaPlayerState state) {
    if (_playerArray.remove(state)) {
      notifyChanged();
    }
  }

  /// Looks up a player state by ID.
  LuminaPlayerState? getPlayerStateById(int playerId) {
    for (final state in _playerArray) {
      if (state.playerId == playerId) return state;
    }
    return null;
  }

  /// Transitions the match state. Throws [StateError] for illegal backwards transitions.
  void setMatchState(LuminaMatchState next) {
    if (_matchState == next) return;

    if (_matchState == LuminaMatchState.waitingPostMatch) {
      throw StateError('Cannot transition out of waitingPostMatch');
    }
    if (_matchState == LuminaMatchState.inProgress && next == LuminaMatchState.waitingToStart) {
      throw StateError('Cannot transition from inProgress to waitingToStart');
    }

    _matchState = next;
    notifyChanged();
  }

  /// Called during world tick phase 2 to accumulate elapsed time.
  void tick(double deltaTime) {
    if (_matchState == LuminaMatchState.inProgress) {
      _elapsedTime += deltaTime;
    }
  }

  /// Adds a listener for changes to this game state.
  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  /// Removes a listener from this game state.
  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  /// Notifies listeners that the state has changed.
  void notifyChanged() {
    for (final listener in List<void Function()>.from(_listeners)) {
      listener();
    }
  }
}
