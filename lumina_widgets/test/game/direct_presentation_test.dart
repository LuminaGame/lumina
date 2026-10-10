import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_widgets/lumina_widgets.dart';

class _EmptyGame extends LuminaGame {
  @override
  LuminaObject? build(LuminaBuildContext context) => LuminaNodeGroup(children: const []);
}

/// A game asking for Direct presentation where it cannot run stays on
/// Flutter, with the reason in force; asking for Flutter never touches the
/// runner's window.
void main() {
  const channel = MethodChannel(LuminaWindowModeChannel.channelName);
  final calls = <String>[];

  setUp(() {
    calls.clear();
    LuminaGamePresentation.reset();
  });

  tearDown(() {
    LuminaGamePresentation.reset();
    LuminaGameWindow.backend = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  Future<void> mount(WidgetTester tester, LuminaPresentationMode presentation) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: LuminaGameWidget(
        game: _EmptyGame(),
        decorated: false,
        allowDirectPresentation: true,
        presentation: presentation,
      ),
    ));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  }

  testWidgets('Direct without a game runner window channel stays on Flutter with the reason', (tester) async {
    LuminaGameWindow.backend = null;
    await mount(tester, LuminaPresentationMode.direct);
    final decision = LuminaGamePresentation.decision.value;
    expect(LuminaGamePresentation.requested.value.mode, LuminaPresentationMode.direct);
    expect(decision.mode, LuminaPresentationMode.flutter);
    expect(decision.reason, contains('no game window channel'));
    await unmount(tester);
  });

  testWidgets('a runner that refuses the presentation window: Flutter with its reason', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'createSurface') {
        throw PlatformException(code: 'unsupported', message: 'direct presentation is not available on this desktop');
      }
      return null;
    });
    LuminaGameWindow.backend = LuminaWindowModeChannel();
    await mount(tester, LuminaPresentationMode.direct);
    final decision = LuminaGamePresentation.decision.value;
    expect(decision.mode, LuminaPresentationMode.flutter);
    // The noop / non-Vulkan engine of a test refuses before the window is
    // asked for; a Vulkan engine asks the runner, which refuses.
    expect(decision.reason, anyOf(contains('Vulkan'), contains('not available on this desktop')));
    await unmount(tester);
  });

  testWidgets('Flutter presentation never asks the runner for a window', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
    LuminaGameWindow.backend = LuminaWindowModeChannel();
    await mount(tester, LuminaPresentationMode.flutter);
    expect(calls, isNot(contains('createSurface')));
    expect(LuminaGamePresentation.decision.value.mode, LuminaPresentationMode.flutter);
    await unmount(tester);
  });
}
