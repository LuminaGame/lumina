import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_widgets/lumina_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(LuminaWindowModeChannel.channelName);

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    LuminaGameWindow.resetForTesting();
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
}
