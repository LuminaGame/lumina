import 'package:meta/meta.dart';

/// Something that tells its listeners it changed, without Flutter: the pure
/// counterpart of Flutter's `Listenable`, for code that must run in a plain
/// `dart` program (a plugin process, a CLI tool, a server).
///
/// The member names match Flutter's, so code that only calls [addListener]
/// and [removeListener] reads the same against either. A Flutter package
/// adapts one to the other (`lumina_editor_api`: `asListenable()`,
/// `asChangeSignal()`).
abstract class ChangeSignal {
  const ChangeSignal();

  /// Calls [listener] after every change. Adding the same function twice
  /// calls it twice.
  void addListener(void Function() listener);

  /// Removes one registration of [listener]; nothing happens when it is not
  /// registered.
  void removeListener(void Function() listener);
}

/// A [ChangeSignal] that also holds a current [value]: the pure counterpart
/// of Flutter's `ValueListenable` (adapted with `asValueListenable()` /
/// `asObservable()` in `lumina_editor_api`).
abstract class Observable<T> implements ChangeSignal {
  const Observable();

  /// The current value; listeners are told when it changes.
  T get value;
}

/// The usual [ChangeSignal]: keeps its listeners and calls them on
/// [notifyListeners]. Extend it (as Flutter code extends `ChangeNotifier`)
/// or hold one and notify it.
class ChangeEmitter implements ChangeSignal {
  List<void Function()>? _listeners = [];

  /// Whether anything listens.
  bool get hasListeners => _listeners?.isNotEmpty ?? false;

  /// Whether [dispose] ran.
  bool get isDisposed => _listeners == null;

  @override
  void addListener(void Function() listener) {
    final listeners = _listeners;
    if (listeners == null) throw StateError('$runtimeType was used after dispose()');
    listeners.add(listener);
  }

  @override
  void removeListener(void Function() listener) => _listeners?.remove(listener);

  /// Calls every listener registered now, in the order they were added. A
  /// listener added or removed by another listener takes effect from the
  /// next notification. A listener that throws does not stop the others; the
  /// first error is rethrown after all of them ran.
  void notifyListeners() {
    final listeners = _listeners;
    if (listeners == null || listeners.isEmpty) return;
    Object? error;
    StackTrace? stack;
    for (final l in List.of(listeners)) {
      try {
        l();
      } catch (e, s) {
        error ??= e;
        stack ??= s;
      }
    }
    if (error != null) Error.throwWithStackTrace(error, stack!);
  }

  /// Drops every listener; adding one afterwards is a [StateError],
  /// notifying does nothing.
  @mustCallSuper
  void dispose() => _listeners = null;
}

/// An [Observable] whose [value] is set from outside: the pure counterpart
/// of Flutter's `ValueNotifier`. Setting a value that is `==` to the current
/// one notifies nobody.
class ObservableValue<T> extends ChangeEmitter implements Observable<T> {
  ObservableValue(this._value);

  T _value;

  @override
  T get value => _value;

  set value(T next) {
    if (next == _value) return;
    _value = next;
    notifyListeners();
  }

  @override
  String toString() => 'ObservableValue($_value)';
}
