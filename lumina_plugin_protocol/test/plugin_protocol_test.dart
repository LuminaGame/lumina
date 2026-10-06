import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:lumina_plugin_protocol/lumina_plugin_protocol.dart';
import 'package:test/test.dart';

/// Two connections over a real loopback socket pair.
Future<(PluginConnection, PluginConnection, ServerSocket)> _pair({Duration timeout = const Duration(seconds: 2)}) async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final accepted = server.first;
  final client = await Socket.connect(InternetAddress.loopbackIPv4, server.port);
  final host = await accepted;
  return (
    PluginConnection(input: host, output: host, defaultTimeout: timeout),
    PluginConnection(input: client, output: client, defaultTimeout: timeout),
    server,
  );
}

void main() {
  group('PluginFrameCodec', () {
    test('frames survive any chunking, including one byte at a time', () async {
      final messages = [
        {'t': 'ntf', 'm': 'a', 'a': {'x': 1}},
        {'t': 'ntf', 'm': 'b', 'a': {'text': 'çğış — ünicode', 'list': [1, 2, 3]}},
      ];
      final bytes = [for (final m in messages) ...PluginFrameCodec.encode(m)];
      final byteByByte = Stream<List<int>>.fromIterable([for (final b in bytes) [b]]);
      expect(await PluginFrameCodec.decode(byteByByte).toList(), messages);
      final oneChunk = Stream<List<int>>.value(bytes);
      expect(await PluginFrameCodec.decode(oneChunk).toList(), messages);
    });

    test('a frame that is not a JSON object, an oversized length or a cut frame is an error', () async {
      final notObject = BytesBuilder()
        ..add([0, 0, 0, 3])
        ..add('[1]'.codeUnits);
      await expectLater(PluginFrameCodec.decode(Stream.value(notObject.toBytes())).toList(), throwsFormatException);
      final huge = Uint8List(4)..buffer.asByteData().setUint32(0, PluginFrameCodec.maxPayload + 1);
      await expectLater(PluginFrameCodec.decode(Stream.value(huge)).toList(), throwsFormatException);
      final cut = PluginFrameCodec.encode({'t': 'ntf', 'm': 'x'}).sublist(0, 7);
      await expectLater(PluginFrameCodec.decode(Stream.value(cut)).toList(), throwsFormatException);
    });
  });

  group('PluginMessage', () {
    test('every message kind encodes and decodes', () {
      final req = PluginMessage.fromJson(const PluginRequest(id: 7, method: 'core.call', args: {'k': 'v'}).toJson());
      expect(req, isA<PluginRequest>().having((r) => r.id, 'id', 7).having((r) => r.args, 'args', {'k': 'v'}));
      final ok = PluginMessage.fromJson(const PluginResponse.ok(7, [1, 2]).toJson()) as PluginResponse;
      expect(ok.ok, isTrue);
      expect(ok.result, [1, 2]);
      final err = PluginMessage.fromJson(
        const PluginResponse.error(8, PluginRemoteError(code: 'x', message: 'y', stack: 's')).toJson(),
      ) as PluginResponse;
      expect(err.error!.code, 'x');
      expect(err.error!.stack, 's');
      final ntf = PluginMessage.fromJson(const PluginNotification(method: 'host.log', args: {'m': 1}).toJson());
      expect(ntf, isA<PluginNotification>());
      expect(() => PluginMessage.fromJson({'t': 'zzz'}), throwsFormatException);
    });
  });

  group('PluginConnection', () {
    test('requests are answered both ways; errors and unknown methods come back as codes', () async {
      final (host, child, server) = await _pair();
      addTearDown(server.close);
      addTearDown(host.close);
      addTearDown(child.close);
      host.onRequest('host.echo', (a) => {'echo': a['v']});
      child.onRequest('core.add', (a) async => (a['x'] as int) + (a['y'] as int));
      child.onRequest('core.fail', (a) => throw StateError('boom'));
      child.onRequest('core.refuse', (a) => throw const PluginRemoteError(code: PluginErrorCodes.badArguments, message: 'no'));

      expect(await child.request('host.echo', {'v': 'hi'}), {'echo': 'hi'});
      expect(await host.request('core.add', {'x': 2, 'y': 3}), 5);
      await expectLater(host.request('core.fail'),
          throwsA(isA<PluginRemoteError>().having((e) => e.code, 'code', PluginErrorCodes.handlerFailed)));
      await expectLater(host.request('core.refuse'),
          throwsA(isA<PluginRemoteError>().having((e) => e.code, 'code', PluginErrorCodes.badArguments)));
      await expectLater(host.request('core.nothing'),
          throwsA(isA<PluginRemoteError>().having((e) => e.code, 'code', PluginErrorCodes.unknownMethod)));
    });

    test('notifications arrive in order', () async {
      final (host, child, server) = await _pair();
      addTearDown(server.close);
      addTearDown(host.close);
      addTearDown(child.close);
      final got = <int>[];
      final all = Completer<void>();
      host.onNotification(PluginMethods.progress, (a) {
        got.add(a['done'] as int);
        if (got.length == 50) all.complete();
      });
      for (var i = 0; i < 50; i++) {
        child.notify(PluginMethods.progress, {'done': i});
      }
      await all.future.timeout(const Duration(seconds: 2));
      expect(got, List.generate(50, (i) => i));
    });

    test('a call times out, and its late answer is dropped', () async {
      final (host, child, server) = await _pair();
      addTearDown(server.close);
      addTearDown(host.close);
      addTearDown(child.close);
      final release = Completer<void>();
      child.onRequest('core.slow', (a) async {
        await release.future;
        return 'late';
      });
      await expectLater(host.request('core.slow', const {}, const Duration(milliseconds: 100)),
          throwsA(isA<PluginRemoteError>().having((e) => e.code, 'code', PluginErrorCodes.timeout)));
      expect(host.pendingCount, 0);
      release.complete();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // The late answer did not break anything: the next call works.
      child.onRequest('core.fast', (a) => 'ok');
      expect(await host.request('core.fast'), 'ok');
    });

    test('closing one side fails the other side\'s pending calls and completes done', () async {
      final (host, child, server) = await _pair(timeout: const Duration(seconds: 30));
      addTearDown(server.close);
      child.onRequest('core.never', (a) => Completer<Object?>().future);
      final call = host.request('core.never');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await child.close();
      await expectLater(call, throwsA(isA<PluginRemoteError>().having((e) => e.code, 'code', PluginErrorCodes.closed)));
      await host.done.timeout(const Duration(seconds: 2));
      expect(host.isClosed, isTrue);
      await expectLater(host.request('x'), throwsA(isA<PluginRemoteError>()));
    });
  });

  group('PluginProcessLaunch', () {
    test('round-trips through the command line and refuses incomplete flags', () {
      const launch = PluginProcessLaunch(pluginName: 'kimodo', port: 5123, token: 'abc', projectDir: r'C:\p\My Game');
      final parsed = PluginProcessLaunch.parse(['--other', ...launch.toArgs()])!;
      expect(parsed.pluginName, 'kimodo');
      expect(parsed.port, 5123);
      expect(parsed.token, 'abc');
      expect(parsed.projectDir, r'C:\p\My Game');
      expect(PluginProcessLaunch.parse(['--project', 'x']), isNull);
      expect(() => PluginProcessLaunch.parse([PluginProcessLaunch.flag, 'p']), throwsFormatException);
    });
  });

  group('contributions and views', () {
    test('contributions round-trip through JSON', () {
      const icon = PluginIconSpec(0xe123, fontFamily: 'lucide', fontPackage: 'shadcn_flutter');
      const c = PluginContributions(
        menus: [PluginMenuSpec(id: 'm', title: 'Kimodo')],
        menuItems: [
          PluginMenuItemSpec(path: 'Kimodo/Generate', command: PluginCommandSpec(id: 'gen', label: 'Generate', icon: icon), checked: false),
        ],
        slotButtons: [
          PluginSlotButtonSpec(
            id: 's',
            slot: 'statusBarRight',
            state: PluginButtonStateSpec(icon: icon, tooltip: 't', badge: '3', busy: true),
            command: PluginCommandSpec(id: 'toggle', label: 'Toggle'),
            menu: [PluginCommandSpec(id: 'a', label: 'A')],
          ),
        ],
        mcpTools: [PluginMcpToolSpec(name: 'kimodo_generate', title: 'Generate', description: 'd', inputSchema: {'type': 'object'}, risk: 'write')],
        importers: [PluginImporterSpec(id: 'uasset', extensions: ['uasset'], description: 'Unreal')],
        consoleCommands: [PluginConsoleCommandSpec(name: 'kimodo.reset', help: 'h')],
        panels: [
          PluginViewPanelSpec(id: 'p', title: 'Status', icon: icon, dock: 'right', view: PluginViewSpec(id: 'v', children: [])),
        ],
      );
      final back = PluginContributions.fromJson(c.toJson());
      expect(back.toJson(), c.toJson());
      expect(back.menuItems.single.command.icon, icon);
      expect(back.slotButtons.single.state.busy, isTrue);
    });

    test('a patch updates one control and leaves the rest', () {
      final spec = PluginViewSpec(id: 'gen', children: [
        PluginControl.section('s', 'Generate', [
          PluginControl.textField('prompt', label: 'Prompt', value: 'walk'),
          PluginControl.progress('p', value: 0.1, text: 'Step 1'),
          PluginControl.button('go', 'Generate'),
        ]),
      ]);
      final patched = spec.apply(const PluginViewPatch([
        PluginViewPatchOp.set('p', {'value': 0.5, 'text': 'Step 2'}),
        PluginViewPatchOp.set('missing', {'value': 1}),
      ]));
      expect(patched.find('p')!['value'], 0.5);
      expect(patched.find('p')!['text'], 'Step 2');
      expect(patched.find('prompt')!['value'], 'walk');
      final replaced = patched.apply(PluginViewPatch([PluginViewPatchOp.replace('go', PluginControl.text('go', 'Done'))]));
      expect(replaced.find('go')!.kind, PluginControlKind.text);
      expect(PluginViewSpec.fromJson(replaced.toJson()).toJson(), replaced.toJson());
      const event = PluginViewEvent(viewId: 'gen', controlId: 'go', kind: 'pressed');
      expect(PluginViewEvent.fromJson(event.toJson()).toJson(), event.toJson());
    });
  });
}
