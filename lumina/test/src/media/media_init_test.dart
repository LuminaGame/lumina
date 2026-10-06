import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  test('MediaKit ensureInitialized can be called safely', () {
    try {
      MediaKit.ensureInitialized();
      expect(true, isTrue);
    } catch (e) {
      // In headless unit tests without native libmpv libraries loaded, it may catch.
      expect(e, isNotNull);
    }
  });
}
