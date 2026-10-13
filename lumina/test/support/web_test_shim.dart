/// The browser side of [test_api.dart]: `test`, `group`, the set-up and
/// tear-down hooks and `expect` over `package:matcher`, collected into
/// [webTests] and run in order by [runWebTests] (the physics web smoke app,
/// example/lib/physics_web_smoke.dart). Only what the tests it runs use.
library;

import 'dart:async';

import 'package:matcher/matcher.dart';

export 'package:matcher/matcher.dart';

/// A registered test: its full name and body, with the hooks of its groups.
class WebTest {
  WebTest(this.name, this.body, this.setUps, this.tearDowns);

  final String name;
  final FutureOr<void> Function() body;
  final List<FutureOr<void> Function()> setUps;
  final List<FutureOr<void> Function()> tearDowns;
}

/// The outcome of one test.
class WebTestResult {
  WebTestResult(this.name, this.error, this.millis);

  final String name;
  final String? error;
  final int millis;

  bool get passed => error == null;
}

final List<WebTest> webTests = [];
final List<FutureOr<void> Function()> _setUpAlls = [];
final List<FutureOr<void> Function()> _tearDownAlls = [];

class _Group {
  _Group(this.name);
  final String name;
  final List<FutureOr<void> Function()> setUps = [];
  final List<FutureOr<void> Function()> tearDowns = [];
}

final List<_Group> _groups = [_Group('')];
List<FutureOr<void> Function()> _pendingTearDowns = [];

void group(Object description, void Function() body) {
  _groups.add(_Group('$description'));
  try {
    body();
  } finally {
    _groups.removeLast();
  }
}

void test(Object description, FutureOr<void> Function() body,
    {Object? skip, Object? timeout, Object? tags, Object? testOn, Object? onPlatform, int? retry}) {
  if (skip != null && skip != false) return;
  final name = [for (final g in _groups) if (g.name.isNotEmpty) g.name, '$description'].join(' ');
  webTests.add(WebTest(
    name,
    body,
    [for (final g in _groups) ...g.setUps],
    [for (final g in _groups.reversed) ...g.tearDowns],
  ));
}

void setUp(FutureOr<void> Function() body) => _groups.last.setUps.add(body);
void tearDown(FutureOr<void> Function() body) => _groups.last.tearDowns.add(body);
void setUpAll(FutureOr<void> Function() body) => _setUpAlls.add(body);
void tearDownAll(FutureOr<void> Function() body) => _tearDownAlls.add(body);
void addTearDown(FutureOr<void> Function() body) => _pendingTearDowns.add(body);

class _Failure implements Exception {
  _Failure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Fails the running test unless [actual] matches [matcher].
void expect(dynamic actual, dynamic matcher, {String? reason, Object? skip}) {
  if (skip != null && skip != false) return;
  final m = wrapMatcher(matcher);
  final state = <dynamic, dynamic>{};
  if (m.matches(actual, state)) return;
  final description = StringDescription()..add('Expected: ').addDescriptionOf(m);
  description.add('\n  Actual: ').addDescriptionOf(actual);
  final mismatch = m.describeMismatch(actual, StringDescription(), state, false).toString();
  if (mismatch.isNotEmpty) description.add('\n   Which: $mismatch');
  if (reason != null) description.add('\n$reason');
  throw _Failure(description.toString());
}

/// Matches a function that throws a [T] when called.
class _Throws<T> extends Matcher {
  const _Throws(this.label);
  final String label;

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    if (item is! Function) return false;
    try {
      (item as dynamic)();
      return false;
    } catch (e) {
      return e is T;
    }
  }

  @override
  Description describe(Description description) => description.add('throws $label');
}

const Matcher throwsArgumentError = _Throws<ArgumentError>('ArgumentError');
const Matcher throwsStateError = _Throws<StateError>('StateError');

/// Runs every registered test in order (set-up-all hooks first), calling
/// [onResult] after each.
Future<List<WebTestResult>> runWebTests({void Function(WebTestResult result)? onResult}) async {
  final results = <WebTestResult>[];
  for (final s in _setUpAlls) {
    await s();
  }
  for (final t in webTests) {
    final watch = Stopwatch()..start();
    String? error;
    _pendingTearDowns = [];
    try {
      for (final s in t.setUps) {
        await s();
      }
      await t.body();
    } catch (e, st) {
      error = e is _Failure ? e.message : '$e\n$st';
    }
    for (final d in [..._pendingTearDowns.reversed, ...t.tearDowns]) {
      try {
        await d();
      } catch (e) {
        error ??= 'tear-down: $e';
      }
    }
    final result = WebTestResult(t.name, error, watch.elapsedMilliseconds);
    results.add(result);
    onResult?.call(result);
  }
  for (final d in _tearDownAlls) {
    await d();
  }
  return results;
}
