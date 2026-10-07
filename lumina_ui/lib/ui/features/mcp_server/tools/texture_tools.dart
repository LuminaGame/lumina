import 'dart:io';

import 'package:lumina/lumina.dart' show AssetType;

import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/texture_editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_editor_sessions.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';

/// The Texture editor as MCP tools: the texture's size, mip
/// chain and settings, every setting the Details column's selects offer
/// (exactly their values), the mip / channel view, Reimport and Save. The
/// editor has no undo stack: settings are the tab's dirty state.
void registerTextureTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions) {
  const groups = {McpToolGroups.texture, McpToolGroups.assetEditors};
  // The Details column's selects (texture_sub_editor.dart), value for value.
  const textureGroups = ['World', 'UI', 'Effects', 'Skybox', 'Normalmap'];
  const compressions = ['KTX2 / Basis Universal', 'ASTC', 'ETC2', 'Uncompressed RGBA8'];
  const qualities = ['Default', 'High Quality / Lossless', 'Fast Compression'];
  const mipGens = ['FromTextureGroup', 'Sharpen2', 'Blur2', 'NoMipmaps'];
  const filters = ['Bilinear', 'Trilinear', 'Anisotropic 16x'];
  const addressModes = ['Wrap', 'Clamp', 'Mirror'];
  const noUndo = 'Not undoable (the Texture editor keeps no undo stack); close the tab without saving to discard.';
  final assetArg = McpSchema.string('The texture asset (list_assets type "texture"): project-relative path or unique file name.');

  Future<TextureEditorViewModel> editorFor(McpArgs args) =>
      sessions.texture(sessions.resolveAsset(args.string('asset'), type: AssetType.texture));

  Map<String, Object?> textureJson(TextureEditorViewModel e, String asset) => {
        'asset': asset,
        'width': e.width,
        'height': e.height,
        'mips': [for (final m in e.mipChain) {'level': m.level, 'width': m.width, 'height': m.height}],
        'settings': {
          'srgb': e.settings.srgb,
          'group': e.settings.group,
          'compression': e.settings.format,
          'quality': e.settings.quality,
          'mip_gen': e.settings.mipGen,
          'filter': e.settings.filter,
          'address_x': e.settings.addressX,
          'address_y': e.settings.addressY,
        },
        'uncompressed_bytes': e.uncompressedSizeBytes,
        'estimated_bytes': e.estimatedSizeBytes.round(),
        'source_file': e.sourceFilePath,
        'view': {
          'mip': e.selectedMip,
          'r': e.showR,
          'g': e.showG,
          'b': e.showB,
          'a': e.showA,
          'alpha_as_greyscale': e.viewAlphaAsGreyscale,
        },
        'is_dirty': e.isDirty,
      };

  registry.registerAll([
    McpTool(
      name: 'get_texture',
      risk: McpToolRisk.readOnly,
      groups: groups,
      title: 'Get texture',
      description: 'The Texture editor\'s asset (opens its tab): size, mip chain, settings (sRGB, group, compression, '
          'quality, mip generation, filter, address modes), uncompressed and estimated compressed size in bytes, the '
          'source file Reimport reads, the mip / channel view, unsaved changes.',
      inputSchema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      handler: (args) async => McpToolResult.json(textureJson(await editorFor(args), args.string('asset'))),
    ),
    McpTool(
      name: 'set_texture_settings',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set texture settings',
      description: 'The Details column: srgb, group (Normalmap also turns sRGB off), compression, quality, mip_gen '
          '(NoMipmaps keeps one level), filter, address_x / address_y — only the values the selects offer. $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'srgb': McpSchema.boolean('sRGB colour space (off for normal maps and masks).'),
        'group': McpSchema.string('Texture group.', enumValues: textureGroups),
        'compression': McpSchema.string('Compression format.', enumValues: compressions),
        'quality': McpSchema.string('Compression quality.', enumValues: qualities),
        'mip_gen': McpSchema.string('Mip generation.', enumValues: mipGens),
        'filter': McpSchema.string('Sampler filter.', enumValues: filters),
        'address_x': McpSchema.string('U address mode.', enumValues: addressModes),
        'address_y': McpSchema.string('V address mode.', enumValues: addressModes),
      }, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        final group = args.optionalString('group');
        if (group != null) e.setTextureGroup(group);
        if (args.has('srgb')) e.setSrgb(args.boolean('srgb'));
        final compression = args.optionalString('compression');
        if (compression != null) e.setCompressionFormat(compression);
        final quality = args.optionalString('quality');
        if (quality != null) e.setCompressionQuality(quality);
        final mipGen = args.optionalString('mip_gen');
        if (mipGen != null) e.setMipGenSettings(mipGen);
        final filter = args.optionalString('filter');
        if (filter != null) e.setFilter(filter);
        final x = args.optionalString('address_x');
        if (x != null) e.setAddressModeX(x);
        final y = args.optionalString('address_y');
        if (y != null) e.setAddressModeY(y);
        return McpToolResult.json(textureJson(e, args.string('asset')));
      },
    ),
    McpTool(
      name: 'set_texture_view',
      risk: McpToolRisk.editorState,
      groups: groups,
      idempotent: true,
      title: 'Set texture view',
      description: 'What the Texture editor\'s canvas shows: the mip level and the R / G / B / A channel isolator, or '
          'alpha as greyscale. A view setting: the asset is not changed (asset_editor_screenshot shows the result).',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'mip': McpSchema.integer('The mip level to show (get_texture mips).'),
        'r': McpSchema.boolean('Show the red channel.'),
        'g': McpSchema.boolean('Show the green channel.'),
        'b': McpSchema.boolean('Show the blue channel.'),
        'a': McpSchema.boolean('Show the alpha channel.'),
        'alpha_as_greyscale': McpSchema.boolean('Show alpha as greyscale.'),
      }, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        if (args.has('mip')) {
          final mip = args.integer('mip');
          if (mip < 0 || mip >= e.mipChain.length) {
            return McpToolResult.error('No mip $mip: the chain has levels 0…${e.mipChain.length - 1}.');
          }
          e.selectMip(mip);
        }
        bool? flag(String k) => args.has(k) ? args.boolean(k) : null;
        if (['r', 'g', 'b', 'a', 'alpha_as_greyscale'].any(args.has)) {
          e.setChannelMask(r: flag('r'), g: flag('g'), b: flag('b'), a: flag('a'), alphaAsGreyscale: flag('alpha_as_greyscale'));
        }
        return McpToolResult.json({'view': textureJson(e, args.string('asset'))['view'], 'is_dirty': e.isDirty});
      },
    ),
    McpTool(
      name: 'reimport_texture',
      risk: McpToolRisk.mutating,
      groups: groups,
      title: 'Reimport texture',
      description: 'The toolbar\'s Reimport: reads the texture\'s source file again, rebuilds the mips and the '
          'thumbnail and writes the .lmas (with the current settings). Refused when no source file is recorded or it '
          'is gone (the button is disabled then).',
      inputSchema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        final src = e.sourceFilePath;
        if (src == null) {
          return McpToolResult.error('${args.string('asset')} records no source file, so it cannot be reimported '
              '(the Reimport button is disabled). import_asset the image again instead.');
        }
        if (!File(src).existsSync()) return McpToolResult.error('The source file $src is missing; nothing was reimported.');
        if (!await e.reimport()) return McpToolResult.error('Reimport of $src failed; see the Output Log.');
        vm.refreshAssets();
        return McpToolResult.json({'reimported': true, ...textureJson(e, args.string('asset'))});
      },
    ),
    McpTool(
      name: 'save_texture',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Save texture',
      description: 'The tab\'s Save: writes the settings into the .lmas metadata (texture_settings).',
      inputSchema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        if (!await e.save()) return McpToolResult.error('Save failed; see the Output Log.');
        return McpToolResult.json(textureJson(e, args.string('asset')));
      },
    ),
  ]);
}
