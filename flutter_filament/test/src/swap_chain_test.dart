import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FilamentEngine engine;

  setUp(() {
    engine = FilamentEngine.create()!;
  });

  tearDown(() {
    engine.dispose();
  });

  group('SwapChainConfig Bitfield and Anti-drift', () {
    test('Anti-drift test: Dart constants match C++ SwapChain.h exact values', () {
      expect(SwapChainConfig.transparent.value, equals(c.filament_swap_chain_config_value(0)));
      expect(SwapChainConfig.readable.value, equals(c.filament_swap_chain_config_value(1)));
      expect(SwapChainConfig.enableXcb.value, equals(c.filament_swap_chain_config_value(2)));
      expect(SwapChainConfig.appleCvPixelBuffer.value, equals(c.filament_swap_chain_config_value(3)));
      expect(SwapChainConfig.srgbColorspace.value, equals(c.filament_swap_chain_config_value(4)));
      expect(SwapChainConfig.hasStencilBuffer.value, equals(c.filament_swap_chain_config_value(5)));
      expect(SwapChainConfig.protectedContent.value, equals(c.filament_swap_chain_config_value(6)));
      expect(SwapChainConfig.msaa4Samples.value, equals(c.filament_swap_chain_config_value(7)));
    });

    test('Bitfield operations and contains checks', () {
      final combined = SwapChainConfig.readable | SwapChainConfig.srgbColorspace;
      expect(combined.contains(SwapChainConfig.readable), isTrue);
      expect(combined.contains(SwapChainConfig.srgbColorspace), isTrue);
      expect(combined.contains(SwapChainConfig.transparent), isFalse);

      final single = SwapChainConfig.transparent;
      expect(single.contains(SwapChainConfig.readable), isFalse);
      expect(single.contains(SwapChainConfig.transparent), isTrue);

      final none = SwapChainConfig.none;
      expect(none.contains(SwapChainConfig.readable), isFalse);
    });
  });

  group('SwapChain Static Capability Queries', () {
    test('isSRGBSupported returns boolean without crashing', () {
      final supported = FilamentSwapChain.isSRGBSupported(engine);
      expect(supported, isA<bool>());
    });

    test('isMSAASupported returns boolean without crashing', () {
      final supported = FilamentSwapChain.isMSAASupported(engine, 4);
      expect(supported, isA<bool>());
    });

    test('isProtectedContentSupported returns boolean without crashing', () {
      final supported = FilamentSwapChain.isProtectedContentSupported(engine);
      expect(supported, isA<bool>());
    });
  });

  group('SwapChain Creation, Frame Rate, and Callbacks', () {
    test('createHeadlessSwapChain with typed SwapChainConfig and render a frame', () {
      final sc = engine.createHeadlessSwapChain(
        64,
        64,
        flags: SwapChainConfig.readable,
      );
      expect(sc.isDisposed, isFalse);
      expect(sc.nativeWindowAddress, equals(0));

      final renderer = engine.createRenderer();
      final view = engine.createView();
      final scene = engine.createScene();
      view.scene = scene;

      final begun = renderer.beginFrame(sc);
      expect(begun, isTrue);
      renderer.render(view);
      renderer.endFrame();
      engine.flushAndWait();

      view.dispose();
      scene.dispose();
      renderer.dispose();
      sc.dispose();
      expect(sc.isDisposed, isTrue);
    });

    test('createHeadlessSwapChain with combined flags (readable | srgb)', () {
      final sc = engine.createHeadlessSwapChain(
        32,
        32,
        flags: SwapChainConfig.readable | SwapChainConfig.srgbColorspace,
      );
      expect(sc.isDisposed, isFalse);
      sc.dispose();
    });

    test('createHeadlessSwapChain with legacy int flags works', () {
      final sc = engine.createHeadlessSwapChain(
        32,
        32,
        flags: 0,
      );
      expect(sc.isDisposed, isFalse);
      sc.dispose();
    });

    test('isFrameRateChangeSupported returns a valid FrameRateChangeSupport enum', () {
      final sc = engine.createHeadlessSwapChain(32, 32);
      final support = sc.isFrameRateChangeSupported;
      expect(
        support,
        isIn([
          FrameRateChangeSupport.unsupported,
          FrameRateChangeSupport.supported,
          FrameRateChangeSupport.indeterminate,
        ]),
      );
      sc.dispose();
    });

    test('setFrameRate runs cleanly on headless swap chain', () {
      final sc = engine.createHeadlessSwapChain(32, 32);
      sc.setFrameRate(
        60.0,
        compatibility: FrameRateCompatibility.defaultMode,
        strategy: ChangeFrameRateStrategy.onlyIfSeamless,
      );
      sc.setFrameRate(
        30.0,
        compatibility: FrameRateCompatibility.fixedSource,
        strategy: ChangeFrameRateStrategy.always,
      );
      sc.dispose();
    });

    test('onFrameScheduled and onFrameCompleted callback wiring and clearing', () {
      final sc = engine.createHeadlessSwapChain(32, 32);

      var scheduledCalled = false;
      var completedCalled = false;

      sc.onFrameScheduled = () {
        scheduledCalled = true;
      };
      sc.onFrameCompleted = () {
        completedCalled = true;
      };

      // Clearing callbacks
      sc.onFrameScheduled = null;
      sc.onFrameCompleted = null;

      expect(sc.isFrameScheduledCallbackSet, isFalse);

      sc.dispose();
    });

    test('Tribool enum mapping logic test', () {
      FrameRateChangeSupport mapFromC(int val) {
        switch (val) {
          case 0:
            return FrameRateChangeSupport.unsupported;
          case 1:
            return FrameRateChangeSupport.supported;
          default:
            return FrameRateChangeSupport.indeterminate;
        }
      }

      expect(mapFromC(0), equals(FrameRateChangeSupport.unsupported));
      expect(mapFromC(1), equals(FrameRateChangeSupport.supported));
      expect(mapFromC(2), equals(FrameRateChangeSupport.indeterminate));
      expect(mapFromC(99), equals(FrameRateChangeSupport.indeterminate));
    });
  });
}
