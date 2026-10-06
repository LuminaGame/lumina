import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_entry.dart';

import 'plugin_process_harness.dart';

/// The editor executable's plugin-process mode, as `runLuminaEditor` runs
/// it before anything else (no window, no crash session, no registry).
void main() {
  const launch = PluginProcessLaunch(pluginName: kFakePluginName, port: 4242, token: 'abc');

  test('a normal editor start is not plugin-process mode', () async {
    expect(await runPluginProcessFromArgs(['--project', '/tmp/x'], {kFakePluginName: FakeProcessPart.new}), isNull);
  });

  test('the named process part runs with the parsed launch and its exit code is returned', () async {
    PluginProcessLaunch? seen;
    LuminaPluginProcess? ran;
    final code = await runPluginProcessFromArgs(
      launch.toArgs(),
      {kFakePluginName: FakeProcessPart.new},
      run: (l, p) async {
        seen = l;
        ran = p;
        return 7;
      },
    );
    expect(code, 7);
    expect(seen!.port, 4242);
    expect(seen!.token, 'abc');
    expect(ran, isA<FakeProcessPart>());
  });

  test('an unknown plugin name exits 64 with a message on stderr', () async {
    final err = StringBuffer();
    final code = await runPluginProcessFromArgs(
      const PluginProcessLaunch(pluginName: 'nope', port: 1, token: 't').toArgs(),
      {kFakePluginName: FakeProcessPart.new},
      stderrSink: err,
    );
    expect(code, kPluginProcessUsageExit);
    expect(err.toString(), contains('no process part for plugin "nope"'));
    expect(err.toString(), contains(kFakePluginName));
  });

  test('incomplete launch arguments exit 64', () async {
    final err = StringBuffer();
    final code = await runPluginProcessFromArgs([PluginProcessLaunch.flag, kFakePluginName], const {}, stderrSink: err);
    expect(code, kPluginProcessUsageExit);
    expect(err.toString(), contains('incomplete plugin process arguments'));
  });
}
