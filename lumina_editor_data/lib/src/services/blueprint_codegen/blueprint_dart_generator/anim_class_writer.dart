part of '../blueprint_dart_generator.dart';

/// An Animation Blueprint as a `LuminaAnimBlueprintInstance` subclass.
/// The shared base does the state machine and poses; the
/// class supplies the update graph and the rules, compiled as Blueprint
/// graphs whose `self` is the owning pawn and whose variables live in the
/// instance's `variables` map, exactly where the VM keeps them.
class _AnimClassWriter {
  final LuminaAnimBlueprintDocument doc;
  final String className;
  final String? assetPath;
  final Map<String, LuminaBlendSpaceDocument> blendSpaces;
  final Map<String, LuminaPoseSearchDatabaseDocument> poseDatabases;
  final List<LuminaBlueprintDiagnostic> issues;
  final Map<String, String> functionImports;
  late final LuminaBlueprintTypeContext context = LuminaBlueprintTypeContext(variables: doc.variables);
  final _Counter _counter = _Counter();
  final Set<String> _libraries = {};
  var failed = false;

  _AnimClassWriter(
      this.doc, this.className, this.assetPath, this.blendSpaces, this.poseDatabases, this.issues, this.functionImports);

  void _error(String message, {String? node}) {
    failed = true;
    issues.add(LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.error, message, nodeId: node));
  }

  _GraphCompiler _compiler(LuminaBlueprintGraph graph) => _GraphCompiler(
        graph,
        context,
        _counter,
        self: 'pawnOwner',
        readVariable: (name) => 'variables[${_str(name)}] as ${_dartType(context.variable(name)?.type ?? LuminaPinType.float)}',
        writeVariable: (name, value) => 'variables[${_str(name)}] = $value;',
        error: _error,
        libraries: _libraries,
      );

  String write(Map<String, String> userRegions) {
    final machine = doc.stateMachine!;
    final update = _compiler(doc.eventGraph);
    final updateCalls = <String>[];
    final methods = <String>[];
    for (final node in doc.eventGraph.nodes) {
      if (node.registryId != LuminaBlueprintNodeLibrary.updateAnimation) continue;
      final name = '_on${_cap(_id(node.id))}';
      final frame = _Frame(node.id, _id(node.id), const {'delta_time_x': 'deltaTimeX'}, 'double deltaTimeX', 'deltaTimeX');
      updateCalls.add('$name(deltaTimeX);');
      methods.add(update.eventMethod(name, frame, node, 'exec_out', node.title));
    }
    final rules = <String, String>{};
    for (final t in machine.transitions) {
      final name = '_rule${_cap(_var(t.id))}';
      rules[t.id] = name;
      final result = t.resultNode!;
      final frame = _Frame(result.id, _id(t.id), const {}, '', '', traceId: t.id);
      methods.add(_compiler(t.rule).valueMethod(name, frame, result, 'can_enter', 'Can ${t.from} → ${t.to} (transition ${t.id}) be taken?'));
    }

    final b = StringBuffer();
    b.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).');
    b.writeln('// Animation Blueprint ${assetPath ?? className}, compiled by Lumina.');
    b.writeln(_ignoreForFile);
    b.writeln();
    final databasePaths = {
      for (final s in machine.states)
        if (s.pose.kind == LuminaAnimPoseKind.motionMatching && s.pose.database != null) s.pose.database!,
    };
    if (databasePaths.isNotEmpty) b.writeln("import 'dart:convert';");
    b.writeln("import 'package:lumina/lumina_runtime.dart';");
    b.writeln("import 'package:vector_math/vector_math_64.dart';");
    _functionImports(b, _libraries, functionImports);
    b.writeln();
    b.writeln('class $className extends LuminaAnimBlueprintInstance {');
    b.writeln('  $className({super.key, required super.mesh})');
    b.writeln('      : super(');
    b.writeln('          stateMachine: _stateMachine,');
    b.writeln('          blendSpaces: _blendSpaces,');
    if (databasePaths.isNotEmpty) b.writeln('          poseDatabases: _poseDatabases,');
    b.writeln('          meshYawOffsetDegrees: ${_double(doc.meshYawOffsetDegrees)},');
    final aim = doc.aimOffset;
    if (aim != null) {
      b.writeln('          aimOffset: const LuminaAnimAimOffset(');
      b.writeln('            bones: [');
      for (final bone in aim.bones) {
        b.writeln('              LuminaAnimAimOffsetBone(${_str(bone.name)}, ${_double(bone.weight)}),');
      }
      b.writeln('            ],');
      b.writeln('            yawVariable: ${_str(aim.yawVariable)},');
      b.writeln('            pitchVariable: ${_str(aim.pitchVariable)},');
      b.writeln('            maxYaw: ${_double(aim.maxYaw)},');
      b.writeln('            maxPitch: ${_double(aim.maxPitch)},');
      b.writeln('            interpSpeed: ${_double(aim.interpSpeed)},');
      b.writeln('          ),');
    }
    b.writeln('          initialVariables: {');
    for (final v in doc.variables) {
      b.writeln('            ${_str(v.name)}: ${_literal(v.type!, v.defaultValue)},');
    }
    b.writeln('          },');
    b.writeln('        );');
    b.writeln();
    b.writeln("  /// Makes the instance for a skeletal mesh whose Anim Class this is.");
    b.writeln('  static LuminaAnimBlueprintInstance create(LuminaAnimatedMeshComponent mesh) => $className(mesh: mesh);');
    b.writeln();
    b.writeln("  /// The AnimGraph's state machine (${machine.name}).");
    b.writeln('  static final LuminaAnimStateMachine _stateMachine = LuminaAnimStateMachine(');
    b.writeln('    name: ${_str(machine.name)},');
    b.writeln('    entryState: ${_str(machine.entryState)},');
    b.writeln('    sampleCrossFade: ${_double(machine.sampleCrossFade)},');
    b.writeln('    states: [');
    for (final s in machine.states) {
      b.writeln('      LuminaAnimState(${_str(s.name)}, ${_pose(s.pose)}, x: ${_double(s.x)}, y: ${_double(s.y)}),');
    }
    b.writeln('    ],');
    b.writeln('    transitions: [');
    for (final t in machine.transitions) {
      b.writeln('      LuminaAnimTransition(id: ${_str(t.id)}, from: ${_str(t.from)}, to: ${_str(t.to)}, '
          'blendDuration: ${_double(t.blendDuration)}, priority: ${t.priority}, '
          'minStateTime: ${_double(t.minStateTime)}, automaticRule: ${t.automaticRule}),');
    }
    b.writeln('    ],');
    b.writeln('  );');
    b.writeln();
    b.writeln('  /// The blend spaces its states play, by asset path.');
    b.writeln('  static final Map<String, LuminaBlendSpaceDocument> _blendSpaces = {');
    for (final path in {for (final s in machine.states) if (s.pose.blendSpace != null) s.pose.blendSpace!}) {
      final space = blendSpaces[path]!;
      b.writeln('    ${_str(path)}: LuminaBlendSpaceDocument(');
      b.writeln('      axes: [${space.axes.map((a) => 'LuminaBlendSpaceAxis(${_str(a.name)}, ${_double(a.min)}, ${_double(a.max)})').join(', ')}],');
      b.writeln('      samples: [');
      for (final sample in space.samples) {
        b.writeln('        LuminaBlendSpaceSample(${_str(sample.clip)}, ${_double(sample.x)}, ${_double(sample.y)}),');
      }
      b.writeln('      ],');
      b.writeln('    ),');
    }
    b.writeln('  };');
    if (databasePaths.isNotEmpty) {
      b.writeln();
      b.writeln('  /// The pose search databases its Motion Matching states play, by asset path.');
      b.writeln('  static final Map<String, LuminaPoseSearchDatabaseDocument> _poseDatabases = {');
      for (final path in databasePaths) {
        final json = jsonEncode(poseDatabases[path]!.toJson());
        b.writeln("    ${_str(path)}: LuminaPoseSearchDatabaseDocument.fromJson(jsonDecode(r'''$json''') as Map<String, dynamic>),");
      }
      b.writeln('  };');
    }
    b.writeln();
    b.writeln('  @override');
    b.writeln('  void updateAnimation(double deltaTimeX) {');
    for (final c in updateCalls) {
      b.writeln('    $c');
    }
    b.writeln('  }');
    b.writeln();
    b.writeln('  @override');
    b.writeln('  bool evaluateRule(LuminaAnimTransition transition) => switch (transition.id) {');
    for (final e in rules.entries) {
      b.writeln('        ${_str(e.key)} => ${e.value}(),');
    }
    b.writeln('        _ => false,');
    b.writeln('      };');
    if (update.stateFields.isNotEmpty) {
      b.writeln();
      for (final f in update.stateFields) {
        b.writeln('  $f');
      }
    }
    for (final m in [...methods, ...update.methods]) {
      b.writeln();
      b.write(m);
    }
    _userRegion(b, userRegions);
    b.writeln('}');
    return b.toString();
  }

  /// A state's pose as the document declares it: a clip with
  /// its loop, root yaw and foot planting, a random clip set, a held pose,
  /// or a blend space.
  static String _pose(LuminaAnimPose p) => switch (p.kind) {
        LuminaAnimPoseKind.clip => p.clips.isNotEmpty
            ? 'LuminaAnimPose.randomClip([${p.clips.map(_str).join(', ')}], rate: ${_double(p.rate)}, loop: ${p.loop}, '
                'rootYawDegrees: ${_double(p.rootYawDegrees)}, plantsFeet: ${p.plantsFeet})'
            : 'LuminaAnimPose.clip(${_str(p.clip!)}, rate: ${_double(p.rate)}, loop: ${p.loop}, '
                'rootYawDegrees: ${_double(p.rootYawDegrees)}, plantsFeet: ${p.plantsFeet})',
        LuminaAnimPoseKind.hold => 'LuminaAnimPose.hold()',
        LuminaAnimPoseKind.motionMatching => 'LuminaAnimPose.motionMatching(${[
            _str(p.database ?? ''),
            'blendTime: ${_double(p.blendTime)}',
            'poseWeight: ${_double(p.poseWeight)}',
            'trajectoryWeight: ${_double(p.trajectoryWeight)}',
            'requiredTags: [${p.requiredTags.map(_str).join(', ')}]',
            'orientToMovement: ${p.orientToMovement}',
            'debugDraw: ${p.debugDraw}',
          ].join(', ')})',
        LuminaAnimPoseKind.blendSpace => 'LuminaAnimPose.blendSpace(${[
            _str(p.blendSpace!),
            'xVariable: ${_str(p.xVariable!)}',
            if (p.yVariable != null) 'yVariable: ${_str(p.yVariable!)}',
            'rate: ${_double(p.rate)}',
            if (p.rateVariable != null) 'rateVariable: ${_str(p.rateVariable!)}',
            'rateReference: ${_double(p.rateReference)}',
            'minRate: ${_double(p.minRate)}',
            'maxRate: ${_double(p.maxRate)}',
            if (p.rateRows) 'rateRows: true',
          ].join(', ')})',
      };
}
