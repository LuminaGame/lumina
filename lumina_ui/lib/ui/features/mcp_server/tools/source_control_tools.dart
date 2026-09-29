import '../../main_editor/view_models/editor_view_model.dart';
import '../../source_control/services/git_service.dart';
import '../../source_control/view_models/source_control_view_model.dart';
import '../services/mcp_protocol.dart';
import '../services/mcp_tool.dart';

/// Source Control as MCP tools (group `scm`), over the
/// editor's own [SourceControlViewModel] (the status bar, the Content
/// Browser's badges and the commit dialog): status, init, commit, file
/// history, revert and the repo-local identity. Push, pull and branches are
/// not in the editor's UI, so they are not exposed.
void registerSourceControlTools(McpToolRegistry registry, EditorViewModel vm) {
  const scm = {McpToolGroups.scm};
  SourceControlViewModel sc() => vm.sourceControl;

  Future<McpToolResult?> ensureGit() async {
    await sc().refresh();
    await sc().whenIdle;
    if (!sc().isAvailable) return McpToolResult.error(SourceControlViewModel.installHint);
    return null;
  }

  McpToolResult? ensureRepo() => sc().isRepo
      ? null
      : McpToolResult.error('The project has no git repository yet; call source_control_init first.');

  Future<String?> lastCommit() async {
    if (!sc().isRepo) return null;
    try {
      return await sc().service.headHash();
    } catch (_) {
      return null;
    }
  }

  String identityHint(String? error) => 'git has no author identity for this repository ($error). '
      'Call source_control_set_identity {name, email} (repo-local, as the identity form does), then commit again.';

  Future<Map<String, Object?>> status({bool summaries = false}) async {
    final s = sc();
    final sums = summaries && s.isRepo ? await s.loadSummaries() : const <String, GitDiffSummary>{};
    final changes = [...s.changes]..sort((a, b) => a.path.compareTo(b.path));
    return {
      'available': s.isAvailable,
      'is_repo': s.isRepo,
      'identity_required': s.identityRequired,
      'last_error': s.lastError,
      'last_commit': await lastCommit(),
      'changes': [
        for (final c in changes)
          {
            'path': c.path,
            'state': c.state.name,
            'orig_path': c.origPath,
            if (sums[c.path] != null) ...{
              'added': sums[c.path]!.added,
              'removed': sums[c.path]!.removed,
              'binary': sums[c.path]!.isBinary,
            },
          },
      ],
    };
  }

  registry.registerAll([
    McpTool(
      name: 'source_control_status',
      risk: McpToolRisk.readOnly,
      groups: scm,
      title: 'Source control status',
      description: 'git status of the project, as the Source Control status bar and the Content Browser badges show it: '
          '{available, is_repo, identity_required, last_error, last_commit, changes[{path, state (modified|added|'
          'deleted|renamed|untracked|conflicted), orig_path}]}. summaries: true adds each change\'s added / removed '
          'line counts, as the commit dialog shows.',
      inputSchema: McpSchema.object({
        'summaries': McpSchema.boolean('Add the diff line counts. Default false.'),
      }),
      handler: (args) async {
        await sc().refresh();
        await sc().whenIdle;
        return McpToolResult.json(await status(summaries: args.boolean('summaries')));
      },
    ),
    McpTool(
      name: 'source_control_init',
      risk: McpToolRisk.mutating,
      groups: scm,
      idempotent: true,
      title: 'Initialize git repository',
      description: 'Source Control → Initialize Git Repository: git init, the Lumina .gitignore and an initial commit. '
          'When git has no author identity the repository is created and staged, identity_required is true: call '
          'source_control_set_identity to finish the initial commit.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) async {
        final missing = await ensureGit();
        if (missing != null) return missing;
        if (sc().isRepo) return McpToolResult.json({...await status(), 'initialized': false, 'note': 'Already a git repository.'});
        final ok = await sc().initRepository();
        await sc().whenIdle;
        if (!ok && sc().identityRequired) return McpToolResult.error(identityHint(sc().lastError));
        if (!ok) return McpToolResult.error('git init failed: ${sc().lastError}');
        return McpToolResult.json({...await status(), 'initialized': true});
      },
    ),
    McpTool(
      name: 'source_control_commit',
      risk: McpToolRisk.mutating,
      groups: scm,
      idempotent: false,
      title: 'Commit',
      description: 'Source Control → Commit: commits exactly `paths` (project-relative, from source_control_status) or, '
          'with all: true, every change, with `message`. Returns {hash}. A commit is ordinary history, not undone by '
          'undo.',
      inputSchema: McpSchema.object({
        'paths': McpSchema.stringArray('The changed files to commit.'),
        'all': McpSchema.boolean('Commit every change instead of paths.'),
        'message': McpSchema.string('The commit message.'),
      }, required: ['message']),
      handler: (args) async {
        final message = args.string('message').trim();
        if (message.isEmpty) {
          throw const JsonRpcException(JsonRpcErrorCode.invalidParams, 'The commit "message" must not be empty.');
        }
        final all = args.boolean('all');
        if (!all && !args.has('paths')) {
          throw const JsonRpcException(JsonRpcErrorCode.invalidParams, 'Pass "paths" (the files to commit) or "all": true.');
        }
        final missing = await ensureGit();
        if (missing != null) return missing;
        final noRepo = ensureRepo();
        if (noRepo != null) return noRepo;
        final changed = {for (final c in sc().changes) c.path};
        final paths = all ? changed.toList() : args.stringList('paths');
        if (paths.isEmpty) return McpToolResult.error('Nothing to commit: the working tree is clean.');
        final unknown = paths.where((p) => !changed.contains(p)).toList();
        if (unknown.isNotEmpty) {
          return McpToolResult.error('Not among the changes: ${unknown.join(', ')}. source_control_status lists them.');
        }
        final hash = await sc().commit(paths: paths, message: message);
        await sc().whenIdle;
        if (hash == null) {
          if (sc().identityRequired) return McpToolResult.error(identityHint(sc().lastError));
          return McpToolResult.error('Commit failed: ${sc().lastError}');
        }
        return McpToolResult.json({'hash': hash, 'committed': paths.length, 'remaining_changes': sc().changes.length});
      },
    ),
    McpTool(
      name: 'source_control_history',
      risk: McpToolRisk.readOnly,
      groups: scm,
      title: 'File history',
      description: 'Source Control → History of a file (default: the open level): [{hash, abbrev, author, date, subject}], '
          'newest first.',
      inputSchema: McpSchema.object({
        'path': McpSchema.string('The project-relative file, e.g. "contents/levels/L_Main.lmas".'),
        'limit': McpSchema.integer('At most this many commits; default 50.'),
      }),
      handler: (args) async {
        final missing = await ensureGit();
        if (missing != null) return missing;
        final noRepo = ensureRepo();
        if (noRepo != null) return noRepo;
        final path = args.optionalString('path') ?? vm.project.activeLevel;
        final limit = args.integer('limit', fallback: 50);
        if (limit < 1) throw const JsonRpcException(JsonRpcErrorCode.invalidParams, 'limit must be at least 1');
        final entries = await sc().history(path, limit: limit);
        return McpToolResult.json({
          'path': path,
          'entries': [
            for (final e in entries)
              {
                'hash': e.hash,
                'abbrev': e.hash.length > 7 ? e.hash.substring(0, 7) : e.hash,
                'author': e.author,
                'date': e.date.toIso8601String(),
                'subject': e.subject,
              },
          ],
        });
      },
    ),
    McpTool(
      name: 'source_control_revert',
      risk: McpToolRisk.destructive,
      groups: scm,
      title: 'Revert file',
      description: 'Source Control → Revert: discards the working-tree changes of one file (git restore); the editor '
          'reloads it. This CANNOT be undone — the discarded edits are gone. The path must be among the changes '
          '(source_control_status). An untracked file is deleted only with delete_untracked: true.',
      inputSchema: McpSchema.object({
        'path': McpSchema.string('The changed file, project-relative.'),
        'delete_untracked': McpSchema.boolean('Delete an untracked (new) file. Default false.'),
      }, required: ['path']),
      handler: (args) async {
        final missing = await ensureGit();
        if (missing != null) return missing;
        final noRepo = ensureRepo();
        if (noRepo != null) return noRepo;
        final path = args.string('path');
        if (sc().statusFor(path) == null) {
          return McpToolResult.error('$path is not among the changes; source_control_status lists what can be reverted.');
        }
        final ok = await sc().revert(path, deleteUntracked: args.boolean('delete_untracked'));
        await sc().whenIdle;
        if (!ok) return McpToolResult.error('Revert of $path failed: ${sc().lastError}');
        return McpToolResult.json({'path': path, 'reverted': true, 'remaining_changes': sc().changes.length});
      },
    ),
    McpTool(
      name: 'source_control_set_identity',
      risk: McpToolRisk.mutating,
      groups: scm,
      idempotent: true,
      title: 'Set git identity',
      description: 'The identity form: writes user.name / user.email into this repository\'s own git config (never the '
          'global one) and finishes an initial commit an identity error interrupted.',
      inputSchema: McpSchema.object({
        'name': McpSchema.string('The author name.'),
        'email': McpSchema.string('The author e-mail.'),
      }, required: ['name', 'email']),
      handler: (args) async {
        final name = args.string('name').trim();
        final email = args.string('email').trim();
        if (name.isEmpty || !email.contains('@')) {
          throw const JsonRpcException(JsonRpcErrorCode.invalidParams, 'Pass a non-empty "name" and an "email" with an @.');
        }
        final missing = await ensureGit();
        if (missing != null) return missing;
        final noRepo = ensureRepo();
        if (noRepo != null) return noRepo;
        final ok = await sc().configureIdentity(name: name, email: email);
        await sc().whenIdle;
        if (!ok) return McpToolResult.error('Could not set the identity: ${sc().lastError}');
        return McpToolResult.json({'name': name, 'email': email, 'identity_required': sc().identityRequired});
      },
    ),
  ]);
}
