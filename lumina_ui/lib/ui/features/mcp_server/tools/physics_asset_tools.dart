import 'dart:math' as math;

import 'package:lumina/lumina.dart' show AssetType;

import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/physics_asset_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/physics_asset_editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_editor_sessions.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';

/// The bones of [names] closest to [wanted] by edit distance (at most
/// [count]), for a tool error that names what the agent probably meant.
List<String> mcpNearestNames(String wanted, Iterable<String> names, {int count = 3}) {
  int distance(String a, String b) {
    a = a.toLowerCase();
    b = b.toLowerCase();
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        cur[j] = math.min(math.min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1));
      }
      prev = cur;
    }
    return prev[b.length];
  }

  final ranked = names.toList()..sort((a, b) => distance(wanted, a).compareTo(distance(wanted, b)));
  return ranked.take(count).toList();
}

/// The Physics Asset editor as MCP tools: bind a skeletal
/// mesh, add / replace / remove bodies auto-sized to their bones,
/// body primitive and physics properties, constraints and their angular
/// limits, collision disables, the narrow-phase overlap validation, Save.
/// Bodies are centimetres. The editor keeps no undo stack.
void registerPhysicsAssetTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions) {
  const groups = {McpToolGroups.physicsAsset, McpToolGroups.assetEditors};
  const noUndo = 'Not undoable (the Physics Asset editor keeps no undo stack); close the tab without saving to discard.';
  final shapes = [for (final s in PhysicsShapeType.values) s.name];
  final modes = [for (final m in PhysicsAngularMode.values) m.name];
  final assetArg = McpSchema.string('The physics asset (list_assets type "physicsAsset"): project-relative path or unique file name.');
  final boneArg = McpSchema.string('A bone of the bound skeletal mesh (get_physics_asset bones).');

  Future<PhysicsAssetEditorViewModel> editorFor(McpArgs args) =>
      sessions.physicsAsset(sessions.resolveAsset(args.string('asset'), type: AssetType.physicsAsset));

  Map<String, Object?> bodyJson(PhysicsBody b) => {
        'bone': b.boneName,
        'name': b.name,
        'shape': b.shape.name,
        'radius_cm': b.radius,
        'half_height_cm': b.halfHeight,
        'extent_cm': b.halfExtents,
        'offset_location_cm': b.offsetLocation,
        'offset_rotation_deg': b.offsetRotationDeg,
        'mass_kg': b.massKg,
        'linear_damping': b.linearDamping,
        'angular_damping': b.angularDamping,
        'physics_material': b.physicsMaterial,
      };

  Map<String, Object?> constraintJson(PhysicsConstraint c) => {
        'name': c.name,
        'bone_a': c.bodyA,
        'bone_b': c.bodyB,
        'mode': c.angularMode.name,
        'swing1_deg': c.swing1Deg,
        'swing2_deg': c.swing2Deg,
        'twist_deg': c.twistDeg,
      };

  List<Map<String, Object?>> overlapsJson(List<PhysicsOverlapResult> results) => [
        for (final r in results)
          {
            'body_a': r.bodyA,
            'body_b': r.bodyB,
            'bone_a': r.boneA,
            'bone_b': r.boneB,
            'colliding': r.isColliding,
            'penetration_cm': r.penetrationDepth,
            'disabled': r.disabled,
          },
      ];

  Map<String, Object?> docJson(PhysicsAssetEditorViewModel e, String asset) => {
        'asset': asset,
        'skeletal_mesh': e.skeletalMeshPath == null ? null : sessions.projectRelative(e.skeletalMeshPath!),
        'link_error': e.skeletalMeshPath == null ? e.linkError : (e.hasSkeletalMesh ? null : e.linkError),
        'bones': [for (final b in e.allBones) {'name': b.name, 'parent': e.parentBoneOf(b.name)}],
        'bodies': [for (final b in e.document.bodies) bodyJson(b)],
        'constraints': [for (final c in e.document.constraints) constraintJson(c)],
        'disabled_collision_pairs': e.document.disabledCollisionPairs,
        'last_validation': e.hasValidated ? overlapsJson(e.lastValidation) : null,
        'errors': e.validationErrors,
        'last_error': e.lastError,
        'is_dirty': e.isDirty,
      };

  McpToolResult ok(PhysicsAssetEditorViewModel e, McpArgs args) => McpToolResult.json(docJson(e, args.string('asset')));

  /// [bone] when the bound mesh has it, else a tool error naming the nearest.
  String boneOf(PhysicsAssetEditorViewModel e, String bone) {
    if (!e.hasSkeletalMesh) {
      throw const JsonRpcException(JsonRpcErrorCode.invalidParams,
          'No skeletal mesh is bound to this physics asset: call bind_physics_skeletal_mesh first.');
    }
    if (e.allBoneNames.contains(bone)) return bone;
    throw JsonRpcException(JsonRpcErrorCode.invalidParams,
        'No bone "$bone" in ${sessions.projectRelative(e.skeletalMeshPath!)}. Nearest: ${mcpNearestNames(bone, e.allBoneNames).join(', ')}.');
  }

  /// [bone] when it carries a body, else a tool error naming the bodies.
  String bodyOf(PhysicsAssetEditorViewModel e, String bone) {
    boneOf(e, bone);
    if (e.document.bodyForBone(bone) != null) return bone;
    final bodies = [for (final b in e.document.bodies) b.boneName];
    throw JsonRpcException(JsonRpcErrorCode.invalidParams,
        '"$bone" carries no body. Bodies: ${bodies.isEmpty ? 'none (add_physics_body first)' : mcpNearestNames(bone, bodies, count: bodies.length).join(', ')}.');
  }

  List<double>? vec(McpArgs args, String key) => args.optionalVector3(key);

  registry.registerAll([
    McpTool(
      name: 'get_physics_asset',
      risk: McpToolRisk.readOnly,
      groups: groups,
      title: 'Get physics asset',
      description: 'The Physics Asset editor\'s document (opens its tab): the bound skeletal mesh and its link error, '
          'bones with their parents, bodies (shape, sizes and offsets in cm, mass, damping, physics material), '
          'constraints (angular mode, swing / twist limits in degrees), disabled collision pairs, the last overlap '
          'validation, blocking errors, unsaved changes.',
      inputSchema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      handler: (args) async => ok(await editorFor(args), args),
    ),
    McpTool(
      name: 'bind_physics_skeletal_mesh',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Bind skeletal mesh',
      description: 'The toolbar\'s Skeletal Mesh picker: binds (or rebinds) the mesh whose bones the bodies follow. '
          '$noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'mesh': McpSchema.string('The skeletal mesh asset (project-relative path or unique file name).'),
      }, required: ['asset', 'mesh']),
      handler: (args) async {
        final mesh = sessions.resolveAsset(args.string('mesh'));
        final e = await editorFor(args);
        final path = mesh.lmasPath;
        if (path == null) return McpToolResult.error('${mesh.relativePath} has no .lmas on disk.');
        if (!await e.bindSkeletalMesh(path, assetId: mesh.assetId)) {
          return McpToolResult.error('${mesh.relativePath} could not be bound: ${e.linkError ?? e.lastError ?? 'not a skeletal mesh'}.');
        }
        return ok(e, args);
      },
    ),
    McpTool(
      name: 'add_physics_body',
      risk: McpToolRisk.mutating,
      groups: groups,
      title: 'Add physics body',
      description: 'Add Body on a bone: a ${shapes.join(' / ')} auto-sized to the bone\'s segment and skin '
          '(its axis along the bone). A bone that already has a body is refused unless replace: true (Replace Body: '
          'the new shape keeps the sizing). $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'bone': boneArg,
        'shape': McpSchema.string('The body primitive.', enumValues: shapes),
        'replace': McpSchema.boolean('Replace the bone\'s existing body\'s shape.'),
      }, required: ['asset', 'bone', 'shape']),
      handler: (args) async {
        final e = await editorFor(args);
        final bone = boneOf(e, args.string('bone'));
        final shape = PhysicsShapeType.values.byName(args.string('shape'));
        if (args.boolean('replace')) {
          e.replaceBody(bone, shape);
        } else if (e.document.bodyForBone(bone) != null) {
          return McpToolResult.error('$bone already has a body; pass replace: true to change its shape.');
        } else if (!e.addBody(bone, shape)) {
          return McpToolResult.error(e.lastError ?? 'Could not add a body to $bone.');
        }
        return ok(e, args);
      },
    ),
    McpTool(
      name: 'set_physics_body',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set physics body',
      description: 'A body\'s Details: radius_cm, half_height_cm, extent_cm [x, y, z] (box half extents), '
          'offset_location_cm and offset_rotation_deg [x, y, z] relative to the bone, mass_kg, linear_damping, '
          'angular_damping, physics_material. Lengths have a small positive floor, mass and damping ≥ 0. $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'bone': boneArg,
        'radius_cm': McpSchema.number('Sphere / capsule radius in cm.'),
        'half_height_cm': McpSchema.number('Capsule half height in cm.'),
        'extent_cm': McpSchema.vector3('Box half extents [x, y, z] in cm.'),
        'offset_location_cm': McpSchema.vector3('Offset from the bone [x, y, z] in cm.'),
        'offset_rotation_deg': McpSchema.vector3('Offset rotation [x, y, z] in degrees.'),
        'mass_kg': McpSchema.number('Mass in kg.'),
        'linear_damping': McpSchema.number('Linear damping.'),
        'angular_damping': McpSchema.number('Angular damping.'),
        'physics_material': McpSchema.string('Physics material name.'),
      }, required: ['asset', 'bone']),
      handler: (args) async {
        final e = await editorFor(args);
        final bone = bodyOf(e, args.string('bone'));
        final radius = args.optionalNumber('radius_cm');
        if (radius != null) e.setBodyRadius(bone, radius);
        final half = args.optionalNumber('half_height_cm');
        if (half != null) e.setBodyHalfHeight(bone, half);
        final extent = vec(args, 'extent_cm');
        for (var i = 0; extent != null && i < 3; i++) {
          e.setBodyExtent(bone, i, extent[i]);
        }
        final location = vec(args, 'offset_location_cm');
        for (var i = 0; location != null && i < 3; i++) {
          e.setBodyOffsetLocation(bone, i, location[i]);
        }
        final rotation = vec(args, 'offset_rotation_deg');
        for (var i = 0; rotation != null && i < 3; i++) {
          e.setBodyOffsetRotation(bone, i, rotation[i]);
        }
        final mass = args.optionalNumber('mass_kg');
        if (mass != null) e.setBodyMass(bone, mass);
        final linear = args.optionalNumber('linear_damping');
        if (linear != null) e.setBodyLinearDamping(bone, linear);
        final angular = args.optionalNumber('angular_damping');
        if (angular != null) e.setBodyAngularDamping(bone, angular);
        final material = args.optionalString('physics_material');
        if (material != null) e.setBodyPhysicsMaterial(bone, material);
        e.selectBody(bone);
        return ok(e, args);
      },
    ),
    McpTool(
      name: 'remove_physics_body',
      risk: McpToolRisk.destructive,
      groups: groups,
      title: 'Remove physics body',
      description: 'Deletes a bone\'s body and every constraint and disabled pair that referenced it. $noUndo',
      inputSchema: McpSchema.object({'asset': assetArg, 'bone': boneArg}, required: ['asset', 'bone']),
      handler: (args) async {
        final e = await editorFor(args);
        e.removeBody(bodyOf(e, args.string('bone')));
        return ok(e, args);
      },
    ),
    McpTool(
      name: 'add_physics_constraint',
      risk: McpToolRisk.mutating,
      groups: groups,
      title: 'Add physics constraint',
      description: 'Joins the bodies on bone_a (parent) and bone_b; both must carry a body. The constraint is named '
          '"<bone_b>_Constraint" and starts limited (45° / 45° swing, 30° twist). $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'bone_a': McpSchema.string('The parent body\'s bone.'),
        'bone_b': McpSchema.string('The child body\'s bone.'),
      }, required: ['asset', 'bone_a', 'bone_b']),
      handler: (args) async {
        final e = await editorFor(args);
        final a = bodyOf(e, args.string('bone_a'));
        final b = bodyOf(e, args.string('bone_b'));
        if (!e.addConstraint(a, b)) return McpToolResult.error(e.lastError ?? 'Could not constrain $a and $b.');
        return ok(e, args);
      },
    ),
    McpTool(
      name: 'set_physics_constraint',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set physics constraint',
      description: 'A constraint\'s angular mode (${modes.join(' / ')}) and swing1 / swing2 / twist limits in '
          'degrees, clamped to −180…180 as the Details fields clamp. $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'name': McpSchema.string('The constraint (get_physics_asset constraints name).'),
        'mode': McpSchema.string('Angular mode.', enumValues: modes),
        'swing1_deg': McpSchema.number('Swing 1 limit in degrees.'),
        'swing2_deg': McpSchema.number('Swing 2 limit in degrees.'),
        'twist_deg': McpSchema.number('Twist limit in degrees.'),
      }, required: ['asset', 'name']),
      handler: (args) async {
        final e = await editorFor(args);
        final name = args.string('name');
        if (e.document.constraintByName(name) == null) {
          final names = [for (final c in e.document.constraints) c.name];
          return McpToolResult.error('No constraint "$name". Constraints: ${names.isEmpty ? 'none' : names.join(', ')}.');
        }
        final mode = args.optionalString('mode');
        if (mode != null) e.setConstraintMode(name, PhysicsAngularMode.values.byName(mode));
        final s1 = args.optionalNumber('swing1_deg');
        if (s1 != null) e.setConstraintSwing1(name, s1);
        final s2 = args.optionalNumber('swing2_deg');
        if (s2 != null) e.setConstraintSwing2(name, s2);
        final twist = args.optionalNumber('twist_deg');
        if (twist != null) e.setConstraintTwist(name, twist);
        e.selectConstraint(name);
        return ok(e, args);
      },
    ),
    McpTool(
      name: 'remove_physics_constraint',
      risk: McpToolRisk.destructive,
      groups: groups,
      title: 'Remove physics constraint',
      description: 'Deletes a constraint. $noUndo',
      inputSchema: McpSchema.object({'asset': assetArg, 'name': McpSchema.string('The constraint name.')}, required: ['asset', 'name']),
      handler: (args) async {
        final e = await editorFor(args);
        final name = args.string('name');
        if (!e.removeConstraint(name)) {
          return McpToolResult.error('No constraint "$name". Constraints: ${e.document.constraints.map((c) => c.name).join(', ')}.');
        }
        return ok(e, args);
      },
    ),
    McpTool(
      name: 'set_physics_collision_pair',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set collision between bodies',
      description: 'Enables or disables collision between the bodies on two bones (the body context menu\'s '
          'Collision → Enable / Disable). $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'bone_a': McpSchema.string('One body\'s bone.'),
        'bone_b': McpSchema.string('The other body\'s bone.'),
        'enabled': McpSchema.boolean('Whether the two bodies collide.'),
      }, required: ['asset', 'bone_a', 'bone_b', 'enabled']),
      handler: (args) async {
        final e = await editorFor(args);
        final a = bodyOf(e, args.string('bone_a'));
        final b = bodyOf(e, args.string('bone_b'));
        if (a == b) return McpToolResult.error('A body always ignores itself; name two different bones.');
        if (args.boolean('enabled')) {
          e.enableCollisionBetween(a, b);
        } else {
          e.disableCollisionBetween(a, b);
        }
        return ok(e, args);
      },
    ),
    McpTool(
      name: 'validate_physics_asset',
      risk: McpToolRisk.readOnly,
      groups: groups,
      title: 'Validate physics asset',
      description: 'The toolbar\'s Validate: runs the real narrow phase over every body pair in bind pose and lists '
          'the overlapping pairs (penetration in cm) and the disabled pairs it skipped, plus the document errors '
          'that block Save.',
      inputSchema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        final results = e.validateOverlaps();
        return McpToolResult.json({'overlaps': overlapsJson(results), 'errors': e.validationErrors});
      },
    ),
    McpTool(
      name: 'save_physics_asset',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Save physics asset',
      description: 'The tab\'s Save: writes the bodies (cm, schema v2), constraints, disabled pairs and the skeletal '
          'mesh reference. Refused while the document has blocking errors (validate_physics_asset errors).',
      inputSchema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        if (!await e.save()) return McpToolResult.error('Save refused: ${e.lastError ?? 'see the Output Log'}.');
        return ok(e, args);
      },
    ),
  ]);
}
