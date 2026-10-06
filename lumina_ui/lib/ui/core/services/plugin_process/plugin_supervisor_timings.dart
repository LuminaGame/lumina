/// The clock of a [PluginProcessSupervisor]: health checks, restarts and
/// the bounds of each call. The defaults are the editor's; tests shorten
/// them.
class PluginSupervisorTimings {
  const PluginSupervisorTimings({
    this.pingInterval = const Duration(seconds: 2),
    this.missedPingsForHung = 3,
    this.restartBackoff = const [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4)],
    this.startTimeout = const Duration(seconds: 60),
    this.callTimeout = const Duration(seconds: 30),
    this.commandTimeout = const Duration(seconds: 30),
    this.mcpToolTimeout = const Duration(minutes: 30),
    this.importTimeout = const Duration(minutes: 30),
    this.projectClosingTimeout = const Duration(seconds: 5),
    this.shutdownTimeout = const Duration(seconds: 3),
    this.stableAfter = const Duration(minutes: 1),
    this.levelChangeDebounce = const Duration(milliseconds: 200),
  });

  /// A `core.ping` this often; each waits at most this long for its answer.
  final Duration pingInterval;

  /// Consecutive unanswered pings after which the process is hung: killed
  /// and restarted.
  final int missedPingsForHung;

  /// The wait before each automatic restart; its length is the number of
  /// automatic restarts before the plugin is stopped.
  final List<Duration> restartBackoff;

  /// From the start to `host.register`; a process that takes longer is
  /// killed and counts as hung.
  final Duration startTimeout;

  /// The default bound of a shell's `PluginProcessChannel.call`.
  final Duration callTimeout;

  /// The bound of a menu / slot command and a console command.
  final Duration commandTimeout;

  /// The bound of an MCP tool call routed to the process: tools may run a
  /// long job (a whole generation). A hang is caught by the health pings,
  /// and a process that dies fails the call at once, not by this bound.
  final Duration mcpToolTimeout;

  /// The bound of a plugin importer (large packages take long; as with
  /// tools, a death or hang ends the call earlier).
  final Duration importTimeout;

  /// The bound of `core.projectClosing`.
  final Duration projectClosingTimeout;

  /// How long a process gets to exit after `core.shutdown` before it is
  /// killed.
  final Duration shutdownTimeout;

  /// A process that has run this long resets the automatic restart count.
  final Duration stableAfter;

  /// Level changes are sent at most this often (`core.levelChanged`).
  final Duration levelChangeDebounce;

  int get maxRestarts => restartBackoff.length;
}
