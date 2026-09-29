/// Typed key/value memory storage used by Behavior Trees, Perception, and AI Controllers.
class LuminaBlackboard {
  final Map<String, dynamic> _data = {};
  final Map<String, List<void Function(String key)>> _observers = {};

  /// Sets [value] for [key]. Notifies registered observers if the value changed.
  void setValue<T>(String key, T value) {
    if (_data.containsKey(key)) {
      final existing = _data[key];
      if (existing == value) return;
    }
    _data[key] = value;
    _notifyObservers(key);
  }

  /// Retrieves the value for [key] as type [T]. Returns null if missing or if the type does not match.
  T? getValue<T>(String key) {
    final val = _data[key];
    if (val is T) return val;
    return null;
  }

  /// Returns true if [key] is present in the blackboard.
  bool hasValue(String key) => _data.containsKey(key);

  /// Clears the value for [key] and notifies registered observers.
  void clearValue(String key) {
    if (_data.containsKey(key)) {
      _data.remove(key);
      _notifyObservers(key);
    }
  }

  /// Adds a change listener for [key]. Returns an unsubscribe closure.
  void Function() addObserver(String key, void Function(String key) onChanged) {
    final list = _observers.putIfAbsent(key, () => []);
    list.add(onChanged);
    return () {
      list.remove(onChanged);
    };
  }

  void _notifyObservers(String key) {
    final list = _observers[key];
    if (list != null) {
      final snapshot = List<void Function(String)>.from(list);
      for (final cb in snapshot) {
        cb(key);
      }
    }
  }
}
