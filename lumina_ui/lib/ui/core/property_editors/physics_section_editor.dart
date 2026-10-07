import 'package:lumina/lumina.dart' show LuminaMeshPhysics, LuminaPhysicalMaterial;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/property_editors/scrub_numeric_field.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';

/// The editor's reading and writing of a component's `physics` JSON:
/// `{simulate, massKg, overrideMass, centerOfMassOffset,
/// linearDamping, angularDamping, enableGravity, friction, restitution,
/// locks: {position: [x, y, z], rotation: [x, y, z]}}`, vectors and lock axes
/// in authoring space (cm, Z up). `meshPhysics` carries the static mesh's
/// values the component inherits, baked for the generated game.
abstract final class PhysicsJson {
  /// The component property the JSON lives under.
  static const String key = 'physics';

  static const double defaultLinearDamping = 0.01;
  static const double defaultAngularDamping = 0.0;

  /// A deep copy of [props]' physics map (empty when it has none).
  static Map<String, dynamic> of(Map<String, dynamic> props) {
    final p = props[key];
    return p is Map ? _copy(p) : <String, dynamic>{};
  }

  static Map<String, dynamic> _copy(Map m) => {
        for (final e in m.entries) '${e.key}': e.value is Map ? _copy(e.value as Map) : (e.value is List ? List.of(e.value as List) : e.value),
      };

  static bool simulate(Map<String, dynamic> json) => json['simulate'] == true;
  static bool overrideMass(Map<String, dynamic> json) => json['overrideMass'] == true;
  static bool enableGravity(Map<String, dynamic> json) => json['enableGravity'] is bool ? json['enableGravity'] as bool : true;
  static bool overridesCenterOfMass(Map<String, dynamic> json) => json['centerOfMassOffset'] is List;

  static double number(Map<String, dynamic> json, String k, double fallback) =>
      json[k] is num ? (json[k] as num).toDouble() : fallback;

  static double friction(Map<String, dynamic> json) => number(json, 'friction', LuminaPhysicalMaterial.defaultFriction);
  static double restitution(Map<String, dynamic> json) => number(json, 'restitution', LuminaPhysicalMaterial.defaultRestitution);
  static double linearDamping(Map<String, dynamic> json) => number(json, 'linearDamping', defaultLinearDamping);
  static double angularDamping(Map<String, dynamic> json) => number(json, 'angularDamping', defaultAngularDamping);

  /// The authored centre-of-mass offset, else [inherited]'s, else zero.
  static List<double> centerOfMass(Map<String, dynamic> json, LuminaMeshPhysics? inherited) {
    final v = json['centerOfMassOffset'];
    if (v is List && v.length >= 3) return [for (final e in v.take(3)) (e as num).toDouble()];
    return List.of(inherited?.centerOfMassOffset ?? const [0.0, 0.0, 0.0]);
  }

  /// Lock [kind] (`position` / `rotation`) on authoring [axis] 0–2.
  static bool lock(Map<String, dynamic> json, String kind, int axis) {
    final locks = json['locks'];
    final v = locks is Map ? locks[kind] : null;
    return v is List && v.length > axis && v[axis] == true;
  }

  /// [json] with [k] set to [value] (null removes it).
  static Map<String, dynamic> withValue(Map<String, dynamic> json, String k, Object? value) {
    final out = _copy(json);
    if (value == null) {
      out.remove(k);
    } else {
      out[k] = value;
    }
    return out;
  }

  static Map<String, dynamic> withLock(Map<String, dynamic> json, String kind, int axis, bool locked) {
    final out = _copy(json);
    final locks = out['locks'] is Map ? out['locks'] as Map<String, dynamic> : <String, dynamic>{};
    for (final k in const ['position', 'rotation']) {
      final v = locks[k];
      locks[k] = [for (var i = 0; i < 3; i++) v is List && v.length > i && v[i] == true];
    }
    (locks[kind] as List)[axis] = locked;
    out['locks'] = locks;
    return out;
  }

