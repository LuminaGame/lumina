import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show RenderBox;
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/services.dart' show TextEditingValue, TextInputAction, TextSelection;
import 'package:flutter/widgets.dart' show EditableTextState, FocusManager, GlobalKey, SelectionChangedCause;
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:vector_math/vector_math_64.dart' show Quaternion;

import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/pie_widget_layer.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_frame_capture.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_play_testing.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/project_settings_tools.dart' show mcpKeyNamed;
import 'package:lumina_ui/ui/features/mcp_server/tools/rotation_convention.dart';

/// `pie_advance`'s frame limit.
const int kMcpMaxAdvanceFrames = 600;

/// `pie_play_for`'s wall-clock limit.
const int kMcpMaxPlayForMs = 10000;

/// Authoring degrees `[x, y, z]` of a runtime rotation (the inverse of
/// [LuminaAxes.rotation]).
List<double> mcpAuthoringRotation(Quaternion q) {
  // luminaPawnQuaternionToEuler decomposes q as Ry(−yaw)·Rx(pitch)·Rz(−roll);
  // q is authored as Ry(−z)·Rx(x)·Rz(y).
  final e = luminaPawnQuaternionToEuler(q);
  double clean(double v) => (v * 1000).roundToDouble() / 1000 + 0.0;
  return [clean(e.x), clean(-e.z), clean(e.y)];
}

List<double> _cm(List<double> v) => [for (final c in v) (c * 1000).roundToDouble() / 1000];

/// Null while a Play-In-Editor world runs, else the tool error the
/// play-testing tools answer with.
McpToolResult? mcpPieRefusal(EditorViewModel vm) {
  final controller = vm.pieController;
  if (!vm.isPlaying && !controller.isPlaying) {
    return McpToolResult.error('Play-In-Editor is not running; call start_pie first.');
  }
  if (!controller.isPlaying || controller.game == null) {
    return McpToolResult.error('Play-In-Editor has no running game world: the level viewport is not shown, so Play '
        'has not mounted. Show the level tab (select_tab 0) and try again, or stop_pie.');
  }
  return null;
}

/// Puts the level viewport, where Play runs, on screen and waits for its
/// next [frames] frames, so the running game (the play camera, a stepped
/// state) is what it shows. The workspace keeps a tab that another tab hides
/// mounted but unpainted: captured then, it still holds its frame from before.
Future<void> mcpShowPlayViewport(EditorViewModel vm, {int frames = 3}) async {
  if (vm.activeTabIndex != 0) vm.selectTab(0);
  final binding = SchedulerBinding.instance;
  for (var i = 0; i < frames; i++) {
    binding.scheduleFrame();
    await binding.endOfFrame.timeout(const Duration(milliseconds: 100), onTimeout: () {});
  }
}

/// Where the possessed pawn is (cm, Z up, rounded to 0.001), or null.
List<double>? mcpPlayerLocation(EditorViewModel vm) {
  final pawn = vm.pieController.possessedPawn;
  return pawn == null ? null : _cm(LuminaAxes.toAuthoringLocation(pawn.actorLocation));
}

