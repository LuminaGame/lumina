import 'package:lumina/lumina.dart'
    show CollisionObjectType, CollisionResponse, LuminaCollisionPreset, LuminaCollisionProfile, luminaParseCollisionObjectType;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// The editor's reading and writing of lumina's collision JSON:
/// `{'preset', 'objectType', 'responses': {'worldStatic': 'block', …},
/// 'generateOverlapEvents', 'collisionEnabled'}` — the keys a collision
/// component carries in a Blueprint document or a placed actor's component
/// properties.
///
/// The rules: picking a preset fills object type and the grid from its
/// table; only **Custom** lets the user edit object type, Collision Enabled
/// and the grid, and an edit made there keeps `preset: custom` even when the
/// grid happens to match a table. Generate Overlap Events is independent of
/// the preset.
abstract final class CollisionJson {
  /// The keys this editor writes.
  static const List<String> keys = ['preset', 'objectType', 'responses', 'generateOverlapEvents', 'collisionEnabled'];

  /// The collision keys of [properties] (anything else dropped).
  static Map<String, dynamic> of(Map<String, dynamic> properties) => {
        for (final k in keys)
          if (properties.containsKey(k)) k: properties[k],
      };

  /// The profile [json] describes, on top of [base] (the component's
  /// built-in setup: a Character's capsule is Pawn, anything else lumina's
  /// default Block All Dynamic).
  static LuminaCollisionProfile profile(Map<String, dynamic> json, {LuminaCollisionProfile? base}) =>
      LuminaCollisionProfile.fromJson(json, base: base ?? LuminaCollisionProfile());

  /// The preset the section shows: a stored `preset` wins (so Custom sticks),
  /// otherwise the table the profile matches.
  static LuminaCollisionPreset preset(Map<String, dynamic> json, {LuminaCollisionProfile? base}) =>
      LuminaCollisionPreset.parse(json['preset'] as String?) ?? profile(json, base: base).preset;

  /// [json] with [preset] chosen: its table, keeping Generate Overlap Events
  /// (Trigger's table turns it on). Custom keeps the current
  /// profile and marks it custom.
  static Map<String, dynamic> withPreset(Map<String, dynamic> json, LuminaCollisionPreset preset,
      {LuminaCollisionProfile? base}) {
    final current = profile(json, base: base);
    final next = preset == LuminaCollisionPreset.custom
        ? current
        : LuminaCollisionProfile.forPreset(preset, generateOverlapEvents: current.generateOverlapEvents);
    return {...next.toJson(), 'preset': preset.name};
  }

  /// [json] with [channel] answered by [response]; the result is Custom.
  static Map<String, dynamic> withResponse(Map<String, dynamic> json, CollisionObjectType channel, CollisionResponse response,
      {LuminaCollisionProfile? base}) {
    final current = profile(json, base: base);
    final grid = Map<CollisionObjectType, CollisionResponse>.from(current.responses)..[channel] = response;
    return {...current.copyWith(responses: grid).toJson(), 'preset': LuminaCollisionPreset.custom.name};
  }

  /// [json] with object type [type]; the result is Custom.
  static Map<String, dynamic> withObjectType(Map<String, dynamic> json, CollisionObjectType type,
          {LuminaCollisionProfile? base}) =>
      {...profile(json, base: base).copyWith(objectType: type).toJson(), 'preset': LuminaCollisionPreset.custom.name};

  /// [json] with Collision Enabled [enabled]; the result is Custom.
  static Map<String, dynamic> withCollisionEnabled(Map<String, dynamic> json, bool enabled,
          {LuminaCollisionProfile? base}) =>
      {...profile(json, base: base).copyWith(collisionEnabled: enabled).toJson(), 'preset': LuminaCollisionPreset.custom.name};

  /// [json] with Generate Overlap Events [value]; the preset stays.
  static Map<String, dynamic> withGenerateOverlapEvents(Map<String, dynamic> json, bool value,
      {LuminaCollisionProfile? base}) {
    final shown = preset(json, base: base);
    return {...profile(json, base: base).copyWith(generateOverlapEvents: value).toJson(), 'preset': shown.name};
  }

  /// The preset's display label.
  static String presetLabel(LuminaCollisionPreset p) => switch (p) {
        LuminaCollisionPreset.noCollision => 'No Collision',
        LuminaCollisionPreset.blockAll => 'Block All',
        LuminaCollisionPreset.overlapAll => 'Overlap All',
        LuminaCollisionPreset.blockAllDynamic => 'Block All Dynamic',
        LuminaCollisionPreset.overlapAllDynamic => 'Overlap All Dynamic',
        LuminaCollisionPreset.pawn => 'Pawn',
        LuminaCollisionPreset.trigger => 'Trigger',
        LuminaCollisionPreset.custom => 'Custom',
      };

  static String channelLabel(CollisionObjectType t) => switch (t) {
        CollisionObjectType.worldStatic => 'World Static',
        CollisionObjectType.worldDynamic => 'World Dynamic',
        CollisionObjectType.pawn => 'Pawn',
      };

  static String responseLabel(CollisionResponse r) => switch (r) {
        CollisionResponse.ignore => 'Ignore',
        CollisionResponse.overlap => 'Overlap',
        CollisionResponse.block => 'Block',
      };

  /// Parses an object type name as the engine does.
  static CollisionObjectType? parseObjectType(String? s) => luminaParseCollisionObjectType(s);
}

