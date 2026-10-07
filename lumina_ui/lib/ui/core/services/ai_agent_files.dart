import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/core/host/editor_host.dart' show EditorAssets;

/// One editor skill shipped in lumina_ui's `skills/<name>/` assets.
class AgentSkill {
  const AgentSkill({required this.name, required this.description, required this.files});

  /// The folder name (`lumina-mcp`), equal to the `name:` of its SKILL.md.
  final String name;

  /// The `description:` of its SKILL.md front matter.
  final String description;

  /// Its files relative to the skill folder (`SKILL.md`, `reference/tools.md`).
  final List<String> files;
}

/// What [AiAgentFiles.install] did in a project.
class AiAgentFilesReport {
  const AiAgentFilesReport({
    required this.skills,
    required this.skillFiles,
    required this.writtenDocs,
    required this.keptDocs,
  });

  /// The skills installed, for each agent tool.
  final List<String> skills;

  /// The skill files written (both tools together).
  final int skillFiles;

  /// `AGENTS.md` / `CLAUDE.md` written from the templates.
  final List<String> writtenDocs;

  /// The documents left as they were because the user edited them.
  final List<String> keptDocs;

  String get summary {
    final parts = [
      'Installed ${skills.length} skill(s) (${skills.join(', ')}) into ${AiAgentFiles.claudeSkillsDir}/ and '
          '${AiAgentFiles.antigravitySkillsDir}/',
      if (writtenDocs.isNotEmpty) 'wrote ${writtenDocs.join(' and ')}',
      if (keptDocs.isNotEmpty) 'kept the edited ${keptDocs.join(' and ')}',
    ];
    return '${parts.join('; ')}.';
  }
}

/// The files that brief AI agents working on a game project:
///
/// - every skill in lumina_ui's `skills/` (Flutter assets, so an installed
///   editor carries them), copied for Claude Code into `.claude/skills/<skill>/`
///   (its project skill folder) and for Antigravity into
///   `.agents/skills/<skill>/` (its workspace skill folder);
/// - `AGENTS.md` (read by Antigravity as an always-on rule and by other agent
///   tools) and `CLAUDE.md` (read by Claude Code; it imports `@AGENTS.md`), at
///   the project root, rendered from `assets/agent_files/*.template` with the
///   project's values.
///
/// A rendered document ends with a marker holding the hash of its text, so an
/// unedited document can be regenerated freely while one the user changed (or
/// wrote) is kept unless the caller asks to replace it. Installed skill
/// folders are always replaced by the editor's version; other folders under
/// the skill directories are the user's and are never touched.
class AiAgentFiles {
  AiAgentFiles({AssetBundle? bundle}) : _bundle = bundle ?? EditorAssets.bundle;

  final AssetBundle _bundle;

  static const String skillsAssetRoot = 'skills/';
  static const String claudeSkillsDir = '.claude/skills';
  static const String antigravitySkillsDir = '.agents/skills';
  static const String agentsDocName = 'AGENTS.md';
  static const String claudeDocName = 'CLAUDE.md';
  static const List<String> docNames = [agentsDocName, claudeDocName];
  static const String agentsTemplate = 'assets/agent_files/AGENTS.md.template';
  static const String claudeTemplate = 'assets/agent_files/CLAUDE.md.template';

  static const String _markerPrefix = '<!-- lumina-agent-file sha256=';
  static const String _markerSuffix =
      ' (written by Lumina Studio; once this file is edited, Set Up AI Agent Files keeps it) -->';

  /// The bundled skill files, sorted, as `skills/<skill>/<path>` — the
  /// asset manifest's keys in the app layout and, in a project editor host,
  /// its `packages/lumina_ui/skills/…` keys without the prefix.
  Future<List<String>> skillAssets() async {
    final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    final out = <String>{};
    for (final key in manifest.listAssets()) {
      final k = key.startsWith(EditorAssets.packagePrefix) ? key.substring(EditorAssets.packagePrefix.length) : key;
      if (k.startsWith(skillsAssetRoot) && k.split('/').length >= 3) out.add(k);
    }
    return out.toList()..sort();
  }

  /// The bundled skills, by name, with their front matter descriptions.
  Future<List<AgentSkill>> skills() async {
    final byName = <String, List<String>>{};
    for (final asset in await skillAssets()) {
      final rest = asset.substring(skillsAssetRoot.length);
      final slash = rest.indexOf('/');
      byName.putIfAbsent(rest.substring(0, slash), () => []).add(rest.substring(slash + 1));
    }
    final out = <AgentSkill>[];
    for (final name in byName.keys.toList()..sort()) {
      final files = byName[name]!;
      if (!files.contains('SKILL.md')) continue;
      final skillMd = await _bundle.loadString('$skillsAssetRoot$name/SKILL.md', cache: false);
      out.add(AgentSkill(name: name, description: _frontMatterValue(skillMd, 'description') ?? '', files: files));
    }
    return out;
  }

  static String? _frontMatterValue(String text, String key) {
    final lines = const LineSplitter().convert(text);
    if (lines.isEmpty || lines.first.trim() != '---') return null;
    for (final line in lines.skip(1)) {
      if (line.trim() == '---') break;
      if (line.startsWith('$key:')) return line.substring(key.length + 1).trim();
    }
    return null;
  }

