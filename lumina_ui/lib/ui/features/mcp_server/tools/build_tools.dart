import 'dart:async';

import 'package:lumina/lumina.dart' show kPackagingPlatforms;

import '../../main_editor/view_models/editor_view_model.dart';
import '../../sub_editors/services/build_pipeline_service.dart';
import '../../sub_editors/view_models/build_manager_view_model.dart';
import '../services/mcp_jobs.dart';
import '../services/mcp_protocol.dart';
import '../services/mcp_tool.dart';

/// The key of the one Build Manager pipeline an editor runs at a time.
const String kMcpBuildPipeline = 'build_pipeline';

/// The steps a run of [kind] covers, from the Build Manager's ticks.
List<BuildStepKind> _plannedSteps(BuildManagerViewModel bm, {required bool cook}) => [
      for (final k in BuildStepKind.values)
        if (k == BuildStepKind.cookAndPackage ? cook : bm.isStepEnabled(k)) k,
    ];

/// The Build menu and the Build Manager as MCP tools (group
/// `build`): the Build Manager's settings, and Build All / Cook & Package
/// started as jobs over the editor's one [BuildManagerViewModel] — the
/// pipeline the menu and the tab drive, so a build the user started is
/// visible here too. Generate Dart Code is `run_codegen` (a project file
/// tool, listed in this group as well); Build Navigation is the level
/// tools' `build_navigation`.
void registerBuildTools(McpToolRegistry registry, EditorViewModel vm, McpJobRegistry jobs) {
  const build = {McpToolGroups.build};
  final configurations = [for (final c in BuildConfiguration.values) c.label];
  final steps = [for (final k in BuildStepKind.values) if (k != BuildStepKind.cookAndPackage) k.name];

  BuildManagerViewModel bm() => vm.buildManagerViewModel;

  Map<String, Object?> stepJson(BuildManagerViewModel b, BuildStepKind k, {Set<BuildStepKind>? planned}) {
    final s = b.stepState(k);
    var status = s.status.name;
    var message = s.message;
    // A planned step the pipeline never started (validation failed and the
    // cook was declined, or an earlier step failed) was skipped.
    if (planned != null && planned.contains(k) && !b.isRunning && s.status == BuildStepStatus.pending) {
      status = BuildStepStatus.skipped.name;
      message ??= 'not started';
    }
    return {
      'step': k.name,
      'label': k.label,
      'enabled': k == BuildStepKind.cookAndPackage ? null : b.isStepEnabled(k),
      'status': status,
      'duration_ms': s.duration?.inMilliseconds,
      'message': message,
      'progress_label': s.progressLabel,
    };
  }

  Map<String, Object?> targetJson(BuildManagerViewModel b, String t) {
    final s = b.targetState(t);
    return {
      'status': s.status.name,
      'package_dir': s.packageDir,
      'size_bytes': s.sizeBytes,
      'duration_ms': s.duration?.inMilliseconds,
      'message': s.message,
      'reasons': s.reasons,
    };
  }

  /// The build as a job's result / get_build_status reports it.
  Map<String, Object?> status(BuildManagerViewModel b, {Set<BuildStepKind>? planned}) => {
        'is_running': b.isRunning,
        'stage': b.currentStage,
        'progress': b.globalProgress,
        'completed_steps': b.completedSteps,
        'total_steps': b.totalSteps,
        'elapsed_ms': b.elapsed.inMilliseconds,
        'steps': [for (final k in BuildStepKind.values) stepJson(b, k, planned: planned)],
        'targets': {for (final t in b.selectedTargets) t: targetJson(b, t)},
        'artifact_path': b.artifactPath,
        'last_pipeline_status': b.lastPipelineStatus?.name,
        'issues': [for (final i in b.issues) {'asset': i.assetPath, 'message': i.message}],
        'log_lines': b.logLines.length,
        'job_id': jobs.runningOn(kMcpBuildPipeline)?.id,
      };

  Future<Map<String, Object?>> settings() async {
    final b = bm();
    if (b.hostTargets == null) await b.init();
    return {
      'steps': [
        for (final k in BuildStepKind.values)
          if (k != BuildStepKind.cookAndPackage) {'step': k.name, 'label': k.label, 'enabled': b.isStepEnabled(k)},
      ],
      'selected_targets': b.selectedTargets,
      'known_targets': kPackagingPlatforms,
      'configuration': b.configuration.label,
      'configuration_flag': b.configuration.flag,
      'configurations': {for (final c in BuildConfiguration.values) c.label: c.flag},
      'extra_flags': b.extraFlags,
      'bundle_web_resources': b.bundleWebResources,
      'buildable_targets': b.buildableTargets,
      'reasons_for': {
        for (final t in kPackagingPlatforms)
          if (b.reasonsFor(t).isNotEmpty) t: b.reasonsFor(t),
      },
      'flutter_version': b.flutterVersion,
      'is_running': b.isRunning,
      'cook_disabled_reason': b.cookDisabledReason,
      'cook_arguments': b.cookArguments,
      'package_dirs': {for (final t in b.selectedTargets) t: b.packageDirFor(t)},
    };
  }

  registry.registerAll([
    McpTool(
      name: 'get_build_settings',
      risk: McpToolRisk.readOnly,
      groups: build,
      title: 'Get build settings',
      description: 'The Build Manager\'s settings: the asset steps with their enabled flags, selected_targets (the '
          'project\'s packaging targets), configuration (Debug → --debug, Development → --profile, Shipping → --release), '
          'extra_flags, bundle_web_resources, buildable_targets and reasons_for each unbuildable one, flutter_version, '
          'is_running, cook_disabled_reason and the literal cook_arguments per target. The first call probes the '
          'toolchain (flutter doctor -v, once per editor).',
      inputSchema: McpSchema.object(const {}),
      handler: (args) async => McpToolResult.json(await settings()),
    ),
    McpTool(
      name: 'set_build_settings',
      risk: McpToolRisk.mutating,
      groups: build,
      idempotent: true,
      title: 'Set build settings',
      description: 'Changes the Build Manager\'s settings as its tab does: steps {"precompileMaterials": false, …}, '
          'targets (the full list to tick; saved to the .lmproject at once, as the tab does), configuration '
          '(Debug | Development | Shipping), extra_flags (appended to flutter build), bundle_web_resources. Refused while '
          'a build runs. Returns get_build_settings.',
      inputSchema: McpSchema.object({
        'steps': {'type': 'object', 'description': 'Step name → enabled. Steps: ${steps.join(', ')}.'},
        'targets': McpSchema.stringArray('The packaging targets to tick: ${kPackagingPlatforms.join(', ')}.'),
        'configuration': McpSchema.string('The build configuration.', enumValues: configurations),
        'extra_flags': McpSchema.string('Extra flutter build flags.'),
        'bundle_web_resources': McpSchema.boolean('Web: bundle CanvasKit & co. (--no-web-resources-cdn).'),
      }),
      handler: (args) async {
        final b = bm();
        if (b.isRunning) {
          return McpToolResult.error('A build is running (get_build_status); change the settings when it has finished.');
        }
        final stepChanges = args.optionalObject('steps') ?? const {};
        for (final e in stepChanges.entries) {
          if (!steps.contains(e.key) || e.value is! bool) {
            throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'steps: "${e.key}" must be one of ${steps.join(', ')} → true/false');
          }
        }
        final targets = args.has('targets') ? args.stringList('targets') : null;
        final unknown = targets?.where((t) => !kPackagingPlatforms.contains(t)).toList() ?? const [];
        if (unknown.isNotEmpty) {
          throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'Unknown target(s) ${unknown.join(', ')}; known: ${kPackagingPlatforms.join(', ')}');
        }
        for (final e in stepChanges.entries) {
          b.setStepEnabled(BuildStepKind.values.byName(e.key), e.value as bool);
        }
        if (targets != null) {
          // What the tab's ticks do (onTargetsChanged → the editor's project
          // + .lmproject), awaited so the manifest holds them on return.
          final ordered = [for (final t in kPackagingPlatforms) if (targets.contains(t)) t];
          await vm.setPackagingTargets(ordered);
        }
        final configuration = args.optionalString('configuration');
        // Always set (also when unchanged) so the open tab repaints the targets.
        b.setConfiguration(configuration == null ? b.configuration : BuildConfiguration.values.firstWhere((c) => c.label == configuration));
        final flags = args.optionalString('extra_flags');
        if (flags != null) b.setExtraFlags(flags);
        if (args.has('bundle_web_resources')) b.setBundleWebResources(args.boolean('bundle_web_resources'));
        return McpToolResult.json(await settings());
      },
    ),
    McpTool(
      name: 'start_build',
      risk: McpToolRisk.external,
      groups: build,
      idempotent: false,
      openWorld: true,
      title: 'Start a build',
      description: 'Build All (the ticked asset steps) or Cook & Package (the steps, then a real flutter build per ticked '
          'target — minutes for a release build), started as a job in the Build Manager tab (it opens). Returns {job_id} '
          'at once: poll get_job (stage, progress, the build log), long-poll wait_job, or cancel_job (kills flutter '
          'build). The result has per-step {status, duration_ms, message}, per-target {status, package_dir, size_bytes, '
          'reasons}, artifact_path and last_pipeline_status. When asset validation fails, Cook & Package is skipped unless '
          'continue_on_validation_failure is true (no dialog is shown). One build at a time per editor.',
      inputSchema: McpSchema.object({
        'kind': McpSchema.string('What to run.', enumValues: const ['build_all', 'cook_and_package']),
        'continue_on_validation_failure': McpSchema.boolean('Cook even when Validate Assets failed (default false).'),
      }, required: ['kind']),
      handler: (args) {
        final kind = args.string('kind');
        final cook = kind == 'cook_and_package';
        final continueAnyway = args.boolean('continue_on_validation_failure');
        final b = bm();
        final running = jobs.runningOn(kMcpBuildPipeline);
        if (running != null) {
          return McpToolResult.error('${running.id} (${running.title}) is still running; wait_job or cancel_job it first.');
        }
        if (b.isRunning) {
          return McpToolResult.error('A build started from the Build Manager or the Build menu is running '
              '(get_build_status: ${b.currentStage}); wait for it to finish.');
        }
        vm.openSubEditorTab('buildManager', title: 'Build Manager');
        final planned = <BuildStepKind>{};
        final McpJob job = jobs.start(
          kind,
          title: cook ? 'Cook & Package (${b.selectedTargets.join(', ')}, ${b.configuration.label})' : 'Build All',
          exclusive: kMcpBuildPipeline,
          cancel: b.cancel,
          run: (job) async {
            var mirrored = b.logLines.length;
            void follow() {
              final lines = b.logLines;
              for (; mirrored < lines.length; mirrored++) {
                final l = lines[mirrored];
                job.addLog(l.message, level: l.level, source: l.source);
              }
              job.update(stage: b.currentStage, progress: b.globalProgress, clearProgress: b.globalProgress == null && b.isRunning);
            }

            b.addListener(follow);
            b.confirmCookOverride = (issues) async {
              job.addLog(
                  'Validate Assets failed (${issues.length} issue(s)); continue_on_validation_failure is $continueAnyway, so '
                  '${continueAnyway ? 'Cook & Package runs anyway' : 'Cook & Package is skipped'}',
                  level: 'warning',
                  source: 'MCP');
              return continueAnyway;
            };
            try {
              if (cook && b.hostTargets == null) {
                job.update(stage: 'Probing the Flutter toolchain (flutter doctor -v)…');
                await b.init();
              }
              planned.addAll(_plannedSteps(b, cook: cook));
              final result = await (cook ? b.cookAndPackage() : b.buildAll());
              follow();
              final report = status(b, planned: planned)..remove('job_id');
              if (result == null) {
                final why = cook ? (b.cookDisabledReason ?? 'the build did not start') : 'no build step is enabled';
                throw McpJobFailure('The build did not start: $why', result: report);
              }
              if (result == BuildStepStatus.failed) {
                throw McpJobFailure('The build failed (${b.currentStage}); see the log and the per-step statuses.', result: report);
              }
              return report;
            } finally {
              b.removeListener(follow);
              b.confirmCookOverride = null;
            }
          },
        );
        return McpToolResult.json({'job_id': job.id, 'state': job.state.name, 'kind': kind, 'title': job.title});
      },
    ),
    McpTool(
      name: 'get_build_status',
      risk: McpToolRisk.readOnly,
      groups: build,
      title: 'Build status',
      description: 'The Build Manager\'s current or last run, whoever started it (start_build, the Build menu, the '
          'tab): is_running, stage, progress, per-step and per-target statuses, artifact_path, last_pipeline_status, '
          'validation issues, and job_id when an agent\'s job runs it. The last log lines are included (log_tail).',
      inputSchema: McpSchema.object({
        'log_tail': McpSchema.integer('How many of the newest log lines to include (default 20, max 500).'),
      }),
      handler: (args) {
        final b = bm();
        final tail = args.integer('log_tail', fallback: 20).clamp(0, 500);
        final lines = b.logLines;
        final from = lines.length > tail ? lines.length - tail : 0;
        return McpToolResult.json({
          ...status(b),
          'log': [
            for (var i = from; i < lines.length; i++)
              {'index': i, 'level': lines[i].level, 'source': lines[i].source, 'message': lines[i].message},
          ],
        });
      },
    ),
    McpTool(
      name: 'launch_web_build',
      risk: McpToolRisk.external,
      groups: build,
      idempotent: false,
      openWorld: true,
      title: 'Launch web build',
      description: 'The Build Manager\'s Launch in Browser: serves the last packaged web build on localhost and opens it '
          'in the system browser. Returns the served URL. Needs a successful Cook & Package with the web target.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) async {
        final b = bm();
        if (!b.canLaunchInBrowser) {
          return McpToolResult.error(b.isRunning
              ? 'A build is running; launch when it has finished.'
              : 'There is no packaged web build: tick the web target (set_build_settings) and start_build cook_and_package.');
        }
        final url = await b.launchInBrowser();
        if (url == null) return McpToolResult.error('The web build could not be served (get_build_status has the log).');
        return McpToolResult.json({'url': url.toString(), 'package_dir': b.webPackageDir});
      },
    ),
  ]);
}
