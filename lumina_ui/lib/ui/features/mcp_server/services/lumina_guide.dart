import '../../../core/host/editor_host.dart' show EditorAssets;

/// One topic of the Lumina engine guide: its id (the `reference/<id>.md`
/// file) and title.
class LuminaGuideTopic {
  const LuminaGuideTopic(this.id, this.title);
  final String id;
  final String title;
}

/// The Lumina engine guide for AI models: how the engine works, written
/// from the code, shipped with the editor as the `lumina-engine` skill
/// (`skills/lumina-engine/`, Flutter assets, so every build carries it;
/// loaded through [EditorAssets], so a project editor host, which bundles
/// them as `packages/lumina_ui/skills/…`, finds them too).
/// `get_lumina_guide` and the `lumina://guide` resources serve it.
class LuminaGuide {
  LuminaGuide({Future<String> Function(String assetPath)? load}) : _load = load ?? EditorAssets.bundle.loadString;

  final Future<String> Function(String assetPath) _load;
  final Map<String, String> _cache = {};

  /// The asset folder of the skill.
  static const String root = 'skills/lumina-engine';

  /// The topics, in reading order. A test keeps this list equal to the
  /// `reference/*.md` files.
  static const List<LuminaGuideTopic> topics = [
    LuminaGuideTopic('project-layout', 'Project layout: .lmproject, contents/, .lmas assets, generated code'),
    LuminaGuideTopic('levels-actors-transforms', 'Levels, actors, components, transforms (units, axes, rotation)'),
    LuminaGuideTopic('blueprints', 'Blueprints: graphs, events, variables, components, compile'),
    LuminaGuideTopic('gameplay-framework', 'Game mode, pawn / character, controller, Maps & Modes'),
    LuminaGuideTopic('input', 'Input actions, mapping contexts, keys'),
    LuminaGuideTopic('umg-widgets', 'Widget Blueprints: elements, Create Widget, Get Element, text, interfaces'),
    LuminaGuideTopic('meshes-materials', 'Meshes and materials: import, material assets, overrides, slots'),
    LuminaGuideTopic(
      'filament-materials',
      "Writing a material's Filament .mat source (blocks, shading, parameters, blending)",
    ),
    LuminaGuideTopic('lights', 'Level lights and the Blueprint Point Light'),
    LuminaGuideTopic('camera-spring-arm', 'Camera, spring arm, control rotation'),
    LuminaGuideTopic('play-testing', 'Play-testing in PIE: start, play, input, screenshots, logs'),
    LuminaGuideTopic('save-games', 'Save games'),
    LuminaGuideTopic('pitfalls', 'Common pitfalls'),
  ];

  static final Set<String> topicIds = {for (final t in topics) t.id};

  /// The resource of the overview, and of a topic (`lumina://guide/<id>`).
  static const String resource = 'lumina://guide';
  static String resourceOf(String topic) => '$resource/$topic';

  /// The asset path of [topic] (null: the overview, `SKILL.md`).
  static String assetOf(String? topic) => topic == null ? '$root/SKILL.md' : '$root/reference/$topic.md';

  /// [text] without a leading YAML front matter block.
  static String stripFrontMatter(String text) {
    final t = text.replaceAll('\r\n', '\n');
    if (!t.startsWith('---\n')) return t.trim();
    final end = t.indexOf('\n---\n', 4);
    return end < 0 ? t.trim() : t.substring(end + 5).trim();
  }

  Future<String> _read(String? topic) async {
    final path = assetOf(topic);
    return _cache[path] ??= stripFrontMatter(await _load(path));
  }

  /// The overview followed by the topic list and how to ask for a topic.
  Future<String> overview() async {
    final body = await _read(null);
    return [
      body,
      '',
      '## Topics',
      '',
      'Call get_lumina_guide with `topic` (or read lumina://guide/<topic>) before working in an area you have not used yet:',
      '',
      for (final t in topics) '- `${t.id}`: ${t.title}',
    ].join('\n');
  }

  /// The text of [id]; an [ArgumentError] naming the topics when unknown.
  Future<String> topic(String id) async {
    if (!topicIds.contains(id)) {
      throw ArgumentError('Unknown guide topic "$id". Topics: ${topics.map((t) => t.id).join(', ')}.');
    }
    return _read(id);
  }
}