  /// The mass the body gets: the override, the mesh's, else [computedMassKg].
  static double effectiveMass(Map<String, dynamic> json, LuminaMeshPhysics? inherited, double computedMassKg) {
    if (overrideMass(json) && number(json, 'massKg', 0) > 0) return number(json, 'massKg', 0);
    return inherited?.massKg ?? computedMassKg;
  }
}

/// The Details **Physics** section, shared by the Blueprint editor's component
/// Details and the level Details of a placed Blueprint's components:
/// Simulate Physics, Mass (kg) — greyed with the inherited value until Override
/// Mass — Center of Mass, Linear / Angular Damping, Enable Gravity, Friction,
/// Restitution and the position / rotation locks.
///
/// Stateless over [value] (the component's physics JSON, possibly empty);
/// every edit hands [onChanged] the whole new JSON, one undo step for the
/// host. [inherited] is the static mesh's physics ([inheritedFrom] names it);
/// [computedMassKg] is the density × volume mass used without either.
class PhysicsSectionEditor extends StatelessWidget {
  final Map<String, dynamic> value;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final String keyPrefix;
  final LuminaMeshPhysics? inherited;
  final String? inheritedFrom;
  final double computedMassKg;

  const PhysicsSectionEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.keyPrefix = 'physics',
    this.inherited,
    this.inheritedFrom,
    this.computedMassKg = 0.0,
  });

  static const List<String> _axes = ['X', 'Y', 'Z'];

  @override
  Widget build(BuildContext context) {
    final simulate = PhysicsJson.simulate(value);
    final override = PhysicsJson.overrideMass(value);
    final mass = PhysicsJson.effectiveMass(value, inherited, computedMassKg);
    final com = PhysicsJson.centerOfMass(value, inherited);
    final comOverride = PhysicsJson.overridesCenterOfMass(value);
    const label = TextStyle(fontSize: 10, color: EditorColors.foreground);
    const muted = TextStyle(fontSize: 9, color: EditorColors.mutedForeground);

    Widget row(String name, Widget editor, {bool dynamicField = true, bool enabled = true}) {
      final dim = (dynamicField && !simulate) || !enabled;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Opacity(
          opacity: dim ? 0.5 : 1.0,
          child: Row(children: [
            SizedBox(width: 118, child: Text(name, style: label)),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: enabled ? editor : IgnorePointer(child: editor),
              ),
            ),
          ]),
        ),
      );
    }

    Widget slider(String k, double v, double def, double min, double max,
            {double? hardMin, double? hardMax, String? unit, int? digits, void Function(double v)? commit}) =>
        SliderField(
          key: ValueKey('${keyPrefix}_$k'),
          value: v,
          defaultValue: def,
          min: min,
          max: max,
          hardMin: hardMin,
          hardMax: hardMax,
          unit: unit,
          fractionDigits: digits,
          onChanged: (_) {},
          onCommit: commit ?? (x) => onChanged(PhysicsJson.withValue(value, k, x)),
          onReset: () => onChanged(PhysicsJson.withValue(value, k, null)),
        );

    Widget check(String k, bool v, ValueChanged<bool> set) => Checkbox(
          key: ValueKey('${keyPrefix}_$k'),
          state: v ? CheckboxState.checked : CheckboxState.unchecked,
          onChanged: (s) => set(s == CheckboxState.checked),
        );

    Widget locks(String kind) => Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 3; i++) ...[
            check('lock_${kind}_${_axes[i].toLowerCase()}', PhysicsJson.lock(value, kind, i),
                (v) => onChanged(PhysicsJson.withLock(value, kind, i, v))),
            Padding(padding: const EdgeInsets.only(left: 3, right: 10), child: Text(_axes[i], style: muted)),
          ],
        ]);

    final hint = override
        ? 'Overrides the inherited mass'
        : (inherited?.massKg != null
            ? 'Inherited from ${inheritedFrom ?? 'the static mesh'}'
            : 'Computed from the shape’s volume × density');

    return Container(
      key: ValueKey('${keyPrefix}_section'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: EditorColors.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: EditorColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('PHYSICS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
          const SizedBox(height: 8),
          row(
            'Simulate Physics',
            Switch(
              key: ValueKey('${keyPrefix}_simulate'),
              value: simulate,
              onChanged: (v) => onChanged(PhysicsJson.withValue(value, 'simulate', v)),
            ),
            dynamicField: false,
          ),
          row(
            'Override Mass',
            check('override_mass', override, (v) {
              var next = PhysicsJson.withValue(value, 'overrideMass', v);
              // Start the override from the mass shown.
              if (v && PhysicsJson.number(value, 'massKg', 0) <= 0) next = PhysicsJson.withValue(next, 'massKg', mass);
              onChanged(next);
            }),
          ),
          row(
            'Mass (kg)',
            slider('mass', mass, inherited?.massKg ?? computedMassKg, 0, 1000,
                hardMin: 0.001, hardMax: double.infinity, unit: 'kg', digits: 1,
                commit: (v) => onChanged(PhysicsJson.withValue(PhysicsJson.withValue(value, 'overrideMass', true), 'massKg', v))),
            enabled: override,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 118, bottom: 3),
            child: Text(hint, key: ValueKey('${keyPrefix}_mass_hint'), style: muted),
          ),
          row(
            'Override Center of Mass',
            check('override_com', comOverride,
                (v) => onChanged(PhysicsJson.withValue(value, 'centerOfMassOffset', v ? com : null))),
          ),
          row(
            'Center of Mass',
            Row(children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ScrubNumericField(
                      key: ValueKey('${keyPrefix}_com_${_axes[i].toLowerCase()}'),
                      value: com[i],
                      defaultValue: inherited?.centerOfMassOffset[i] ?? 0.0,
                      label: _axes[i],
                      unit: 'cm',
                      fractionDigits: 1,
                      onChanged: (_) {},
                      onCommit: (x) => onChanged(PhysicsJson.withValue(value, 'centerOfMassOffset', [...com]..[i] = x)),
                      onReset: () => onChanged(PhysicsJson.withValue(value, 'centerOfMassOffset', null)),
                    ),
                  ),
                ),
            ]),
            enabled: comOverride,
          ),
          row('Linear Damping', slider('linearDamping', PhysicsJson.linearDamping(value), PhysicsJson.defaultLinearDamping, 0, 10,
              hardMin: 0, hardMax: double.infinity, digits: 3)),
          row('Angular Damping', slider('angularDamping', PhysicsJson.angularDamping(value), PhysicsJson.defaultAngularDamping, 0, 10,
              hardMin: 0, hardMax: double.infinity, digits: 3)),
          row(
            'Enable Gravity',
            Switch(
              key: ValueKey('${keyPrefix}_gravity'),
              value: PhysicsJson.enableGravity(value),
              onChanged: (v) => onChanged(PhysicsJson.withValue(value, 'enableGravity', v)),
            ),
          ),
          row('Friction', slider('friction', PhysicsJson.friction(value), LuminaPhysicalMaterial.defaultFriction, 0, 2,
              hardMin: 0, hardMax: double.infinity)),
          row('Restitution', slider('restitution', PhysicsJson.restitution(value), LuminaPhysicalMaterial.defaultRestitution, 0, 1,
              hardMin: 0, hardMax: 1)),
          row('Lock Position', locks('position')),
          row('Lock Rotation', locks('rotation')),
          if (!simulate) ...[
            const SizedBox(height: 4),
            const Text('Turn on Simulate Physics to make it fall, tumble and be pushed in Play.', style: muted),
          ],
        ],
      ),
    );
  }
}
