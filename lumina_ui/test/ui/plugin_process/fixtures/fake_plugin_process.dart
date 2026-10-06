// The fake plugin as a child process:
// `dart fake_plugin_process.dart <control file> --lumina-plugin-process ...`.
import 'package:lumina_plugin_protocol/lumina_plugin_protocol.dart';

import 'fake_plugin_client.dart';

Future<void> main(List<String> args) async {
  final launch = PluginProcessLaunch.parse(args)!;
  await runFakePlugin(launch, controlPath: args.first);
}
