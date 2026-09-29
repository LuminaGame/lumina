import '../services/mcp_jobs.dart';
import '../services/mcp_protocol.dart';
import '../services/mcp_tool.dart';

/// `wait_job`'s longest wait: no call outlives a client's HTTP timeout.
const int kMcpWaitJobMaxMs = 25000;

/// The job tools (group `core`):
/// list, read (state, progress, result, log pages), long-poll and cancel the
/// long-running operations other tools start.
void registerJobTools(McpToolRegistry registry, McpJobRegistry jobs) {
  const core = {McpToolGroups.core};

  McpJob jobOf(McpArgs args) {
    final id = args.string('id');
    final job = jobs.byId(id);
    if (job == null) {
      final known = jobs.jobs.map((j) => j.id).toList();
      throw JsonRpcException(JsonRpcErrorCode.invalidParams,
          'No job "$id". ${known.isEmpty ? 'No job was started in this editor session.' : 'Jobs: ${known.join(', ')} (list_jobs).'}');
    }
    return job;
  }

  final states = [for (final s in McpJobState.values) s.name];

  registry.registerAll([
    McpTool(
      name: 'list_jobs',
      risk: McpToolRisk.readOnly,
      groups: core,
      title: 'List jobs',
      description: 'The long-running operations of this editor session (start_build, play_standalone, set_widget_library, …), '
          'newest last: {id, kind, title, state (queued|running|succeeded|failed|cancelled), progress 0..1 or null, stage, '
          'started, finished, elapsed_ms, log_lines}. The last 50 are kept.',
      inputSchema: McpSchema.object({
        'state': McpSchema.string('Only jobs in this state.', enumValues: states),
      }),
      handler: (args) {
        final wanted = args.optionalString('state');
        return McpToolResult.json({
          'jobs': [
            for (final j in jobs.jobs)
              if (wanted == null || j.state.name == wanted) j.summary(),
          ],
        });
      },
    ),
    McpTool(
      name: 'get_job',
      risk: McpToolRisk.readOnly,
      groups: core,
      title: 'Get job',
      description: 'One job: state, progress, stage, result (when finished), error, and its log as '
          '[{index, level, source, message}] plus next_log_index. Pass since_log_index = the previous next_log_index to '
          'read only new lines; tail (default 100, max 2000) keeps the last lines of that range.',
      inputSchema: McpSchema.object({
        'id': McpSchema.string('The job id ("job_3").'),
        'since_log_index': McpSchema.integer('First log index to return (default 0).'),
        'tail': McpSchema.integer('At most this many (the newest) lines; default 100, max 2000.'),
      }, required: ['id']),
      handler: (args) {
        final job = jobOf(args);
        final tail = args.integer('tail', fallback: 100);
        if (tail < 0 || tail > 2000) {
          throw const JsonRpcException(JsonRpcErrorCode.invalidParams, 'tail must be between 0 and 2000');
        }
        final since = args.integer('since_log_index', fallback: 0);
        if (since < 0) throw const JsonRpcException(JsonRpcErrorCode.invalidParams, 'since_log_index must be ≥ 0');
        return McpToolResult.json(job.detail(sinceLogIndex: since, tail: tail));
      },
    ),
    McpTool(
      name: 'wait_job',
      risk: McpToolRisk.readOnly,
      groups: core,
      title: 'Wait for a job',
      description: 'Long-poll: returns as soon as the job leaves running (its state, progress, result, error), or after '
          'timeout_ms (default 20000, max $kMcpWaitJobMaxMs) with timed_out: true. Call it again to keep waiting; use it '
          'instead of polling get_job in a loop.',
      inputSchema: McpSchema.object({
        'id': McpSchema.string('The job id.'),
        'timeout_ms': McpSchema.integer('How long to wait at most; default 20000, max $kMcpWaitJobMaxMs.'),
      }, required: ['id']),
      handler: (args) async {
        final job = jobOf(args);
        final timeout = args.integer('timeout_ms', fallback: 20000);
        if (timeout < 0 || timeout > kMcpWaitJobMaxMs) {
          throw const JsonRpcException(JsonRpcErrorCode.invalidParams,
              'timeout_ms must be between 0 and $kMcpWaitJobMaxMs (25 s, so no call outlives an HTTP client timeout); '
              'call wait_job again to keep waiting.');
        }
        final done = await jobs.wait(job, Duration(milliseconds: timeout));
        final detail = job.detail(tail: 20);
        return McpToolResult.json({...detail, 'timed_out': !done});
      },
    ),
    McpTool(
      name: 'cancel_job',
      risk: McpToolRisk.editorState,
      groups: core,
      idempotent: true,
      title: 'Cancel job',
      description: 'Cancels a running job: a build kills its flutter build, Play Standalone stops the game or its build. '
          'The job is cancelled at once; the call waits up to 5 s for the operation to wind down and returns the job.',
      inputSchema: McpSchema.object({'id': McpSchema.string('The job id.')}, required: ['id']),
      handler: (args) async {
        final job = jobOf(args);
        final was = job.state;
        if (!jobs.cancel(job)) {
          return McpToolResult.error('${job.id} already ${was.name}; nothing to cancel.');
        }
        try {
          await job.runDone.timeout(const Duration(seconds: 5));
        } catch (_) {
          // Still winding down; the job is cancelled all the same.
        }
        return McpToolResult.json(job.detail(tail: 20));
      },
    ),
  ]);
}