/// Play-testing tools (group `pie`): keys, axes, mouse and
/// Enhanced Input actions into the running Play-In-Editor game — through
/// the project's own key bindings, so triggers and modifiers run as for a
/// player — a click and typed text into its UMG widgets, frame-exact
/// advance and wall-clock play, and the runtime actors read back.
void registerPlayTestingTools(
  McpToolRegistry registry,
  EditorViewModel vm,
  McpPlayTesting play, {
  required GlobalKey viewportBoundaryKey,
}) {
  const pie = {McpToolGroups.pie};
  final controller = vm.pieController;

  /// Null while a PIE world runs, else the refusal.
  McpToolResult? refuse() => mcpPieRefusal(vm);

  List<double>? playerLocation() => mcpPlayerLocation(vm);

  Map<String, Object?> actorJson(LuminaActor a) {
    final key = a.key;
    final bp = a is LuminaBlueprintInstance ? a.blueprintClass.name : null;
    return {
      'id': key?.value,
      'class': bp ?? a.runtimeType.toString(),
      'native_class': a.runtimeType.toString(),
      'location': _cm(LuminaAxes.toAuthoringLocation(a.actorLocation)),
      'rotation': mcpAuthoringRotation(a.actorRotation),
      if (a is LuminaCharacter) 'velocity': _cm(LuminaAxes.toAuthoringLocation(a.characterMovement.velocity)),
      'is_possessed_pawn': identical(a, controller.possessedPawn),
    };
  }

  List<Map<String, Object?>> actors({List<String>? ids, String? classContains, int limit = 100}) {
    final world = controller.game?.gameInstance.world;
    if (world == null) return const [];
    final needle = classContains?.toLowerCase();
    final out = <Map<String, Object?>>[];
    for (final a in world.persistentLevel.actors) {
      final json = actorJson(a);
      if (ids != null && !ids.contains(json['id'])) continue;
      if (needle != null &&
          !(json['class'] as String).toLowerCase().contains(needle) &&
          !(json['native_class'] as String).toLowerCase().contains(needle)) {
        continue;
      }
      out.add(json);
      if (out.length >= limit) break;
    }
    return out;
  }

  /// The shape pie_advance / pie_play_for return: frames, where the player
  /// is, the actors (on request), the log lines emitted since [logFrom], and
  /// a screenshot (on request).
  Future<McpToolResult> report(McpArgs args, int logFrom, Map<String, Object?> head) async {
    final logs = vm.logs;
    final from = logFrom.clamp(0, logs.length);
    final data = <String, Object?>{
      ...head,
      'paused': controller.isPaused,
      'frames_advanced': play.framesAdvanced,
      'held_keys': play.heldKeys,
      'player_location': playerLocation(),
      if (args.boolean('actors')) 'actors': actors(),
      'log': [
        for (var i = from; i < logs.length; i++)
          {'index': i, 'level': logs[i].level, 'source': logs[i].source, 'message': logs[i].message},
      ],
    };
    if (!args.boolean('screenshot')) return McpToolResult.json(data);
    try {
      await mcpShowPlayViewport(vm);
      final frame = await McpFrameCapture.capture(viewportBoundaryKey, what: 'level viewport');
      data['screenshot'] = {'width': frame.width, 'height': frame.height};
      return McpToolResult([McpContent.image(frame.png), McpContent.text(_jsonLine(data))], structuredContent: data);
    } on StateError catch (e) {
      data['screenshot_error'] = e.message;
      return McpToolResult.json(data);
    }
  }

  const ejectedNote = 'The player is ejected (eject_pie): the game takes no input until possess_pie; the press was dropped.';

  // --- pie_action: an action through the project's key bindings -------------

  /// The bindings of [action] in the contexts Play bound, highest priority
  /// first: (key, toX, toY) — toX / toY are the axis placement (scale on
  /// the mapping's axis; digital actions carry 1, 0).
  List<(LuminaKey, double, double)> bindingsOf(String action) {
    final bound = controller.boundInputForProject();
    final contexts = [...bound.contexts]..sort((a, b) => b.priority.compareTo(a.priority));
    return [
      for (final c in contexts)
        for (final m in c.context.mappings)
          if (m.action.name == action)
            (
              m.key,
              m.modifiers.whereType<LuminaAxisPlacementModifier>().firstOrNull?.toX ?? 1.0,
              m.modifiers.whereType<LuminaAxisPlacementModifier>().firstOrNull?.toY ?? 0.0,
            ),
    ];
  }

  String describeBindings() {
    final bound = controller.boundInputForProject();
    return bound.actions.keys.map((name) {
      final keys = bindingsOf(name).map((b) => b.$1.id).toSet();
      return '$name (${keys.isEmpty ? 'unbound' : keys.join(', ')})';
    }).join(', ');
  }

  registry.registerAll([
    McpTool(
      name: 'pie_key',
      risk: McpToolRisk.editorState,
      groups: pie,
      idempotent: false,
      title: 'Press a key in Play',
      description: 'A key in the running game, as a player presses it: action "down" holds it (across pie_advance / '
          'pie_play_for frames) until "up"; "tap" is down, hold_frames (default 1) advanced frames, then up. key: "W", '
          '"Space", "KeyW", "LeftShift", "MouseLeft" (the game\'s fire button), "GamepadFaceButtonBottom", … Keys you hold '
          'are released on stop_pie, eject_pie and when your MCP session ends.',
      inputSchema: McpSchema.object({
        'key': McpSchema.string('The key name.'),
        'action': McpSchema.string('down, up or tap.', enumValues: const ['down', 'up', 'tap']),
        'hold_frames': McpSchema.integer('tap: frames the key stays down (1..$kMcpMaxAdvanceFrames, default 1).'),
      }, required: ['key', 'action']),
      handler: (args) {
        final refusal = refuse();
        if (refusal != null) return refusal;
        final key = mcpKeyNamed(args.string('key'));
        if (key.isAnalog) {
          throw JsonRpcException(JsonRpcErrorCode.invalidParams, '${key.id} is an analog axis; use pie_axis (or pie_mouse_move).');
        }
        final action = args.string('action');
        if (action == 'up') {
          play.release(key);
          return McpToolResult.json({'key': key.id, 'action': 'up', 'held_keys': play.heldKeys});
        }
        if (!controller.acceptsScriptedInput) {
          return McpToolResult.json({'key': key.id, 'action': action, 'dropped': true, 'note': ejectedNote, 'held_keys': play.heldKeys});
        }
        if (action == 'down') {
          play.press(key);
          return McpToolResult.json({'key': key.id, 'action': 'down', 'held_keys': play.heldKeys});
        }
        final frames = args.integer('hold_frames', fallback: 1);
        if (frames < 1 || frames > kMcpMaxAdvanceFrames) {
          throw const JsonRpcException(JsonRpcErrorCode.invalidParams, 'hold_frames must be 1..$kMcpMaxAdvanceFrames');
        }
        final wasRunning = play.pauseForStepping();
        play.press(key);
        play.step(frames, 1 / 60);
        play.release(key);
        play.resumeAfterStepping(wasRunning);
        return McpToolResult.json({
          'key': key.id,
          'action': 'tap',
          'frames': frames,
          'held_keys': play.heldKeys,
          'player_location': playerLocation(),
        });
      },
    ),
    McpTool(
      name: 'pie_axis',
      risk: McpToolRisk.editorState,
      groups: pie,
      idempotent: false,
      title: 'Move an analog axis in Play',
      description: 'An analog value for the next frame: key "MouseX" / "MouseY" (pixels of mouse movement), '
          '"GamepadLeftStickX" / "GamepadLeftStickY" / right stick / triggers (-1..1). It is consumed by the next '
          'advanced or played frame (pie_advance / pie_play_for).',
      inputSchema: McpSchema.object({
        'key': McpSchema.string('The analog key.'),
        'value': McpSchema.number('The value.'),
      }, required: ['key', 'value']),
      handler: (args) {
        final refusal = refuse();
        if (refusal != null) return refusal;
        final key = mcpKeyNamed(args.string('key'));
        if (!key.isAnalog) {
          throw JsonRpcException(JsonRpcErrorCode.invalidParams,
              '${key.id} is a digital key; pie_axis takes MouseX, MouseY, GamepadLeftStickX, GamepadLeftStickY, … (pie_key presses digital keys).');
        }
        final value = args.number('value');
        if (!controller.acceptsScriptedInput) {
          return McpToolResult.json({'key': key.id, 'value': value, 'dropped': true, 'note': ejectedNote});
        }
        controller.injectAnalog(key, value, scripted: true);
        return McpToolResult.json({'key': key.id, 'value': value, 'note': 'Applied on the next frame (pie_advance / pie_play_for).'});
      },
    ),
    McpTool(
      name: 'pie_mouse_move',
      risk: McpToolRisk.editorState,
      groups: pie,
      idempotent: false,
      title: 'Move the mouse in Play',
      description: 'A relative mouse movement in pixels (dx right, dy down) for the next frame — the game\'s mouse look, '
          'as when the game has captured the mouse.',
      inputSchema: McpSchema.object({
        'dx': McpSchema.number('Pixels to the right.'),
        'dy': McpSchema.number('Pixels down.'),
      }, required: ['dx', 'dy']),
      handler: (args) {
        final refusal = refuse();
        if (refusal != null) return refusal;
        final dx = args.number('dx');
        final dy = args.number('dy');
        if (!controller.acceptsScriptedInput) {
          return McpToolResult.json({'dx': dx, 'dy': dy, 'dropped': true, 'note': ejectedNote});
        }
        controller.injectMouseDelta(dx, dy, scripted: true);
        return McpToolResult.json({'dx': dx, 'dy': dy, 'note': 'Applied on the next frame (pie_advance / pie_play_for).'});
      },
    ),
    McpTool(
      name: 'pie_action',
      risk: McpToolRisk.editorState,
      groups: pie,
      idempotent: false,
      title: 'Trigger an input action in Play',
      description: 'Fires an Enhanced Input action by pressing the keys the project binds to it (Play\'s mapping '
          'contexts), for hold_frames advanced frames (default 1), then releasing them — so the action\'s modifiers and '
          'triggers run exactly as for a player. value: omitted for a digital action (IA_Jump); a number or [x, y] for an '
          'axis action (IA_Move [0, 1] presses W, [1, 0] presses D; IA_Look [dx, dy] drives MouseX / MouseY). Rebinding '
          'in Project Settings changes what this presses (from the next start_pie).',
      inputSchema: McpSchema.object({
        'action': McpSchema.string('The input action (IA_Jump).'),
        'value': McpSchema.any('Axis actions: a number or [x, y].'),
        'hold_frames': McpSchema.integer('Frames the keys stay down (1..$kMcpMaxAdvanceFrames, default 1).'),
      }, required: ['action']),
      handler: (args) {
        final refusal = refuse();
        if (refusal != null) return refusal;
        final name = args.string('action');
        final bound = controller.boundInputForProject();
        final def = bound.actions[name];
        final bindings = bindingsOf(name);
        if (def == null || bindings.isEmpty) {
          return McpToolResult.error('${def == null ? 'No input action' : 'Nothing binds'} "$name" in this project. '
              'Actions and their keys: ${describeBindings()}.');
        }
        final frames = args.integer('hold_frames', fallback: 1);
        if (frames < 1 || frames > kMcpMaxAdvanceFrames) {
          throw const JsonRpcException(JsonRpcErrorCode.invalidParams, 'hold_frames must be 1..$kMcpMaxAdvanceFrames');
        }
        final digitalKeys = <LuminaKey>[];
        final analog = <LuminaKey, double>{};
        if (def.valueType == InputValueType.digitalBool) {
          final key = bindings.map((b) => b.$1).firstWhere((k) => !k.isAnalog, orElse: () => bindings.first.$1);
          if (key.isAnalog) {
            analog[key] = 1.0;
          } else {
            digitalKeys.add(key);
          }
        } else {
          final raw = args['value'];
          final List<double> wanted;
          if (raw is num) {
            wanted = [raw.toDouble(), 0.0];
          } else if (raw is List && raw.isNotEmpty && raw.length <= 2 && raw.every((v) => v is num)) {
            wanted = [for (final v in raw) (v as num).toDouble(), if (raw.length == 1) 0.0];
          } else {
            throw JsonRpcException(JsonRpcErrorCode.invalidParams, '$name is an axis action: pass value as a number or [x, y].');
          }
          for (var axis = 0; axis < 2; axis++) {
            final v = wanted[axis];
            if (v == 0) continue;
            double along((LuminaKey, double, double) b) => axis == 0 ? b.$2 : b.$3;
            double across((LuminaKey, double, double) b) => axis == 0 ? b.$3 : b.$2;
            final digital = bindings.where((b) => !b.$1.isAnalog && across(b) == 0 && along(b) != 0 && along(b).sign == v.sign);
            final stick = bindings.where((b) => b.$1.isAnalog && along(b) != 0);
            if (digital.isNotEmpty) {
              digitalKeys.add(digital.first.$1);
            } else if (stick.isNotEmpty) {
              analog[stick.first.$1] = v / along(stick.first);
            } else {
              return McpToolResult.error('No key bound to $name produces ${axis == 0 ? 'X' : 'Y'} = $v. Its bindings: '
                  '${bindings.map((b) => '${b.$1.id} → (${b.$2}, ${b.$3})').join(', ')}.');
            }
          }
        }
        if (!controller.acceptsScriptedInput) {
          return McpToolResult.json({'action': name, 'dropped': true, 'note': ejectedNote});
        }
        final wasRunning = play.pauseForStepping();
        for (final k in digitalKeys) {
          play.press(k);
        }
        play.step(frames, 1 / 60, beforeFrame: () {
          for (final e in analog.entries) {
            controller.injectAnalog(e.key, e.value, scripted: true);
          }
        });
        for (final k in digitalKeys) {
          play.release(k);
        }
        play.resumeAfterStepping(wasRunning);
        return McpToolResult.json({
          'action': name,
          'value_type': def.valueType.name,
          'pressed': [for (final k in digitalKeys) k.id],
          'analog': {for (final e in analog.entries) e.key.id: e.value},
          'frames': frames,
          'player_location': playerLocation(),
        });
      },
    ),
    McpTool(
      name: 'pie_click',
      risk: McpToolRisk.editorState,
      groups: pie,
      idempotent: false,
      title: 'Click in the Play viewport',
      description: 'A pointer down + up at (x, y) viewport pixels (the coordinate space of viewport_screenshot at its '
          'natural size): hits the UMG widgets the game added to the viewport (buttons, text fields). The game\'s own '
          'fire button is pie_key {key: "MouseLeft"}.',
      inputSchema: McpSchema.object({
        'x': McpSchema.number('Pixels from the viewport\'s left edge.'),
        'y': McpSchema.number('Pixels from the viewport\'s top edge.'),
      }, required: ['x', 'y']),
      handler: (args) async {
        final refusal = refuse();
        if (refusal != null) return refusal;
        final box = viewportBoundaryKey.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.attached) {
          return McpToolResult.error('The level viewport is not shown: show the level tab (select_tab 0) first.');
        }
        final x = args.number('x');
        final y = args.number('y');
        if (x < 0 || y < 0 || x > box.size.width || y > box.size.height) {
          throw JsonRpcException(JsonRpcErrorCode.invalidParams,
              '($x, $y) is outside the viewport (${box.size.width.round()}×${box.size.height.round()} px).');
        }
        final global = box.localToGlobal(Offset(x, y));
        final logFrom = vm.logs.length;
        final pointer = _nextPointer++;
        final binding = GestureBinding.instance;
        binding.handlePointerEvent(PointerDownEvent(pointer: pointer, position: global, kind: PointerDeviceKind.touch));
        await Future<void>.delayed(const Duration(milliseconds: 16));
        binding.handlePointerEvent(PointerUpEvent(pointer: pointer, position: global, kind: PointerDeviceKind.touch));
        await Future<void>.delayed(Duration.zero);
        final logs = vm.logs;
        return McpToolResult.json({
          'x': x,
          'y': y,
          'global': [global.dx, global.dy],
          'log': [
            for (var i = logFrom.clamp(0, logs.length); i < logs.length; i++)
              {'index': i, 'level': logs[i].level, 'source': logs[i].source, 'message': logs[i].message},
          ],
        });
      },
    ),
    McpTool(
      name: 'pie_type_text',
      risk: McpToolRisk.editorState,
      groups: pie,
      idempotent: false,
      title: 'Type into a Play text field',
      description: 'Types text into the focused text field of the game\'s UMG widgets (click it with pie_click first), '
          'at its cursor; submit: true then commits it (Enter: the field\'s On Text Committed).',
      inputSchema: McpSchema.object({
        'text': McpSchema.string('The text to type.'),
        'submit': McpSchema.boolean('Press Enter afterwards (default false).'),
      }, required: ['text']),
      handler: (args) async {
        final refusal = refuse();
        if (refusal != null) return refusal;
        final context = FocusManager.instance.primaryFocus?.context;
        final state = context?.findAncestorStateOfType<EditableTextState>();
        final inGame = context?.findAncestorWidgetOfExactType<PieWidgetLayer>() != null;
        if (state == null || !inGame) {
          return McpToolResult.error('No text field of the game has keyboard focus: click the field with pie_click first.');
        }
        final text = args.string('text');
        final value = state.textEditingValue;
        final selection = value.selection.isValid ? value.selection : TextSelection.collapsed(offset: value.text.length);
        final next = value.text.replaceRange(selection.start, selection.end, text);
        state.userUpdateTextEditingValue(
          TextEditingValue(text: next, selection: TextSelection.collapsed(offset: selection.start + text.length)),
          SelectionChangedCause.keyboard,
        );
        final submit = args.boolean('submit');
        if (submit) state.performAction(TextInputAction.done);
        await Future<void>.delayed(Duration.zero);
        return McpToolResult.json({'text': next, 'submitted': submit});
      },
    ),
    McpTool(
      name: 'pie_advance',
      risk: McpToolRisk.editorState,
      groups: pie,
      idempotent: false,
      title: 'Advance Play by frames',
      description: 'Frame-exact play-testing: pauses the game if it runs and advances it by frames (1..$kMcpMaxAdvanceFrames) '
          'of dt seconds (default 1/60). Keys held with pie_key down stay held. Logs one "PIE advanced N frames" line. '
          'Returns {frames, player_location (cm, Z up), actors (with actors: true), log (the lines emitted meanwhile), '
          'held_keys} and, with screenshot: true, a PNG of the level viewport (brought to the front when a sub-editor tab '
          'hides it). The game stays paused (resume_pie).',
      inputSchema: McpSchema.object({
        'frames': McpSchema.integer('Frames to advance, 1..$kMcpMaxAdvanceFrames.'),
        'dt': McpSchema.number('Seconds per frame (default 1/60, at most 0.1).'),
        'screenshot': McpSchema.boolean('Return a viewport PNG too.'),
        'actors': McpSchema.boolean('Return the runtime actors too (pie_get_actors).'),
      }, required: ['frames']),
      handler: (args) async {
        final frames = args.integer('frames');
        if (frames < 1 || frames > kMcpMaxAdvanceFrames) {
          throw const JsonRpcException(JsonRpcErrorCode.invalidParams, 'frames must be 1..$kMcpMaxAdvanceFrames');
        }
        final dt = args.number('dt', fallback: 1 / 60);
        if (dt <= 0 || dt > 0.1) throw const JsonRpcException(JsonRpcErrorCode.invalidParams, 'dt must be in (0, 0.1] seconds');
        final refusal = refuse();
        if (refusal != null) return refusal;
        final logFrom = vm.logs.length;
        play.pauseForStepping();
        play.step(frames, dt);
        vm.logger.log('PIE advanced $frames frames (${(dt * 1000).toStringAsFixed(1)} ms each)', level: 'info', source: 'PIE');
        vm.notifyListeners();
        return report(args, logFrom, {'frames': frames, 'dt': dt});
      },
    ),
    McpTool(
      name: 'pie_play_for',
      risk: McpToolRisk.editorState,
      groups: pie,
      idempotent: false,
      title: 'Play for a while',
      description: 'Resumes the game, lets the viewport run it for ms of wall-clock time (≤ $kMcpMaxPlayForMs), and pauses '
          'it again (unless pause_after: false). Keys held with pie_key down stay held. Returns the same shape as '
          'pie_advance (player_location, actors, log, screenshot).',
      inputSchema: McpSchema.object({
        'ms': McpSchema.integer('Milliseconds to play, 1..$kMcpMaxPlayForMs.'),
        'screenshot': McpSchema.boolean('Return a viewport PNG too.'),
        'actors': McpSchema.boolean('Return the runtime actors too.'),
        'pause_after': McpSchema.boolean('Pause when the time is up (default true).'),
      }, required: ['ms']),
      handler: (args) async {
        final ms = args.integer('ms');
        if (ms < 1 || ms > kMcpMaxPlayForMs) {
          throw const JsonRpcException(JsonRpcErrorCode.invalidParams, 'ms must be 1..$kMcpMaxPlayForMs');
        }
        final refusal = refuse();
        if (refusal != null) return refusal;
        final logFrom = vm.logs.length;
        play.resumeAfterStepping(true);
        await Future<void>.delayed(Duration(milliseconds: ms));
        if (!controller.isPlaying) {
          return McpToolResult.error('Play stopped while it was playing (pie_status, read_output_log).');
        }
        if (args.boolean('pause_after', fallback: true)) play.pauseForStepping();
        return report(args, logFrom, {'played_ms': ms});
      },
    ),
    McpTool(
      name: 'pie_get_actors',
      risk: McpToolRisk.readOnly,
      groups: pie,
      title: 'Runtime actors',
      description: 'The actors of the running game\'s level: {id (the editor actor id, null for spawned ones), class '
          '(the Blueprint class or the native class), native_class, name, location (cm, Z up), rotation '
          '($kMcpRotationConvention), velocity (cm/s, characters), is_possessed_pawn}.',
      inputSchema: McpSchema.object({
        'ids': McpSchema.stringArray('Only these editor actor ids.'),
        'class_contains': McpSchema.string('Only classes containing this (case-insensitive).'),
        'limit': McpSchema.integer('At most this many (default 100).'),
      }),
      handler: (args) {
        final refusal = refuse();
        if (refusal != null) return refusal;
        final list = actors(
          ids: args.has('ids') ? args.stringList('ids') : null,
          classContains: args.optionalString('class_contains'),
          limit: args.integer('limit', fallback: 100),
        );
        return McpToolResult.json({'actors': list, 'count': list.length, 'player_location': playerLocation()});
      },
    ),
  ]);
}

int _nextPointer = 7000;

String _jsonLine(Map<String, Object?> data) {
  final location = data['player_location'];
  final shot = data['screenshot'];
  return 'Player at ${location ?? 'n/a'} cm; ${data['frames'] ?? data['played_ms']} '
      '${data.containsKey('frames') ? 'frames advanced' : 'ms played'}${shot is Map ? '; ${shot['width']}×${shot['height']} PNG of the viewport' : ''}.';
}
