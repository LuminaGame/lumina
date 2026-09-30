import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart' show GlobalKey;

import '../../main_editor/commands/editor_transaction.dart';
import '../../main_editor/view_models/editor_view_model.dart';
import '../services/mcp_frame_capture.dart';
import '../services/mcp_play_testing.dart';
import '../services/mcp_protocol.dart';
import '../services/mcp_tool.dart';
import 'play_testing_tools.dart';

/// `pie_sequence`'s step limit.
const int kMcpMaxSequenceSteps = 50;

/// `pie_sequence`'s screenshot limit.
const int kMcpMaxSequenceScreenshots = 10;

/// The frames `pie_sequence` steps after starting Play, at most, until the
/// player's pawn exists.
const int kMcpSequenceSettleFrames = 30;

/// How long `pie_sequence` waits for a Play it started to mount.
const Duration kMcpSequenceMountTimeout = Duration(seconds: 15);

/// The step kinds, each with the extra fields it takes (`label` is allowed
/// on every step).
const Map<String, Set<String>> _kinds = {
  'key': {'hold_ms', 'hold_frames', 'state'},
  'action': {'value', 'hold_ms', 'hold_frames'},
  'axis': {'value'},
  'click': {},
  'mouse_move': {},
  'play_ms': {},
  'advance_frames': {},
  'screenshot': {},
  'expect': {},
};

const Set<String> _expectChecks = {'player_moved', 'min_distance_cm', 'log_contains'};

/// One validated step.
typedef _Step = ({int index, String kind, String? label, Map<String, Object?> raw});

/// Frames of game time [ms] stands for, stepped at 60 fps (at least one).
int _framesOf(int ms) => math.max(1, (ms * 60 / 1000).round());

Never _invalid(String message) => throw JsonRpcException(JsonRpcErrorCode.invalidParams, message);

/// A step that did not do what it asked for; [message] says why.
class _StepFailure implements Exception {
  const _StepFailure(this.message);
  final String message;
}

