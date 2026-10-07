import 'package:flutter/foundation.dart';
import 'package:lumina_core/lumina_core.dart' show ChangeSignal, Observable;

/// Flutter views of the pure change types (`lumina_core`'s [ChangeSignal]
/// and [Observable], used by plugin processes) and pure views of Flutter's,
/// so a widget can listen to a process-side value and a Flutter notifier can
/// feed a process-side API.
///
/// The views forward [addListener] / [removeListener] to their source and
/// read its current value; they keep no state of their own. Asking for the
/// view of the same source twice returns the same object, so a widget that
/// calls `asValueListenable()` in `build` does not resubscribe every frame.
extension ObservableAsValueListenable<T> on Observable<T> {
  /// This observable as a Flutter [ValueListenable] (for a
  /// `ValueListenableBuilder`).
  ValueListenable<T> asValueListenable() {
    final self = this;
    if (self is _ListenableObservable<T>) return self.source;
    return (_valueViews[this] ??= _ObservableListenable<T>(this)) as ValueListenable<T>;
  }
}

/// See [ObservableAsValueListenable].
extension ChangeSignalAsListenable on ChangeSignal {
  /// This signal as a Flutter [Listenable] (for a `ListenableBuilder`).
  Listenable asListenable() {
    final self = this;
    if (self is _ListenableSignal) return self.source;
    return _signalViews[this] ??= _SignalListenable(this);
  }
}

/// See [ObservableAsValueListenable].
extension ValueListenableAsObservable<T> on ValueListenable<T> {
  /// This listenable as a pure [Observable] (for a plugin process API, e.g.
  /// a `PluginProcessSlotButton.state` or a menu item's `checked`).
  Observable<T> asObservable() {
    final self = this;
    if (self is _ObservableListenable<T>) return self.source;
    return (_observableViews[this] ??= _ListenableObservable<T>(this)) as Observable<T>;
  }
}

/// See [ObservableAsValueListenable].
extension ListenableAsChangeSignal on Listenable {
  /// This listenable as a pure [ChangeSignal].
  ChangeSignal asChangeSignal() {
    final self = this;
    if (self is _SignalListenable) return self.source;
    return _changeViews[this] ??= _ListenableSignal(this);
  }
}

final Expando<Object> _valueViews = Expando('asValueListenable');
final Expando<Listenable> _signalViews = Expando('asListenable');
final Expando<Object> _observableViews = Expando('asObservable');
final Expando<ChangeSignal> _changeViews = Expando('asChangeSignal');

class _ObservableListenable<T> implements ValueListenable<T> {
  _ObservableListenable(this.source);

  final Observable<T> source;

  @override
  T get value => source.value;

  @override
  void addListener(VoidCallback listener) => source.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => source.removeListener(listener);
}

class _SignalListenable implements Listenable {
  _SignalListenable(this.source);

  final ChangeSignal source;

  @override
  void addListener(VoidCallback listener) => source.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => source.removeListener(listener);
}

class _ListenableObservable<T> extends Observable<T> {
  _ListenableObservable(this.source);

  final ValueListenable<T> source;

  @override
  T get value => source.value;

  @override
  void addListener(void Function() listener) => source.addListener(listener);

  @override
  void removeListener(void Function() listener) => source.removeListener(listener);
}

class _ListenableSignal extends ChangeSignal {
  _ListenableSignal(this.source);

  final Listenable source;

  @override
  void addListener(void Function() listener) => source.addListener(listener);

  @override
  void removeListener(void Function() listener) => source.removeListener(listener);
}
