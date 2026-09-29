import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bookmark Tests', () {
    test('ORBIT manipulator: currentBookmark save, navigate, jumpToBookmark restore', () {
      final builder = FilamentManipulatorBuilder()
        ..viewport(800, 600)
        ..targetPosition(0.0, 0.0, 0.0)
        ..orbitHomePosition(0.0, 0.0, 5.0)
        ..upVector(0.0, 1.0, 0.0);

      final manip = builder.build(ManipulatorMode.orbit);
      manip.update(0.016);

      final eye0 = manip.getEye();
      final bookmark = manip.currentBookmark;

      // Orbit away
      manip.grabBegin(100, 100, strafe: false);
      manip.grabUpdate(300, 300);
      manip.grabEnd();
      manip.update(0.016);

      final eyeMoved = manip.getEye();
      expect(eyeMoved.x != eye0.x || eyeMoved.y != eye0.y || eyeMoved.z != eye0.z, isTrue);

      // Jump back
      manip.jumpToBookmark(bookmark);
      manip.update(0.016);

      final eyeRestored = manip.getEye();

      expect(eyeRestored.x, closeTo(eye0.x, 1e-4));
      expect(eyeRestored.y, closeTo(eye0.y, 1e-4));
      expect(eyeRestored.z, closeTo(eye0.z, 1e-4));

      bookmark.dispose();
      manip.dispose();
      builder.dispose();
    });

    test('homeBookmark restores initial pose after navigation', () {
      final builder = FilamentManipulatorBuilder()
        ..viewport(800, 600)
        ..targetPosition(0.0, 0.0, 0.0)
        ..orbitHomePosition(0.0, 0.0, 5.0)
        ..upVector(0.0, 1.0, 0.0);

      final manip = builder.build(ManipulatorMode.orbit);
      final homeBookmark = manip.homeBookmark;
      manip.jumpToBookmark(homeBookmark);
      manip.update(0.016);

      final eyeHome = manip.getEye();

      // Navigate
      manip.grabBegin(50, 50, strafe: false);
      manip.grabUpdate(200, 400);
      manip.grabEnd();
      manip.update(0.016);

      manip.jumpToBookmark(homeBookmark);
      manip.update(0.016);

      final eyeRestored = manip.getEye();

      expect(eyeRestored.x, closeTo(eyeHome.x, 1e-4));
      expect(eyeRestored.y, closeTo(eyeHome.y, 1e-4));
      expect(eyeRestored.z, closeTo(eyeHome.z, 1e-4));

      homeBookmark.dispose();
      manip.dispose();
      builder.dispose();
    });

    test('Bookmark.interpolate: endpoints t=0 and t=1 match a and b', () {
      final builder = FilamentManipulatorBuilder()
        ..viewport(800, 600)
        ..targetPosition(0.0, 0.0, 0.0)
        ..orbitHomePosition(0.0, 0.0, 5.0);

      final manip = builder.build(ManipulatorMode.orbit);
      manip.update(0.016);

      final bookmarkA = manip.currentBookmark;

      manip.grabBegin(100, 100, strafe: false);
      manip.grabUpdate(250, 250);
      manip.grabEnd();
      manip.update(0.016);

      final bookmarkB = manip.currentBookmark;

      manip.jumpToBookmark(bookmarkB);
      manip.update(0.016);
      final eyeB = manip.getEye();

      // Interpolate t=0.0
      final interp0 = Bookmark.interpolate(bookmarkA, bookmarkB, 0.0);
      manip.jumpToBookmark(interp0);
      manip.update(0.016);
      final eye0 = manip.getEye();

      manip.jumpToBookmark(bookmarkA);
      manip.update(0.016);
      final eyeA = manip.getEye();

      expect(eye0.x, closeTo(eyeA.x, 1e-4));
      expect(eye0.y, closeTo(eyeA.y, 1e-4));
      expect(eye0.z, closeTo(eyeA.z, 1e-4));

      // Interpolate t=1.0
      final interp1 = Bookmark.interpolate(bookmarkA, bookmarkB, 1.0);
      manip.jumpToBookmark(interp1);
      manip.update(0.016);
      final eye1 = manip.getEye();

      expect(eye1.x, closeTo(eyeB.x, 1e-4));
      expect(eye1.y, closeTo(eyeB.y, 1e-4));
      expect(eye1.z, closeTo(eyeB.z, 1e-4));

      interp0.dispose();
      interp1.dispose();
      bookmarkA.dispose();
      bookmarkB.dispose();
      manip.dispose();
      builder.dispose();
    });

    test('Bookmark.interpolate: midpoint t=0.5 and arc path length test', () {
      final builder = FilamentManipulatorBuilder()
        ..viewport(800, 600)
        ..targetPosition(0.0, 0.0, 0.0)
        ..orbitHomePosition(0.0, 0.0, 10.0);

      final manip = builder.build(ManipulatorMode.orbit);
      manip.update(0.016);

      final bookmarkA = manip.currentBookmark;

      manip.grabBegin(200, 200, strafe: false);
      manip.grabUpdate(500, 500);
      manip.grabEnd();
      manip.update(0.016);

      final bookmarkB = manip.currentBookmark;

      final interpMid = Bookmark.interpolate(bookmarkA, bookmarkB, 0.5);
      manip.jumpToBookmark(interpMid);
      manip.update(0.016);
      final eyeMid = manip.getEye();

      manip.jumpToBookmark(bookmarkA);
      manip.update(0.016);
      final eyeA = manip.getEye();

      manip.jumpToBookmark(bookmarkB);
      manip.update(0.016);
      final eyeB = manip.getEye();

      // Midpoint differs from both endpoints
      final distA = math.sqrt(math.pow(eyeMid.x - eyeA.x, 2) + math.pow(eyeMid.y - eyeA.y, 2) + math.pow(eyeMid.z - eyeA.z, 2));
      final distB = math.sqrt(math.pow(eyeMid.x - eyeB.x, 2) + math.pow(eyeMid.y - eyeB.y, 2) + math.pow(eyeMid.z - eyeB.z, 2));
      expect(distA > 0.01, isTrue);
      expect(distB > 0.01, isTrue);

      // Arc path length >= straight-line distance
      final straightLineDist = math.sqrt(math.pow(eyeB.x - eyeA.x, 2) + math.pow(eyeB.y - eyeA.y, 2) + math.pow(eyeB.z - eyeA.z, 2));
      double cumulativePath = 0.0;
      var prevEye = eyeA;
      for (final t in [0.25, 0.5, 0.75, 1.0]) {
        final b = Bookmark.interpolate(bookmarkA, bookmarkB, t);
        manip.jumpToBookmark(b);
        manip.update(0.016);
        final currEye = manip.getEye();
        cumulativePath += math.sqrt(math.pow(currEye.x - prevEye.x, 2) + math.pow(currEye.y - prevEye.y, 2) + math.pow(currEye.z - prevEye.z, 2));
        prevEye = currEye;
        b.dispose();
      }

      expect(cumulativePath + 1e-4 >= straightLineDist, isTrue);

      interpMid.dispose();
      bookmarkA.dispose();
      bookmarkB.dispose();
      manip.dispose();
      builder.dispose();
    });

    test('Bookmark.duration is > 0 and roughly symmetric', () {
      final builder = FilamentManipulatorBuilder()
        ..viewport(800, 600)
        ..targetPosition(0.0, 0.0, 0.0)
        ..upVector(0.0, 1.0, 0.0)
        ..groundPlane(0.0, 0.0, 1.0, 0.0)
        ..mapExtent(100.0, 100.0)
        ..mapMinDistance(1.0);

      final manip = builder.build(ManipulatorMode.map);
      final bA = manip.homeBookmark;
      manip.jumpToBookmark(bA);
      manip.update(0.016);

      manip.grabBegin(100, 100, strafe: false);
      manip.grabUpdate(400, 400);
      manip.grabEnd();
      manip.scroll(200, 200, 5.0);
      manip.update(0.016);

      final bB = manip.currentBookmark;

      final durAB = Bookmark.duration(bA, bB);
      final durBA = Bookmark.duration(bB, bA);

      expect(durAB.isFinite && durAB > 0.0, isTrue);
      expect((durAB - durBA).abs() < 0.1, isTrue);

      bA.dispose();
      bB.dispose();
      manip.dispose();
      builder.dispose();
    });

    test('100-bookmark create/destroy loop smoke test', () {
      final builder = FilamentManipulatorBuilder()
        ..viewport(800, 600);
      final manip = builder.build(ManipulatorMode.orbit);
      manip.update(0.016);

      for (int i = 0; i < 100; i++) {
        final b = manip.currentBookmark;
        b.dispose();
      }

      manip.dispose();
      builder.dispose();
    });
  });
}