/// A scripted play test in one call: `pie_sequence` starts Play when
/// needed, runs its steps through the play-testing tools' own handlers
/// (`pie_key`, `pie_action`, `pie_axis`, `pie_click`, `pie_mouse_move`,
/// `pie_play_for`, `pie_advance`), captures labelled viewport screenshots
/// and checks light assertions on the player, and returns a per-step log.
/// It stops at the first failing step, releases the keys the calling
/// session holds, and stops a Play it started when a step fails.
void registerPieSequenceTool(
  McpToolRegistry registry,
  EditorViewModel vm,
  McpPlayTesting play, {
  required GlobalKey viewportBoundaryKey,
}) {
  final controller = vm.pieController;

  /// Runs another registered tool's handler for this call (the approval
  /// chain already reviewed `pie_sequence`, at the same risk).
  Future<McpToolResult> runTool(String name, Map<String, Object?> args) async {
    final tool = registry.byName(name);
    if (tool == null) throw StateError('The $name tool is not registered.');
    return await tool.handler(McpArgs(args));
  }

  String textOf(McpToolResult r) => r.content.where((c) => c['type'] == 'text').map((c) => c['text']).join('\n');

  List<_Step> validate(McpArgs args) {
    final raw = args['steps'];
    if (raw is! List || raw.isEmpty || raw.length > kMcpMaxSequenceSteps) {
      _invalid('steps must be an array of 1..$kMcpMaxSequenceSteps step objects.');
    }
    final steps = <_Step>[];
    var gameMs = 0.0;
    var screenshots = 0;
    for (var i = 0; i < raw.length; i++) {
      final s = raw[i];
      if (s is! Map) _invalid('step $i must be an object such as {"key": "W", "hold_ms": 800}.');
      final step = Map<String, Object?>.from(s);
      final kinds = step.keys.where(_kinds.containsKey).toList();
      if (kinds.length != 1) {
        _invalid('step $i must have exactly one of ${_kinds.keys.join(', ')}; it has ${kinds.isEmpty ? 'none' : kinds.join(' and ')}.');
      }
      final kind = kinds.single;
      final allowed = {kind, 'label', ..._kinds[kind]!};
      final unknown = step.keys.where((k) => !allowed.contains(k)).toList();
      if (unknown.isNotEmpty) {
        _invalid('step $i ($kind) has no field ${unknown.join(', ')}; it takes ${allowed.join(', ')}.');
      }
      final label = step['label'];
      if (label != null && label is! String) _invalid('step $i: label must be a string.');
      int intIn(String field, int max) {
        final v = step[field];
        if (v is! num || v != v.roundToDouble() || v < 1 || v > max) _invalid('step $i: $field must be an integer 1..$max.');
        return v.toInt();
      }

      int? holdFrames() {
        if (step.containsKey('hold_ms') && step.containsKey('hold_frames')) _invalid('step $i: give hold_ms or hold_frames, not both.');
        if (step.containsKey('hold_ms')) {
          final ms = intIn('hold_ms', kMcpMaxPlayForMs);
          gameMs += ms;
          return _framesOf(ms);
        }
        if (step.containsKey('hold_frames')) {
          final frames = intIn('hold_frames', kMcpMaxAdvanceFrames);
          gameMs += frames * 1000 / 60;
          return frames;
        }
        return null;
      }

      switch (kind) {
        case 'key':
          if (step['key'] is! String) _invalid('step $i: key must be a key name ("W", "Space", "MouseLeft", …).');
          final state = step['state'];
          if (state != null) {
            if (state != 'down' && state != 'up') _invalid('step $i: state must be "down" or "up".');
            if (step.containsKey('hold_ms') || step.containsKey('hold_frames')) {
              _invalid('step $i: a key with state holds until its "up" step; hold_ms / hold_frames are for a tap.');
            }
          } else {
            if (holdFrames() == null) gameMs += 1000 / 60;
          }
        case 'action':
          if (step['action'] is! String) _invalid('step $i: action must be an input action name (IA_Jump).');
          if (holdFrames() == null) gameMs += 1000 / 60;
        case 'axis':
          if (step['axis'] is! String) _invalid('step $i: axis must be an analog key (MouseX, GamepadLeftStickY, …).');
          if (step['value'] is! num) _invalid('step $i: axis needs a numeric value.');
        case 'click':
          final c = step['click'];
          if (c is! Map || c['x'] is! num || c['y'] is! num || c.length != 2) _invalid('step $i: click must be {"x": px, "y": px}.');
        case 'mouse_move':
          final m = step['mouse_move'];
          if (m is! Map || m['dx'] is! num || m['dy'] is! num || m.length != 2) _invalid('step $i: mouse_move must be {"dx": px, "dy": px}.');
        case 'play_ms':
          gameMs += intIn('play_ms', kMcpMaxPlayForMs);
        case 'advance_frames':
          gameMs += intIn('advance_frames', kMcpMaxAdvanceFrames) * 1000 / 60;
        case 'screenshot':
          if (step['screenshot'] != true) _invalid('step $i: screenshot must be true.');
          screenshots++;
        case 'expect':
          final e = step['expect'];
          if (e is! Map || e.isEmpty || e.keys.any((k) => !_expectChecks.contains(k))) {
            _invalid('step $i: expect must be an object of ${_expectChecks.join(', ')}.');
          }
          if (e.containsKey('player_moved') && e['player_moved'] is! bool) _invalid('step $i: expect.player_moved must be a boolean.');
          if (e.containsKey('min_distance_cm') && e['min_distance_cm'] is! num) _invalid('step $i: expect.min_distance_cm must be a number.');
          if (e.containsKey('log_contains') && e['log_contains'] is! String) _invalid('step $i: expect.log_contains must be a string.');
      }
      steps.add((index: i, kind: kind, label: label as String?, raw: step));
    }
    if (screenshots > kMcpMaxSequenceScreenshots) {
      _invalid('A sequence takes at most $kMcpMaxSequenceScreenshots screenshots; this one has $screenshots.');
    }
    if (gameMs > kMcpMaxPlayForMs + 0.5) {
      _invalid('The steps add up to ${gameMs.round()} ms of game time; a sequence plays at most $kMcpMaxPlayForMs ms.');
    }
    return steps;
  }

  registry.register(McpTool(
    name: 'pie_sequence',
    risk: McpToolRisk.editorState,
    groups: const {McpToolGroups.pie},
    idempotent: false,
    title: 'Run a scripted play test',
    description: 'A whole play test in one call. Starts Play when it is not running (start, default true; as start_pie, '
        'from the level\'s PlayerStart, then settles until the pawn exists), runs up to $kMcpMaxSequenceSteps steps in '
        'order and leaves Play paused (stop_at_end: true stops it). Steps: {"key": "W", "hold_ms": 800} (a tap held for '
        'that much game time, 60 fps frames), {"key": "W", "state": "down" | "up"}, {"action": "IA_Jump"}, {"action": '
        '"IA_Move", "value": [0, 1], "hold_ms": 500}, {"axis": "MouseX", "value": 40}, {"click": {"x", "y"}}, '
        '{"mouse_move": {"dx", "dy"}}, {"play_ms": 500} (wall-clock play), {"advance_frames": 10}, {"screenshot": true}, '
        '{"expect": {"player_moved": true, "min_distance_cm": 100, "log_contains": "text"}} (against where the player '
        'was when the steps began); any step may carry a "label". Each input step runs the matching pie_* tool. A Play '
        'the sequence starts loads its meshes over its first wall-clock moment: begin with {"play_ms": 1500} before a '
        'first screenshot. Limits: '
        '$kMcpMaxSequenceSteps steps, $kMcpMaxSequenceScreenshots screenshots, $kMcpMaxPlayForMs ms of game time in all. '
        'Returns steps [{index, kind, label, ok, result, player_location, log}], the screenshots as images each after '
        'a caption naming its step and label, and final_status (pie_status). The first failing step stops the '
        'sequence (a tool error with failed_step); the keys your session holds are released at the end, and a Play '
        'the sequence started is stopped on error unless keep_pie_on_error.',
    inputSchema: McpSchema.object({
      'steps': {
        'type': 'array',
        'description': 'The steps, 1..$kMcpMaxSequenceSteps objects, each with one kind (key, action, axis, click, '
            'mouse_move, play_ms, advance_frames, screenshot, expect) and an optional label.',
        'items': {'type': 'object'},
      },
      'start': McpSchema.boolean('Start Play when it is not running (default true).'),
      'stop_at_end': McpSchema.boolean('Stop Play when the steps are done (default false: it stays running, paused).'),
      'keep_pie_on_error': McpSchema.boolean('Keep a Play the sequence started running (paused) when a step fails '
          '(default false: it is stopped).'),
      'screenshot_max_width': McpSchema.integer('Largest screenshot width in pixels; default 1280, at least 64.'),
    }, required: ['steps']),
    handler: (args) async {
      final steps = validate(args);
      final maxWidth = args.integer('screenshot_max_width', fallback: 1280);
      if (maxWidth < 64) _invalid('screenshot_max_width must be at least 64');
      final start = args.boolean('start', fallback: true);
      final stopAtEnd = args.boolean('stop_at_end');
      final keepOnError = args.boolean('keep_pie_on_error');

      if (vm.activeTabIndex != 0) {
        return McpToolResult.error('The level viewport is not shown: tab ${vm.activeTabIndex} ("${vm.currentTab.title}") is '
            'active, and Play runs in the level viewport. Switch to the level tab first (select_tab 0).');
      }
      var startedPie = false;
      var settleFrames = 0;
      if (!vm.isPlaying && !controller.isPlaying) {
        if (!start) return McpToolResult.error('Play-In-Editor is not running; call start_pie first, or pass start: true.');
        final started = await runTool('start_pie', const {});
        if (started.isError) return started;
        startedPie = true;
        final deadline = DateTime.now().add(kMcpSequenceMountTimeout);
        while (vm.isPlaying && (!controller.isPlaying || controller.game == null) && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }
      final refusal = mcpPieRefusal(vm);
      if (refusal != null) {
        if (startedPie && vm.isPlaying) await runTool('stop_pie', const {});
        return refusal;
      }
      if (startedPie) {
        // The pawn spawns deferred: the first frames register and land it.
        play.pauseForStepping();
        while (controller.possessedPawn == null && settleFrames < kMcpSequenceSettleFrames && controller.isPlaying) {
          play.step(1, 1 / 60);
          settleFrames++;
        }
      }

      final logs = vm.logs;
      final sequenceLogFrom = logs.length;
      final origin = mcpPlayerLocation(vm);
      final log = <Map<String, Object?>>[];
      final shots = <Map<String, Object?>>[];
      final images = <Map<String, Object?>>[];
      int? failedStep;
      String? error;

      List<Map<String, Object?>> linesSince(int from) {
        final all = vm.logs;
        return [
          for (var i = from.clamp(0, all.length); i < all.length; i++)
            {'index': i, 'level': all[i].level, 'source': all[i].source, 'message': all[i].message},
        ];
      }

      double? movedCm() {
        final now = mcpPlayerLocation(vm);
        if (origin == null || now == null) return null;
        return math.sqrt(math.pow(now[0] - origin[0], 2) + math.pow(now[1] - origin[1], 2) + math.pow(now[2] - origin[2], 2));
      }

      /// Runs one step: its result on success, else throws the failure text.
      Future<Map<String, Object?>> runStep(_Step step) async {
        final s = step.raw;
        Future<Map<String, Object?>> via(String tool, Map<String, Object?> toolArgs) async {
          final McpToolResult r;
          try {
            r = await runTool(tool, toolArgs);
          } on JsonRpcException catch (e) {
            throw _StepFailure(e.message);
          }
          if (r.isError) throw _StepFailure(textOf(r));
          final data = Map<String, Object?>.from(r.structuredContent ?? const {})..remove('log');
          if (data['dropped'] == true) throw _StepFailure('${data['note']}');
          return data;
        }

        switch (step.kind) {
          case 'key':
            final state = s['state'] as String?;
            if (state != null) return via('pie_key', {'key': s['key'], 'action': state});
            final frames = s.containsKey('hold_ms') ? _framesOf((s['hold_ms'] as num).toInt()) : (s['hold_frames'] as num?)?.toInt() ?? 1;
            return via('pie_key', {'key': s['key'], 'action': 'tap', 'hold_frames': frames});
          case 'action':
            final frames = s.containsKey('hold_ms') ? _framesOf((s['hold_ms'] as num).toInt()) : (s['hold_frames'] as num?)?.toInt();
            return via('pie_action', {'action': s['action'], 'value': ?s['value'], 'hold_frames': ?frames});
          case 'axis':
            return via('pie_axis', {'key': s['axis'], 'value': s['value']});
          case 'click':
            final c = s['click'] as Map;
            return via('pie_click', {'x': c['x'], 'y': c['y']});
          case 'mouse_move':
            final m = s['mouse_move'] as Map;
            return via('pie_mouse_move', {'dx': m['dx'], 'dy': m['dy']});
          case 'play_ms':
            return via('pie_play_for', {'ms': s['play_ms']});
          case 'advance_frames':
            return via('pie_advance', {'frames': s['advance_frames']});
          case 'screenshot':
            final gate = mcpPieRefusal(vm);
            if (gate != null) throw _StepFailure(textOf(gate));
            // The stepped state reaches the screen over the next frames.
            await mcpShowPlayViewport(vm);
            final McpFrame frame;
            try {
              frame = await McpFrameCapture.capture(viewportBoundaryKey, maxWidth: maxWidth, what: 'level viewport');
            } on StateError catch (e) {
              throw _StepFailure(e.message);
            }
            final where = mcpPlayerLocation(vm);
            final name = step.label == null ? '' : ' "${step.label}"';
            shots.add({'step': step.index, 'label': step.label, 'width': frame.width, 'height': frame.height, 'player_location': where});
            images
              ..add(McpContent.text('Step ${step.index}$name: ${frame.width}×${frame.height} PNG of the viewport, '
                  'player at ${where ?? 'n/a'} cm.'))
              ..add(McpContent.image(frame.png));
            return {'width': frame.width, 'height': frame.height};
          case 'expect':
            final e = s['expect'] as Map;
            final moved = movedCm();
            final checks = <String, Object?>{};
            final failures = <String>[];
            if (e.containsKey('player_moved')) {
              if (moved == null) {
                failures.add('player_moved: there is no possessed pawn');
              } else {
                final did = moved > 1.0;
                checks['player_moved'] = did;
                if (did != e['player_moved']) {
                  failures.add('player_moved ${e['player_moved']}: the player moved ${moved.toStringAsFixed(1)} cm since the steps began');
                }
              }
            }
            if (e.containsKey('min_distance_cm')) {
              final min = (e['min_distance_cm'] as num).toDouble();
              checks['distance_cm'] = moved == null ? null : (moved * 10).roundToDouble() / 10;
              if (moved == null || moved < min) {
                failures.add('min_distance_cm $min: the player moved ${moved == null ? 'nowhere (no pawn)' : '${moved.toStringAsFixed(1)} cm'} '
                    'since the steps began');
              }
            }
            if (e.containsKey('log_contains')) {
              final needle = e['log_contains'] as String;
              final found = linesSince(sequenceLogFrom).any((l) => (l['message'] as String).contains(needle));
              checks['log_contains'] = found;
              if (!found) failures.add('log_contains "$needle": no Output Log line of the sequence contains it');
            }
            if (failures.isNotEmpty) throw _StepFailure('expect failed: ${failures.join('; ')}');
            return checks;
        }
        throw _StepFailure('unknown step kind ${step.kind}');
      }

      for (final step in steps) {
        final from = vm.logs.length;
        final entry = <String, Object?>{'index': step.index, 'kind': step.kind, 'label': step.label};
        try {
          entry['result'] = await runStep(step);
          entry['ok'] = true;
        } on _StepFailure catch (f) {
          final message = f.message;
          entry['ok'] = false;
          entry['error'] = message;
          failedStep = step.index;
          final name = step.label == null ? '' : ' "${step.label}"';
          error = 'Step ${step.index} (${step.kind}$name) failed: $message';
        } catch (e) {
          entry['ok'] = false;
          entry['error'] = '$e';
          failedStep = step.index;
          error = 'Step ${step.index} (${step.kind}) failed: $e';
        }
        entry['player_location'] = mcpPlayerLocation(vm);
        entry['log'] = linesSince(from);
        log.add(entry);
        if (failedStep != null) break;
        if (!controller.isPlaying) {
          failedStep = step.index;
          error = 'Play stopped during step ${step.index} (pie_status, read_output_log).';
          break;
        }
      }

      // Safety: no key stays down, and a failed sequence leaves no Play it started.
      final released = play.releaseAll(sessionId: TransactionManager.currentOrigin?.sessionId);
      var stoppedPie = false;
      if (vm.isPlaying && (stopAtEnd || (failedStep != null && startedPie && !keepOnError))) {
        final stopped = await runTool('stop_pie', const {});
        stoppedPie = !stopped.isError;
      } else if (controller.isPlaying) {
        play.pauseForStepping();
        vm.notifyListeners();
      }
      final status = (await runTool('pie_status', const {})).structuredContent;
      final data = <String, Object?>{
        'ok': failedStep == null,
        'failed_step': ?failedStep,
        'error': ?error,
        'started_pie': startedPie,
        if (startedPie) 'settle_frames': settleFrames,
        'stopped_pie': stoppedPie,
        'released_keys': released,
        'steps': log,
        'screenshots': shots,
        'final_status': status,
      };
      final summary = const JsonEncoder.withIndent('  ').convert(data);
      return McpToolResult([
        McpContent.text(error == null ? summary : '$error\n$summary'),
        ...images,
      ], structuredContent: data, isError: error != null);
    },
  ));
}
