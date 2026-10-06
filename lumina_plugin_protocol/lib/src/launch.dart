/// How the host starts a plugin process and how the process reads it back.
///
/// The host binds a loopback `ServerSocket` on port 0 and starts the
/// project editor's own executable (or, in tests, any program) with
/// [toArgs]; the process connects to `127.0.0.1:<port>`, sends
/// `host.hello` with [token] and from then on speaks the protocol. A
/// process started with these flags never opens an editor window.
class PluginProcessLaunch {
  const PluginProcessLaunch({
    required this.pluginName,
    required this.port,
    required this.token,
    this.projectDir,
  });

  /// The flag that switches the editor executable into plugin-process mode.
  static const String flag = '--lumina-plugin-process';
  static const String portFlag = '--lumina-plugin-port';
  static const String tokenFlag = '--lumina-plugin-token';
  static const String projectFlag = '--lumina-plugin-project';

  final String pluginName;
  final int port;

  /// A random secret: a hello with another token is refused, so nothing
  /// else on the machine can pose as the plugin.
  final String token;

  /// The open project's directory, when one is open at launch.
  final String? projectDir;

  List<String> toArgs() => [
        flag,
        pluginName,
        portFlag,
        '$port',
        tokenFlag,
        token,
        if (projectDir != null) ...[projectFlag, projectDir!],
      ];

  /// The launch in [args], or null when [args] has no [flag] (a normal
  /// editor start). Throws [FormatException] when the flag is there but the
  /// rest is incomplete.
  static PluginProcessLaunch? parse(List<String> args) {
    final i = args.indexOf(flag);
    if (i < 0) return null;
    String? valueOf(String name) {
      final j = args.indexOf(name);
      return j >= 0 && j + 1 < args.length ? args[j + 1] : null;
    }

    final name = i + 1 < args.length ? args[i + 1] : null;
    final port = int.tryParse(valueOf(portFlag) ?? '');
    final token = valueOf(tokenFlag);
    if (name == null || name.startsWith('--') || port == null || token == null || token.isEmpty) {
      throw FormatException('incomplete plugin process arguments: ${args.join(' ')}');
    }
    return PluginProcessLaunch(pluginName: name, port: port, token: token, projectDir: valueOf(projectFlag));
  }
}
