import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';

/// The stall audit reports sections that held the isolate longer than its threshold.
void main() {
  setUp(() {
    FilamentStallAudit.clear();
    FilamentStallAudit.threshold = const Duration(milliseconds: 8);
  });

  test('a section that blocks 40 ms is reported with its name and duration', () async {
    final seen = <FilamentStall>[];
    final sub = FilamentStallAudit.stalls.listen(seen.add);
    addTearDown(sub.cancel);
    final result = FilamentStallAudit.section('scene setup', () {
      sleep(const Duration(milliseconds: 40));
      return 42;
    });
    expect(result, 42);
    await Future<void>.delayed(Duration.zero);
    expect(seen.single.name, 'scene setup');
    expect(seen.single.duration.inMilliseconds, greaterThanOrEqualTo(40));
    expect(FilamentStallAudit.recent.single.toString(), contains('scene setup took'));
  });

  test('a fast section is not a stall; an awaited section counts its wait', () async {
    FilamentStallAudit.section('cheap', () {});
    expect(FilamentStallAudit.recent, isEmpty);
    await FilamentStallAudit.sectionAsync('upload wait', () => Future<void>.delayed(const Duration(milliseconds: 20)));
    expect(FilamentStallAudit.recent.single.name, 'upload wait');
  });

  test('recent keeps the last 64 stalls', () {
    for (var i = 0; i < 70; i++) {
      FilamentStallAudit.record('s$i', const Duration(milliseconds: 9));
    }
    expect(FilamentStallAudit.recent.length, FilamentStallAudit.capacity);
    expect(FilamentStallAudit.recent.first.name, 's6');
    expect(FilamentStallAudit.recent.last.name, 's69');
  });
}
