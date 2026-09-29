import 'dart:async';

import 'package:lumina/lumina.dart';

import '../../main_editor/services/blueprint_play_support.dart';
import '../../main_editor/services/standalone_game_runner.dart';
import '../../main_editor/view_models/editor_view_model.dart';
import '../services/mcp_jobs.dart';
import '../services/mcp_play_testing.dart';
import '../services/mcp_protocol.dart';
import '../services/mcp_tool.dart';

/// The key of Play Standalone's one game process.
const String kMcpStandalone = 'standalone';

/// Play-In-Editor as MCP tools: start, stop, pause, resume,
/// step, and the session's status, over `requestPlay` and the `PieController`;
/// also eject / possess and Play Standalone as a job.
void registerPlayTools(McpToolRegistry registry, EditorViewModel vm, {required McpPlayTesting play, required McpJobRegistry jobs}) {
  Map<String, Object?> status() {
    final pie = vm.pieController;
    final pawn = pie.possessedPawn;
    return {
      'playing': vm.isPlaying,
      'paused': vm.isPaused,
      'ejected': pie.isEjected,
      'runtime_mounted': pie.isPlaying,
      'pawn_class': pie.pawnClassLabel,
      'player_location': pawn == null ? null : LuminaAxes.toAuthoringLocation(pawn.actorLocation),
      'last_error': pie.lastError,
      'blockers': vm.playBlockers.map((b) => {'blueprint': b.blueprintPath, 'node_id': b.nodeId, 'node_title': b.nodeTitle, 'message': b.message}).toList(),
      'warnings': vm.playWarnings.map((w) => {'blueprint': w.blueprintPath, 'node_id': w.nodeId, 'node_title': w.nodeTitle, 'message': w.message}).toList(),
      // The keys agents hold and the frames they advanced.
      'held_keys': play.heldKeys,
      'frames_advanced': play.framesAdvanced,
    };
  }

  // Read on use: a test sets the runner's flutter before the first read.
  StandaloneGameRunner runner() => vm.standalone;
  Map<String, Object?> standaloneStatus() => {
        'state': runner().state.name,
        'pid': runner().pid,
        'last_pid': runner().lastPid,
        'last_exit_code': runner().lastExitCode,
        'output_lines': runner().output.length,
        'job_id': jobs.runningOn(kMcpStandalone)?.id,
      };

  registry.registerAll([
    McpTool(
      name: 'pie_status',
      risk: McpToolRisk.readOnly,
      groups: const {McpToolGroups.pie},
      title: 'Play-In-Editor status',
      description: 'Whether Play-In-Editor is running or paused, which pawn class the player possesses and where it '
          'is (cm, Z up), the last runtime error, and the Blueprint blockers / warnings of the last Play attempt.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) => McpToolResult.json(status()),
    ),
    McpTool(
      name: 'start_pie',
      risk: McpToolRisk.editorState,
      groups: const {McpToolGroups.pie},
      idempotent: false,
      title: 'Start Play-In-Editor',
      description: 'Presses Play: open Blueprints compile first; compile errors keep Play from starting and come back '
          'as a tool error listing the Blueprint, node and message. While Play runs the level tools are refused; '
          'stop_pie restores the editor\'s level exactly as it was.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) async {
        if (vm.isPlaying) return McpToolResult.error('Play-In-Editor is already running (pie_status).');
        final started = await vm.requestPlay();
        if (!started) {
          final blockers = vm.playBlockers.map((b) => '• $b').join('\n');
          return McpToolResult.error('Play did not start.${blockers.isEmpty ? '' : '\n$blockers'}');
        }
        return McpToolResult.json(status());
      },
    ),
    McpTool(
      name: 'stop_pie',
      risk: McpToolRisk.editorState,
      groups: const {McpToolGroups.pie},
      idempotent: true,
      title: 'Stop Play-In-Editor',
      description: 'Stops Play and restores the editor\'s level, selection and camera from before Play.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) {
        if (!vm.isPlaying) return McpToolResult.error('Play-In-Editor is not running.');
        // The keys agents hold are let go while the world
        // still exists, so none stays down in it.
        final released = play.releaseAll();
        vm.stopSimulation();
        return McpToolResult.json({...status(), 'released_keys': released});
      },
    ),
    McpTool(
      name: 'pause_pie',
      risk: McpToolRisk.editorState,
      groups: const {McpToolGroups.pie},
      idempotent: true,
      title: 'Pause Play-In-Editor',
      description: 'Pauses the running game (timers, physics and audio freeze). step_pie then advances one frame.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) {
        if (!vm.isPlaying) return McpToolResult.error('Play-In-Editor is not running; call start_pie first.');
        if (!vm.isPaused) vm.togglePauseSimulation();
        return McpToolResult.json(status());
      },
    ),
    McpTool(
      name: 'resume_pie',
      risk: McpToolRisk.editorState,
      groups: const {McpToolGroups.pie},
      idempotent: true,
      title: 'Resume Play-In-Editor',
      description: 'Resumes a paused game.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) {
        if (!vm.isPlaying) return McpToolResult.error('Play-In-Editor is not running; call start_pie first.');
        if (vm.isPaused) vm.togglePauseSimulation();
        return McpToolResult.json(status());
      },
    ),
    McpTool(
      name: 'step_pie',
      risk: McpToolRisk.editorState,
      groups: const {McpToolGroups.pie},
      idempotent: false,
      title: 'Step Play-In-Editor',
      description: 'Advances the paused game by one frame (1/60 s). Requires pause_pie first.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) {
        if (!vm.isPlaying) return McpToolResult.error('Play-In-Editor is not running; call start_pie first.');
        if (!vm.isPaused) return McpToolResult.error('The game is not paused; call pause_pie first, then step_pie.');
        vm.stepSimulation();
        return McpToolResult.json(status());
      },
    ),
    McpTool(
      name: 'eject_pie',
      risk: McpToolRisk.editorState,
      groups: const {McpToolGroups.pie},
      idempotent: true,
      title: 'Eject from the player',
      description: 'The toolbar\'s Eject: the game keeps running but takes no input (the editor camera flies instead); '
          'keys agents hold are released. possess_pie takes the player back.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) {
        final pie = vm.pieController;
        if (!pie.isPlaying) return McpToolResult.error('Play-In-Editor is not running; call start_pie first.');
        final released = play.releaseAll();
        pie.eject();
        vm.notifyListeners();
        return McpToolResult.json({...status(), 'released_keys': released});
      },
    ),
    McpTool(
      name: 'possess_pie',
      risk: McpToolRisk.editorState,
      groups: const {McpToolGroups.pie},
      idempotent: true,
      title: 'Possess the player',
      description: 'Takes the player back after eject_pie: keys, axes and actions reach the game again.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) {
        final pie = vm.pieController;
        if (!pie.isPlaying) return McpToolResult.error('Play-In-Editor is not running; call start_pie first.');
        pie.possess();
        vm.notifyListeners();
        return McpToolResult.json(status());
      },
    ),
    McpTool(
      name: 'play_standalone',
      risk: McpToolRisk.external,
      groups: const {McpToolGroups.pie},
      idempotent: false,
      openWorld: true,
      title: 'Play Standalone',
      description: 'Debug → Play Standalone as a job: open Blueprints compile (errors are a tool error, as for start_pie), '
          'the level is saved and the game code generated, then a real flutter build <host> --debug runs and the game '
          'starts as its own process. Returns {job_id} at once; the job\'s stage goes building → running, its log is the '
          'build and game output, its result {pid, last_exit_code} when the game exits. stop_standalone / cancel_job stop '
          'it. The standalone game is a separate process: input tools, actor readback and screenshots are Play-In-Editor '
          'only.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) async {
        final running = jobs.runningOn(kMcpStandalone);
        if (running != null) {
          return McpToolResult.error('${running.id} (Play Standalone) is still ${running.stage ?? 'running'}; stop_standalone first.');
        }
        if (runner().isActive) {
          return McpToolResult.error('Play Standalone is already ${runner().state.name} (started from the editor); stop_standalone first.');
        }
        // The Blueprint gate first, so a blocker is this call's error.
        final pending = vm.openBlueprintEditors.where(BlueprintPlayPreflight.needsCompile).toList();
        final blockers = pending.isEmpty ? const <PlayBlocker>[] : await BlueprintPlayPreflight.compileEditors(vm.projectDirPath, pending);
        if (blockers.isNotEmpty) {
          return McpToolResult.error('Play Standalone did not start.\n${blockers.map((b) => '• $b').join('\n')}');
        }
        final job = jobs.start('play_standalone', title: 'Play Standalone', exclusive: kMcpStandalone, cancel: () => unawaited(vm.stopStandalone()),
            run: (job) async {
          var mirrored = 0;
          final ended = Completer<void>();
          var sawActive = false;
          void follow() {
            for (; mirrored < runner().output.length; mirrored++) {
              job.addLog(runner().output[mirrored], source: 'Standalone');
            }
            final state = runner().state;
            if (state != StandaloneState.idle) sawActive = true;
            job.update(stage: state.name);
            if (sawActive && state == StandaloneState.idle && !ended.isCompleted) ended.complete();
          }

          runner().addListener(follow);
          try {
            job.update(stage: 'preparing');
            final started = await vm.playStandalone();
            follow();
            if (!started) {
              throw McpJobFailure(
                  sawActive ? 'The build failed or produced no game executable (the job log has the build output).' : 'Play Standalone could not start (read_output_log, source Standalone, says why).',
                  result: standaloneStatus()..remove('job_id'));
            }
            job.addLog('Game running (pid ${runner().pid})', level: 'success', source: 'Standalone');
            await ended.future;
            follow();
            return {'pid': runner().lastPid, 'last_exit_code': runner().lastExitCode};
          } finally {
            runner().removeListener(follow);
          }
        });
        return McpToolResult.json({'job_id': job.id, 'state': job.state.name, 'kind': job.kind});
      },
    ),
    McpTool(
      name: 'stop_standalone',
      risk: McpToolRisk.editorState,
      groups: const {McpToolGroups.pie},
      idempotent: true,
      title: 'Stop Play Standalone',
      description: 'Stops the standalone game (or its build) and cancels its job; returns the standalone status.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) async {
        final job = jobs.runningOn(kMcpStandalone);
        if (job == null && !runner().isActive) return McpToolResult.error('Play Standalone is not running.');
        if (job != null) jobs.cancel(job);
        await vm.stopStandalone();
        if (job != null) {
          try {
            await job.runDone.timeout(const Duration(seconds: 5));
          } catch (_) {}
        }
        return McpToolResult.json({...standaloneStatus(), 'cancelled_job': job?.id});
      },
    ),
    McpTool(
      name: 'standalone_status',
      risk: McpToolRisk.readOnly,
      groups: const {McpToolGroups.pie},
      title: 'Play Standalone status',
      description: 'Play Standalone\'s state (idle | building | running), the game\'s pid, the last pid and exit code, and '
          'the job running it.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) => McpToolResult.json(standaloneStatus()),
    ),
  ]);
}

