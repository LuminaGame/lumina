import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/widgets.dart';
import 'package:lumina/lumina.dart' show AssetType;

import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_editor_sessions.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_frame_capture.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';

/// The level viewport as MCP tools: a screenshot of the
/// viewport or the whole editor window as MCP image content, and the
/// camera (orbit yaw / pitch / distance / target, ortho modes, view mode,
/// focus, frame), plus `asset_editor_screenshot`: an asset's
/// sub-editor tab (UMG designer, material graph, …) as MCP image content.
void registerViewTools(
  McpToolRegistry registry,
  EditorViewModel vm, {
  required GlobalKey viewportBoundaryKey,
  required GlobalKey editorBoundaryKey,
  required McpEditorSessions sessions,
  required GlobalKey Function(String tabId) subEditorBoundaryKeyFor,
}) {
  Map<String, Object?> camera() => {
        'mode': vm.cameraMode,
        'yaw': vm.cameraYaw,
        'pitch': vm.cameraPitch,
        'distance': vm.cameraDistance,
        'target': [vm.cameraPanX, vm.cameraPanY, vm.cameraPanZ],
        'view_mode': vm.viewportMode,
        'speed_level': vm.cameraSpeedScalar,
      };

  const cameraModes = ['Perspective', 'Top', 'Bottom', 'Front', 'Back', 'Right', 'Left'];
  const viewModes = ['Lit', 'Unlit', 'Wireframe', 'Buffer'];

  registry.registerAll([
    McpTool(
      name: 'viewport_screenshot',
      risk: McpToolRisk.readOnly,
      groups: const {McpToolGroups.view},
      title: 'Viewport screenshot',
      description: 'A PNG of the level viewport (default) or of the whole editor window, as it is on screen right '
          'now (Filament render included), returned as MCP image content plus a text line with its size and the '
          'camera. Frames wider than max_width are scaled down. The level tab must be showing; open sub-editor '
          'tabs hide it (select_tab 0 via open_asset_editor\'s open_tabs, or close them).',
      inputSchema: McpSchema.object({
        'target': McpSchema.string('"viewport" (default) or "editor" for the whole window.', enumValues: ['viewport', 'editor']),
        'max_width': McpSchema.integer('Largest width in pixels; default 1280, at least 64.'),
      }),
      handler: (args) async {
        final target = args.optionalString('target') ?? 'viewport';
        final maxWidth = args.integer('max_width', fallback: 1280);
        if (maxWidth < 64) throw const JsonRpcException(JsonRpcErrorCode.invalidParams, 'max_width must be at least 64');
        if (target == 'viewport' && vm.activeTabIndex != 0) {
          return McpToolResult.error(
            'The level viewport is not shown: tab ${vm.activeTabIndex} ("${vm.currentTab.title}") is active. '
            'Screenshot the "editor" instead, or switch to the level tab first (select_tab).',
          );
        }
        final McpFrame frame;
        try {
          frame = await McpFrameCapture.capture(
            target == 'editor' ? editorBoundaryKey : viewportBoundaryKey,
            maxWidth: maxWidth,
            what: target == 'editor' ? 'editor window' : 'level viewport',
          );
        } on StateError catch (e) {
          return McpToolResult.error(e.message);
        }
        final cam = camera();
        return McpToolResult([
          McpContent.image(frame.png),
          McpContent.text('${frame.width}×${frame.height} PNG of the $target. Camera: ${cam['mode']}, yaw ${cam['yaw']}, '
              'pitch ${cam['pitch']}, distance ${cam['distance']} cm, target ${cam['target']}, ${cam['view_mode']}.'),
        ], structuredContent: {'width': frame.width, 'height': frame.height, 'target': target, 'camera': cam});
      },
    ),
    McpTool(
      name: 'asset_editor_screenshot',
      risk: McpToolRisk.readOnly,
      groups: const {
        McpToolGroups.view, McpToolGroups.umg, McpToolGroups.materialGraph, //
        McpToolGroups.animation, McpToolGroups.sequencer, McpToolGroups.particle, //
        McpToolGroups.landscape, McpToolGroups.staticMesh, McpToolGroups.texture, McpToolGroups.physicsAsset, //
        McpToolGroups.audio, McpToolGroups.blueprintTypes, McpToolGroups.assetEditors,
      },
      title: 'Asset editor screenshot',
      description: 'A PNG of an asset\'s editor tab as it is on screen (the UMG designer or graph, the Material '
          'editor\'s graph, code and preview sphere, the Anim Blueprint, Blend Space, Animation, Skeletal Mesh, '
          'Sequencer and Particle editors with their previews, the Landscape\'s lit terrain, the Static Mesh, Texture, '
          'Physics Asset, Sound, Enumeration and Blueprint Interface editors, …), returned as MCP image content plus a text line with its '
          'size. Opens or activates the asset\'s tab first (as open_asset_editor does) and waits for it to draw. '
          'Frames wider than max_width are scaled down. A level is not an asset editor: use viewport_screenshot.',
      inputSchema: McpSchema.object({
        'asset': McpSchema.string('The asset\'s project-relative path (list_assets), or its file name when unique.'),
        'max_width': McpSchema.integer('Largest width in pixels; default 1280, at least 64.'),
      }, required: ['asset']),
      handler: (args) async {
        final maxWidth = args.integer('max_width', fallback: 1280);
        if (maxWidth < 64) throw const JsonRpcException(JsonRpcErrorCode.invalidParams, 'max_width must be at least 64');
        final asset = sessions.resolveAsset(args.string('asset'));
        if (asset.type == AssetType.level) {
          return McpToolResult.error('${asset.relativePath} is a level, not an asset editor: use viewport_screenshot.');
        }
        vm.openAssetEditorByPath(asset.relativePath);
        final tab = vm.currentTab;
        if (vm.activeTabIndex == 0) return McpToolResult.error('${asset.relativePath} has no editor tab.');
        final key = subEditorBoundaryKeyFor(tab.id);
        // The tab mounts (and a freshly opened editor lays out) over the
        // next frames: wait for its boundary, four seconds at most.
        final binding = SchedulerBinding.instance;
        for (var i = 0; i < 40; i++) {
          final render = key.currentContext?.findRenderObject();
          if (i >= 2 && render is RenderRepaintBoundary && render.attached && !render.debugNeedsPaint) break;
          binding.scheduleFrame();
          await binding.endOfFrame.timeout(const Duration(milliseconds: 100), onTimeout: () {});
        }
        final McpFrame frame;
        try {
          frame = await McpFrameCapture.capture(key, maxWidth: maxWidth, what: '${tab.category} editor');
        } on StateError catch (e) {
          return McpToolResult.error('The asset editor is not shown (${e.message}). The editor window must be open.');
        }
        return McpToolResult([
          McpContent.image(frame.png),
          McpContent.text('${frame.width}×${frame.height} PNG of the ${tab.category} editor for ${asset.relativePath}.'),
        ], structuredContent: {
          'width': frame.width,
          'height': frame.height,
          'asset': asset.relativePath,
          'category': tab.category,
          'tab_id': tab.id,
        });
      },
    ),
    McpTool(
      name: 'select_tab',
      risk: McpToolRisk.editorState,
      groups: const {McpToolGroups.view},
      idempotent: true,
      title: 'Select workspace tab',
      description: 'Shows a workspace tab: 0 is the level (viewport, Outliner, Details), 1… the open sub-editors '
          '(open_asset_editor returns them).',
      inputSchema: McpSchema.object({'index': McpSchema.integer('The tab index; 0 is the level.')}, required: ['index']),
      handler: (args) {
        final index = args.integer('index');
        if (index < 0 || index >= vm.openTabs.length) {
          return McpToolResult.error('No tab $index; open tabs: ${vm.openTabs.asMap().entries.map((e) => '${e.key} "${e.value.title}"').join(', ')}.');
        }
        vm.selectTab(index);
        return McpToolResult.json({'active_tab': index, 'title': vm.currentTab.title, 'category': vm.currentTab.category});
      },
    ),
    McpTool(
      name: 'get_camera',
      risk: McpToolRisk.readOnly,
      groups: const {McpToolGroups.view},
      title: 'Get camera',
      description: 'The level viewport\'s camera: mode (Perspective or an ortho view), orbit yaw and pitch in '
          'degrees, distance in cm from the target, the orbit target [x, y, z] in cm (authoring space), the view '
          'mode (Lit / Unlit / Wireframe / Buffer) and the fly speed level (1–8).',
      inputSchema: McpSchema.object(const {}),
      handler: (args) => McpToolResult.json(camera()),
    ),
    McpTool(
      name: 'set_camera',
      risk: McpToolRisk.editorState,
      groups: const {McpToolGroups.view},
      idempotent: true,
      title: 'Set camera',
      description: 'Moves the level viewport\'s camera: any of yaw, pitch (degrees), distance (cm), target [x, y, z] '
          '(cm), mode (${cameraModes.join(' / ')}), view_mode (${viewModes.join(' / ')}) and the fly speed_level '
          '(1–8, the viewport\'s camera speed control). Not an undo step (the camera is not level content).',
      inputSchema: McpSchema.object({
        'yaw': McpSchema.number('Orbit yaw in degrees.'),
        'pitch': McpSchema.number('Orbit pitch in degrees (−89 … 89).'),
        'distance': McpSchema.number('Distance from the target in cm (> 0).'),
        'target': McpSchema.vector3('The orbit target [x, y, z] in cm.'),
        'mode': McpSchema.string('The camera mode.', enumValues: cameraModes),
        'view_mode': McpSchema.string('The view mode.', enumValues: viewModes),
        'speed_level': McpSchema.integer('The fly speed level, 1 (slowest) … 8 (fastest).'),
      }),
      handler: (args) {
        final speed = args.has('speed_level') ? args.integer('speed_level') : null;
        if (speed != null && (speed < 1 || speed > 8)) return McpToolResult.error('speed_level must be within 1–8.');
        if (speed != null) vm.setCameraSpeed(speed);
        final mode = args.optionalString('mode');
        if (mode != null) vm.setCameraMode(mode);
        final viewMode = args.optionalString('view_mode');
        if (viewMode != null) vm.setViewportMode(viewMode);
        final target = args.optionalVector3('target');
        final distance = args.optionalNumber('distance');
        if (distance != null && distance <= 0) return McpToolResult.error('distance must be positive.');
        final pitch = args.optionalNumber('pitch');
        if (pitch != null && (pitch < -89.9 || pitch > 89.9)) return McpToolResult.error('pitch must be within −89 … 89.');
        if (args.has('yaw') || pitch != null || distance != null || target != null) {
          vm.restoreCameraSnapshot([
            args.optionalNumber('yaw') ?? vm.cameraYaw,
            pitch ?? vm.cameraPitch,
            distance ?? vm.cameraDistance,
            target?[0] ?? vm.cameraPanX,
            target?[1] ?? vm.cameraPanY,
            target?[2] ?? vm.cameraPanZ,
          ]);
        }
        return McpToolResult.json(camera());
      },
    ),
    McpTool(
      name: 'focus_actor',
      risk: McpToolRisk.editorState,
      groups: const {McpToolGroups.view},
      idempotent: true,
      title: 'Focus actor',
      description: 'Points the camera at an actor and frames it (the F key), selecting it.',
      inputSchema: McpSchema.object({'id': McpSchema.string('The actor id (list_actors).')}, required: ['id']),
      handler: (args) {
        final id = args.string('id');
        final actor = vm.actors.where((a) => a.id == id).firstOrNull;
        if (actor == null) throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'No actor with id "$id". Call list_actors.');
        vm.focusCameraOnActor(actor);
        return McpToolResult.json(camera());
      },
    ),
    McpTool(
      name: 'frame_level',
      risk: McpToolRisk.editorState,
      groups: const {McpToolGroups.view},
      idempotent: true,
      title: 'Frame level',
      description: 'Pulls the camera back to hold the whole level.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) {
        vm.frameLevelBounds();
        return McpToolResult.json(camera());
      },
    ),
  ]);
}
