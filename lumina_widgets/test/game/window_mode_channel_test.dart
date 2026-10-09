import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_widgets/lumina_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(LuminaWindowModeChannel.channelName);

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    LuminaGameWindow.resetForTesting();
    LuminaGameDisplay.resetForTesting();
  });

  test('speaks the runner protocol: getMode / setMode with the mode id', () async {
    var runnerMode = 'borderless_fullscreen';
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'getMode':
          return runnerMode;
        case 'setMode':
          runnerMode = (call.arguments as Map)['mode'] as String;
          return true;
      }
      return null;
    });
    final backend = LuminaWindowModeChannel();
    expect(await backend.getMode(), LuminaWindowMode.borderlessFullscreen);
    expect(await backend.setMode(LuminaWindowMode.windowed), isTrue);
    expect(runnerMode, 'windowed');
    expect(calls.map((c) => c.method), ['getMode', 'setMode']);
  });

  test('a runner without window-mode support reports no mode and applies nothing', () async {
    final backend = LuminaWindowModeChannel();
    expect(await backend.getMode(), isNull);
    expect(await backend.setMode(LuminaWindowMode.borderlessFullscreen), isFalse);
  });

  test('the runner toggling (Alt+Enter / F11) reaches the game window', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => call.method == 'getMode' ? 'windowed' : true);
    LuminaGameWindow.backend = LuminaWindowModeChannel();
    await LuminaGameWindow.restore();
    expect(LuminaGameWindow.mode.value, LuminaWindowMode.windowed);

    await messenger.handlePlatformMessage(
      LuminaWindowModeChannel.channelName,
      const StandardMethodCodec().encodeMethodCall(const MethodCall('modeChanged', {'mode': 'borderless_fullscreen'})),
      (_) {},
    );
    expect(LuminaGameWindow.mode.value, LuminaWindowMode.borderlessFullscreen);
  });

  test('speaks the display protocol: getDisplays, setClientSize, moveToMonitor, displayChanged', () async {
    final calls = <MethodCall>[];
    final displays = {
      'monitors': [
        {
          'name': 'DELL U3419W',
          'device': r'\.\DISPLAY1',
          'primary': true,
          'bounds': [0, 0, 3440, 1440],
          'work': [0, 0, 3440, 1392],
          'current': [3440, 1440, 60],
          'modes': [
            [3440, 1440, 60],
            [1920, 1080, 60],
            [1920, 1080, 100],
          ],
          'scale': 1.0,
        },
      ],
      'current': 0,
      'client': [1280, 720],
    };
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'getDisplays':
          return displays;
        case 'setClientSize':
          final args = call.arguments as Map;
          return [args['width'], args['height']];
        case 'moveToMonitor':
          return (call.arguments as Map)['index'] == 0;
      }
      return null;
    });
    final backend = LuminaWindowModeChannel();
    final info = (await backend.queryDisplays())!;
    expect(info.current!.resolutions, [(1920, 1080), (3440, 1440)]);
    expect(info.current!.refreshRatesFor(1920, 1080), [60, 100]);
    expect(info.clientSize, (1280, 720));
    expect(await backend.setClientSize(1920, 1080), (1920, 1080));
    expect(await backend.moveToMonitor(0), isTrue);
    expect(await backend.moveToMonitor(3), isFalse);
    expect([for (final c in calls) c.method], ['getDisplays', 'setClientSize', 'moveToMonitor', 'moveToMonitor']);

    LuminaDisplayInfo? changed;
    backend.onDisplayChanged = (next) => changed = next;
    await messenger.handlePlatformMessage(
      LuminaWindowModeChannel.channelName,
      const StandardMethodCodec().encodeMethodCall(MethodCall('displayChanged', displays)),
      (_) {},
    );
    expect(changed?.monitors.single.name, 'DELL U3419W');
  });

  test('a runner without display support reports nothing and resizes nothing', () async {
    final backend = LuminaWindowModeChannel();
    expect(await backend.queryDisplays(), isNull);
    expect(await backend.setClientSize(1920, 1080), isNull);
    expect(await backend.moveToMonitor(1), isFalse);
  });

  testWidgets('the game view keeps its element while the screen resolution letterboxes it', (tester) async {
    final resolution = ObservableValue<(int, int)?>(null);
    final sizes = <Size?>[];
    tester.view.physicalSize = const Size(3440, 1440);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: LuminaScreenResolutionBox(
        resolution: resolution,
        builder: (context, render) {
          sizes.add(render);
          return const _ViewProbe();
        },
      ),
    ));
    final element = tester.element(find.byType(_ViewProbe));
    expect(tester.getSize(find.byType(_ViewProbe)), const Size(3440, 1440));

    resolution.value = (1920, 1080);
    await tester.pump();
    expect(tester.element(find.byType(_ViewProbe)), same(element));
    expect(sizes.last, const Size(1920, 1080));
    // 16:9 on 43:18: pillarboxed to the full height.
    expect(tester.getSize(find.byType(_ViewProbe)), const Size(2560, 1440));
    expect(tester.getTopLeft(find.byType(_ViewProbe)), const Offset(440, 0));
  });
}

class _ViewProbe extends StatelessWidget {
  const _ViewProbe();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
