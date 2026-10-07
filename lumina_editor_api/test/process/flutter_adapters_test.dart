import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';

import 'package:lumina_editor_api/testing.dart';

/// A plugin process that only keeps its context, to reach its level.
class _LevelProcess extends LuminaPluginProcess {
  late PluginProcessContext context;

  @override
  String get pluginName => 'adapters';

  @override
  void register(PluginProcessContext context) => this.context = context;
}

void main() {
  test('an ObservableValue seen as a ValueListenable forwards listeners and reads the value', () {
    final pure = ObservableValue(1);
    final listenable = pure.asValueListenable();
    expect(identical(listenable, pure.asValueListenable()), isTrue, reason: 'one view per source');
    var calls = 0;
    void listener() => calls++;
    listenable.addListener(listener);
    pure.value = 2;
    expect(listenable.value, 2);
    listenable.removeListener(listener);
    pure.value = 3;
    expect(calls, 1);
    expect(identical(listenable.asObservable(), pure), isTrue, reason: 'the round trip gives the source back');
  });

  test('a ValueNotifier seen as an Observable forwards listeners and reads the value', () {
    final notifier = ValueNotifier('a');
    final pure = notifier.asObservable();
    final seen = <String>[];
    pure.addListener(() => seen.add(pure.value));
    notifier.value = 'b';
    expect(seen, ['b']);
    expect(identical(pure.asValueListenable(), notifier), isTrue);
  });

  test('ChangeSignal and Listenable convert both ways', () {
    final signal = ChangeEmitter();
    final listenable = signal.asListenable();
    var calls = 0;
    listenable.addListener(() => calls++);
    signal.notifyListeners();
    expect(calls, 1);
    expect(identical(listenable.asChangeSignal(), signal), isTrue);

    final notifier = ChangeNotifier();
    final pure = notifier.asChangeSignal();
    var pureCalls = 0;
    pure.addListener(() => pureCalls++);
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    notifier.notifyListeners();
    expect(pureCalls, 1);
  });

  test('a detached channel is disabled and refuses calls', () async {
    final channel = PluginProcessChannel.detached('lonely');
    expect(channel.state.value.status, PluginProcessStatus.disabled);
    await expectLater(
      channel.call('anything'),
      throwsA(isA<PluginRemoteError>().having((e) => e.code, 'code', PluginErrorCodes.unavailable)),
    );
  });

  test("the loopback host's channel is its link with a Flutter state, and the process level has a Flutter view",
      () async {
    final host = await LoopbackHost.start();
    addTearDown(host.close);
    final process = _LevelProcess();
    final exit = runPluginProcessMain(host.launch('adapters'), process);
    await host.contributions;

    final channel = host.channel;
    expect(identical(channel, host.channel), isTrue);
    expect(channel.state, isA<ValueListenable<PluginProcessState>>());
    expect(channel.state.value.status, PluginProcessStatus.running);
    expect(identical(channel.asLink(), host.link), isTrue);

    // The pure level and its Flutter view fire together on core.levelChanged.
    final PluginLevelAccess level = process.context.level;
    final EditorLevelAccess editorLevel = level.asEditorLevelAccess();
    expect(identical(editorLevel.asPluginLevelAccess(), level), isTrue);
    var flutterFired = 0;
    editorLevel.changes.addListener(() => flutterFired++);
    final ids = await editorLevel.addActors([const EditorActorSpec(name: 'Viewed', type: 'Empty', location: [0, 0, 0])]);
    expect(host.level.actors.single.id, ids.single);
    expect(editorLevel.actors.single.name, 'Viewed');
    expect(flutterFired, greaterThan(0));

    final before = flutterFired;
    host.connection.notify(PluginMethods.levelChanged, const {});
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(flutterFired, greaterThan(before));

    await host.call(PluginMethods.shutdown);
    expect(await exit, PluginProcessExitCodes.ok);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(channel.state.value.status, PluginProcessStatus.crashed);
  });
}
