import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FilamentEngine engine;
  late FilamentSwapChain swapChain;
  late FilamentRenderer renderer;
  late FilamentView view;
  late FilamentScene scene;

  setUp(() {
    engine = FilamentEngine.create()!;
    swapChain = engine.createHeadlessSwapChain(64, 64);
    renderer = engine.createRenderer();
    view = engine.createView();
    scene = engine.createScene();
    view.scene = scene;
  });

  tearDown(() {
    view.dispose();
    scene.dispose();
    renderer.dispose();
    swapChain.dispose();
    engine.dispose();
  });

  group('DebugRegistry Operations and Properties', () {
    test('engine.debugRegistry returns valid handle', () {
      final reg1 = engine.debugRegistry;
      final reg2 = engine.debugRegistry;
      expect(reg1, equals(reg2));
      expect(reg1.hasProperty('this.does.not.exist'), isFalse);
    });

    test('missing property returns null for getters and false for setters', () {
      final reg = engine.debugRegistry;
      const bogus = 'completely.nonexistent.property.12345';

      expect(reg.hasProperty(bogus), isFalse);
      expect(reg.getBool(bogus), isNull);
      expect(reg.getInt(bogus), isNull);
      expect(reg.getDouble(bogus), isNull);
      expect(reg.getVec2(bogus), isNull);
      expect(reg.getVec3(bogus), isNull);
      expect(reg.getVec4(bogus), isNull);

      expect(reg.setBool(bogus, true), isFalse);
      expect(reg.setInt(bogus, 42), isFalse);
      expect(reg.setDouble(bogus, 3.14), isFalse);
      expect(reg.setVec2(bogus, 1.0, 2.0), isFalse);
      expect(reg.setVec3(bogus, 1.0, 2.0, 3.0), isFalse);
      expect(reg.setVec4(bogus, 1.0, 2.0, 3.0, 4.0), isFalse);
    });

    test('real engine property d.renderer.disable_subpasses roundtrip and survives frame', () {
      // Pinned real property from filament/filament/src/details/Renderer.cpp line 121:
      // debugRegistry.registerProperty("d.renderer.disable_subpasses", &engine.debug.renderer.disable_subpasses);
      final reg = engine.debugRegistry;
      const prop = 'd.renderer.disable_subpasses';

      expect(reg.hasProperty(prop), isTrue);

      final initial = reg.getBool(prop);
      expect(initial, isA<bool>());

      // Set to true
      expect(reg.setBool(prop, true), isTrue);
      expect(reg.getBool(prop), isTrue);

      // Render 1 frame
      final begun = renderer.beginFrame(swapChain);
      expect(begun, isTrue);
      renderer.render(view);
      renderer.endFrame();
      engine.flushAndWait();

      // Property value should persist
      expect(reg.getBool(prop), isTrue);

      // Reset to false
      expect(reg.setBool(prop, false), isTrue);
      expect(reg.getBool(prop), isFalse);
    });

    test('real engine int and float property roundtrips', () {
      // From filament/src/details/Renderer.cpp line 125 & 137:
      // "d.shadowmap.display_shadow_texture_scale" (int)
      // "d.shadowmap.display_shadow_texture_power" (float)
      final reg = engine.debugRegistry;
      const intProp = 'd.shadowmap.display_shadow_texture_scale';
      const floatProp = 'd.shadowmap.display_shadow_texture_power';

      expect(reg.hasProperty(intProp), isTrue);
      expect(reg.hasProperty(floatProp), isTrue);

      expect(reg.setInt(intProp, 3), isTrue);
      expect(reg.getInt(intProp), equals(3));

      expect(reg.setDouble(floatProp, 2.5), isTrue);
      expect(reg.getDouble(floatProp), closeTo(2.5, 0.001));
    });

    test('non-existent property returns null without crashing', () {
      final reg = engine.debugRegistry;
      const prop = 'd.renderer.nonexistent_property';

      expect(reg.hasProperty(prop), isFalse);
      expect(reg.getDouble(prop), isNull);
      expect(reg.getInt(prop), isNull);
      expect(reg.getVec2(prop), isNull);
    });

    test('getDataSource returns null for bogus name and does not crash', () {
      final reg = engine.debugRegistry;
      expect(reg.getDataSource('bogus_source'), isNull);
    });
  });
}