/// The Details **Collision** section, shared by the
/// Blueprint editor's component Details and the level Details of a placed
/// actor's collision components: Collision Presets, Collision Enabled, Object
/// Type, the World Static / World Dynamic / Pawn × Ignore / Overlap / Block
/// response grid and Generate Overlap Events.
///
/// Stateless over [value] (the component's collision JSON, possibly empty);
/// every edit hands [onChanged] the whole new collision JSON, which the host
/// stores as one undo step. Widget keys start with [keyPrefix].
class CollisionSectionEditor extends StatelessWidget {
  final Map<String, dynamic> value;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final String keyPrefix;

  /// The component's setup when [value] lacks a key (a Character's capsule
  /// is Pawn).
  final LuminaCollisionProfile? base;

  const CollisionSectionEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.keyPrefix = 'collision',
    this.base,
  });

  static const String gridTooltip =
      'The effective response between two components is the weaker of the two (Ignore < Overlap < Block).';

  @override
  Widget build(BuildContext context) {
    final profile = CollisionJson.profile(value, base: base);
    final preset = CollisionJson.preset(value, base: base);
    final custom = preset == LuminaCollisionPreset.custom;
    const label = TextStyle(fontSize: 10, color: EditorColors.foreground);
    const muted = TextStyle(fontSize: 9, color: EditorColors.mutedForeground);

    // The label column is 118 px, but never more than 45 % of a narrow
    // Details panel, so the value keeps room for one line.
    Widget row(String name, Widget editor) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(children: [
              SizedBox(
                width: constraints.maxWidth.isFinite ? (constraints.maxWidth * 0.45).clamp(0.0, 118.0) : 118,
                child: Text(name, style: label),
              ),
              Expanded(child: Align(alignment: Alignment.centerLeft, child: editor)),
            ]),
          ),
        );

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
          const Text('COLLISION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
          const SizedBox(height: 8),
          row(
            'Collision Presets',
            Select<LuminaCollisionPreset>(
              key: ValueKey('${keyPrefix}_preset'),
              value: preset,
              itemBuilder: (context, p) => Text(CollisionJson.presetLabel(p), style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              onChanged: (p) {
                if (p != null && p != preset) onChanged(CollisionJson.withPreset(value, p, base: base));
              },
              // Every preset built: a short window scrolls the popup to any.
              popup: SelectPopup.noVirtualization(
                items: SelectItemList(children: [
                  for (final p in LuminaCollisionPreset.values)
                    SelectItemButton(
                      key: ValueKey('${keyPrefix}_preset_${p.name}'),
                      value: p,
                      child: Text(CollisionJson.presetLabel(p), style: const TextStyle(fontSize: 11)),
                    ),
                ]),
              ).call,
            ),
          ),
          row(
            'Collision Enabled',
            Switch(
              key: ValueKey('${keyPrefix}_enabled'),
              value: profile.collisionEnabled,
              enabled: custom,
              onChanged: (v) => onChanged(CollisionJson.withCollisionEnabled(value, v, base: base)),
            ),
          ),
          row(
            'Object Type',
            Select<CollisionObjectType>(
              key: ValueKey('${keyPrefix}_object_type'),
              value: profile.objectType,
              enabled: custom,
              itemBuilder: (context, t) => Text(CollisionJson.channelLabel(t), style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              onChanged: (t) {
                if (t != null && t != profile.objectType) onChanged(CollisionJson.withObjectType(value, t, base: base));
              },
              popup: SelectPopup(
                items: SelectItemList(children: [
                  for (final t in CollisionObjectType.values)
                    SelectItemButton(
                      key: ValueKey('${keyPrefix}_object_type_${t.name}'),
                      value: t,
                      child: Text(CollisionJson.channelLabel(t), style: const TextStyle(fontSize: 11)),
                    ),
                ]),
              ).call,
            ),
          ),
          row(
            'Generate Overlap Events',
            Switch(
              key: ValueKey('${keyPrefix}_overlap_events'),
              value: profile.generateOverlapEvents,
              onChanged: (v) => onChanged(CollisionJson.withGenerateOverlapEvents(value, v, base: base)),
            ),
          ),
          const SizedBox(height: 6),
          // The response grid: one radio group per channel, greyed unless
          // Custom (the preset's values are what it shows then).
          Tooltip(
            tooltip: (context) => TooltipContainer(child: const Text(gridTooltip).small()),
            child: Row(children: [
              const SizedBox(width: 118, child: Text('Collision Responses', style: muted)),
              for (final r in CollisionResponse.values)
                Expanded(child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: Text(CollisionJson.responseLabel(r), style: muted, maxLines: 1)))),
            ]),
          ),
          const SizedBox(height: 2),
          Opacity(
            opacity: custom ? 1.0 : 0.5,
            child: Column(children: [
              for (final t in CollisionObjectType.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: RadioGroup<CollisionResponse>(
                    key: ValueKey('${keyPrefix}_response_${t.name}'),
                    value: profile.responses[t],
                    enabled: custom,
                    onChanged: custom
                        ? (r) {
                            if (r != profile.responses[t]) onChanged(CollisionJson.withResponse(value, t, r, base: base));
                          }
                        : null,
                    child: Row(children: [
                      SizedBox(width: 118, child: Text(CollisionJson.channelLabel(t), style: label)),
                      for (final r in CollisionResponse.values)
                        Expanded(
                          child: Center(
                            child: RadioItem<CollisionResponse>(
                              key: ValueKey('${keyPrefix}_response_${t.name}_${r.name}'),
                              value: r,
                              enabled: custom,
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),
            ]),
          ),
          if (!custom) ...[
            const SizedBox(height: 4),
            const Text('Pick Custom to edit the object type and the responses.', style: muted),
          ],
        ],
      ),
    );
  }
}
