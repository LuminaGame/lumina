import 'package:lumina_core/lumina_core.dart';
import 'package:test/test.dart';

void main() {
  test('ChangeEmitter calls its listeners in order; removing one stops it', () {
    final signal = ChangeEmitter();
    final calls = <String>[];
    void a() => calls.add('a');
    void b() => calls.add('b');
    signal
      ..addListener(a)
      ..addListener(b);
    expect(signal.hasListeners, isTrue);
    signal.notifyListeners();
    signal.removeListener(a);
    signal.notifyListeners();
    expect(calls, ['a', 'b', 'b']);
  });

  test('a listener added while notifying runs from the next notification', () {
    final signal = ChangeEmitter();
    final calls = <String>[];
    void late() => calls.add('late');
    signal.addListener(() {
      calls.add('first');
      signal.addListener(late);
    });
    signal.notifyListeners();
    expect(calls, ['first']);
    signal.notifyListeners();
    expect(calls, ['first', 'first', 'late']);
  });

  test('a throwing listener does not stop the others and its error is rethrown', () {
    final signal = ChangeEmitter();
    var after = 0;
    signal
      ..addListener(() => throw StateError('listener broke'))
      ..addListener(() => after++);
    expect(signal.notifyListeners, throwsStateError);
    expect(after, 1);
  });

  test('dispose drops the listeners; adding one afterwards fails', () {
    final signal = ChangeEmitter();
    var calls = 0;
    signal.addListener(() => calls++);
    signal.dispose();
    signal.notifyListeners();
    expect(calls, 0);
    expect(signal.isDisposed, isTrue);
    expect(() => signal.addListener(() {}), throwsStateError);
  });

  test('ObservableValue notifies only when the value changes', () {
    final count = ObservableValue(1);
    final seen = <int>[];
    count.addListener(() => seen.add(count.value));
    count.value = 1;
    count.value = 2;
    count.value = 2;
    count.value = 3;
    expect(seen, [2, 3]);
    final Observable<int> read = count;
    expect(read.value, 3);
  });
}