  /// `AGENTS.md` and `CLAUDE.md` for [project], marker included.
  Future<Map<String, String>> renderDocs(LuminaProject project, {List<AgentSkill>? skills}) async {
    final list = skills ?? await this.skills();
    final legacy = project.isLegacyMetreProject;
    final unit = legacy ? 'm' : 'cm';
    final up = project.upAxis.toLowerCase() == kUpAxisY ? 'Y' : 'Z';
    final values = <String, String>{
      'project_name': project.projectName,
      'engine_version': project.engineVersion,
      'template': project.template,
      'active_level': project.activeLevel.isEmpty ? '(none yet)' : project.activeLevel,
      'widget_library': project.ui.widgetLibrary,
      'units_line': '1 unit = 1 $unit',
      'up_line': '$up is up',
      'units_detail': legacy ? _legacyUnitsDetail(project, up) : _unitsDetail,
      'claude_skills_dir': claudeSkillsDir,
      'antigravity_skills_dir': antigravitySkillsDir,
      'skill_names': list.map((s) => '`${s.name}`').join(', '),
      'skills_table': [
        '| Skill | Use it when |',
        '|---|---|',
        for (final s in list) '| `${s.name}` | ${s.description.replaceAll('|', r'\|')} |',
      ].join('\n'),
    };
    final out = <String, String>{};
    for (final entry in {agentsDocName: agentsTemplate, claudeDocName: claudeTemplate}.entries) {
      final template = await _bundle.loadString(entry.value, cache: false);
      final body = template.replaceAll('\r\n', '\n').replaceAllMapped(
            RegExp(r'\{\{([a-z_]+)\}\}'),
            (m) => values[m.group(1)!] ?? m.group(0)!,
          );
      out[entry.key] = _withMarker(body);
    }
    return out;
  }

  static const String _unitsDetail =
      'One world unit is one centimetre (1 unit = 1 cm), angles are in degrees, and Z is up: in the Details panel, '
      'in stored `.lmas` transforms and in every MCP tool. A rotation is `[pitch, roll, yaw]` in degrees about X, Y, '
      'Z; at rotation 0 an actor faces +Y. The runtime converts to the renderer\'s Y-up space itself, so never '
      'convert by hand. glTF/GLB models are in metres and are drawn x100: a 1 m barrel spans about 100 units at '
      'scale 1.';

  static String _legacyUnitsDetail(LuminaProject p, String up) =>
      'This project predates centimetre, Z-up authoring: its manifest says `world_units: ${p.worldUnits}` and '
      '`up_axis: ${p.upAxis}`, so 1 unit = 1 m and $up is up. It is not migrated; keep its values in metres. '
      'Angles are in degrees.';

  static String _hash(String body) => sha256.convert(utf8.encode(body.replaceAll('\r\n', '\n'))).toString();

  static String _withMarker(String body) {
    final b = body.endsWith('\n') ? body : '$body\n';
    return '$b\n$_markerPrefix${_hash(b)}$_markerSuffix\n';
  }

  /// Whether [text] is a document as the editor wrote it: its marker's hash
  /// matches the text before it.
  static bool isUnedited(String text) {
    final t = text.replaceAll('\r\n', '\n');
    final at = t.lastIndexOf('\n$_markerPrefix');
    if (at < 0) return false;
    final marker = t.substring(at + 1).trim();
    if (!marker.endsWith(_markerSuffix)) return false;
    final hash = marker.substring(_markerPrefix.length, marker.length - _markerSuffix.length);
    return _hash(t.substring(0, at)) == hash;
  }

  /// The documents in [projectDir] the user edited or wrote: present, and not
  /// as the editor left them.
  Future<List<String>> editedDocs(String projectDir) async => [
        for (final name in docNames)
          if (_edited(File('$projectDir/$name'))) name,
      ];

  static bool _edited(File f) => f.existsSync() && !isUnedited(f.readAsStringSync());

  /// Installs the skills for both tools into [projectDir] and writes the two
  /// documents for [project]. An edited document is kept unless
  /// [overwriteDocs].
  Future<AiAgentFilesReport> install(String projectDir, LuminaProject project, {bool overwriteDocs = false}) async {
    final list = await skills();
    var count = 0;
    for (final target in [claudeSkillsDir, antigravitySkillsDir]) {
      for (final skill in list) {
        final dir = Directory('$projectDir/$target/${skill.name}');
        if (dir.existsSync()) dir.deleteSync(recursive: true);
        for (final rel in skill.files) {
          final data = await _bundle.load('$skillsAssetRoot${skill.name}/$rel');
          final out = File('${dir.path}/$rel');
          out.parent.createSync(recursive: true);
          out.writeAsBytesSync(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
          count++;
        }
      }
    }
    final docs = await renderDocs(project, skills: list);
    final written = <String>[];
    final kept = <String>[];
    for (final name in docNames) {
      final f = File('$projectDir/$name');
      if (!overwriteDocs && _edited(f)) {
        kept.add(name);
        continue;
      }
      f.writeAsStringSync(docs[name]!, flush: true);
      written.add(name);
    }
    return AiAgentFilesReport(
      skills: [for (final s in list) s.name],
      skillFiles: count,
      writtenDocs: written,
      keptDocs: kept,
    );
  }
}
