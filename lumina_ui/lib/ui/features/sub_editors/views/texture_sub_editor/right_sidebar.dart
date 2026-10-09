part of '../texture_sub_editor.dart';

/// The right sidebar: texture settings.
mixin _TextureSubEditorRightSidebar on _TextureSubEditorStateBase {
  Widget _buildRightSidebar() {
    final vm = _viewModel;
    final s = vm.settings;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // 1. General Settings
        const Row(
          children: [
            Icon(LucideIcons.slidersHorizontal, size: 12, color: Colors.teal),
            SizedBox(width: 6),
            Text('GENERAL SETTINGS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal)),
          ],
        ),
        const SizedBox(height: 10),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('sRGB (Color Space)', style: TextStyle(fontSize: 9.5, color: EditorColors.foreground)),
            Switch(
              value: s.srgb,
              onChanged: (val) => vm.setSrgb(val),
            ),
          ],
        ),
        const SizedBox(height: 10),

        const Text('Texture Group', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
        const SizedBox(height: 4),
        Select<String>(
          value: s.group,
          onChanged: (val) {
            if (val != null) vm.setTextureGroup(val);
          },
          itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 9.5)),
          popup: const SelectPopup(
            items: SelectItemList(
              children: [
                SelectItemButton(value: 'World', child: Text('World')),
                SelectItemButton(value: 'UI', child: Text('UI (Crisp / Uncompressed)')),
                SelectItemButton(value: 'Effects', child: Text('Effects / Particles')),
                SelectItemButton(value: 'Skybox', child: Text('Skybox (HDR / Cube)')),
                SelectItemButton(value: 'Normalmap', child: Text('Normalmap (Linear sRGB=off)')),
              ],
            ),
          ).call,
        ),

        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 14),

        // 2. Compression Settings
        const Row(
          children: [
            Icon(LucideIcons.fileArchive, size: 12, color: Colors.purple),
            SizedBox(width: 6),
            Text('COMPRESSION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple)),
          ],
        ),
        const SizedBox(height: 10),

        const Text('Compression Format', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
        const SizedBox(height: 4),
        Select<String>(
          value: s.format,
          onChanged: (val) {
            if (val != null) vm.setCompressionFormat(val);
          },
          itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 9.5)),
          popup: const SelectPopup(
            items: SelectItemList(
              children: [
                SelectItemButton(value: 'KTX2 / Basis Universal', child: Text('KTX2 / Basis Universal (Universal)')),
                SelectItemButton(value: 'ASTC', child: Text('ASTC (Mobile / High Quality)')),
                SelectItemButton(value: 'ETC2', child: Text('ETC2 (Standard Mobile)')),
                SelectItemButton(value: 'Uncompressed RGBA8', child: Text('Uncompressed RGBA8 (Lossless)')),
              ],
            ),
          ).call,
        ),
        const SizedBox(height: 10),

        const Text('Compression Quality', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
        const SizedBox(height: 4),
        Select<String>(
          value: s.quality,
          onChanged: (val) {
            if (val != null) vm.setCompressionQuality(val);
          },
          itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 9.5)),
          popup: const SelectPopup(
            items: SelectItemList(
              children: [
                SelectItemButton(value: 'Default', child: Text('Default (Balanced)')),
                SelectItemButton(value: 'High Quality / Lossless', child: Text('High Quality / Lossless')),
                SelectItemButton(value: 'Fast Compression', child: Text('Fast Compression (Preview)')),
              ],
            ),
          ).call,
        ),

        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 14),

        // 3. Mipmap Gen & Sampler Settings
        const Row(
          children: [
            Icon(LucideIcons.binary, size: 12, color: Colors.cyan),
            SizedBox(width: 6),
            Text('MIPMAP GEN & SAMPLER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.cyan)),
          ],
        ),
        const SizedBox(height: 10),

        const Text('Mip Gen Settings', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
        const SizedBox(height: 4),
        Select<String>(
          value: s.mipGen,
          onChanged: (val) {
            if (val != null) vm.setMipGenSettings(val);
          },
          itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 9.5)),
          popup: const SelectPopup(
            items: SelectItemList(
              children: [
                SelectItemButton(value: 'FromTextureGroup', child: Text('FromTextureGroup (Auto)')),
                SelectItemButton(value: 'Sharpen2', child: Text('Sharpen (Mild)')),
                SelectItemButton(value: 'Blur2', child: Text('Blur (Mild)')),
                SelectItemButton(value: 'NoMipmaps', child: Text('NoMipmaps (1 Level Only)')),
              ],
            ),
          ).call,
        ),
        const SizedBox(height: 10),

        const Text('Texture Filter', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
        const SizedBox(height: 4),
        Select<String>(
          value: s.filter,
          onChanged: (val) {
            if (val != null) vm.setFilter(val);
          },
          itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 9.5)),
          popup: const SelectPopup(
            items: SelectItemList(
              children: [
                SelectItemButton(value: 'Bilinear', child: Text('Bilinear')),
                SelectItemButton(value: 'Trilinear', child: Text('Trilinear')),
                SelectItemButton(value: 'Anisotropic 16x', child: Text('Anisotropic 16x (Highest Quality)')),
              ],
            ),
          ).call,
        ),
        const SizedBox(height: 10),

        const Text('Address Mode X / Y', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Select<String>(
                value: s.addressX,
                onChanged: (val) {
                  if (val != null) vm.setAddressModeX(val);
                },
                itemBuilder: (context, item) => Text('X: $item', style: const TextStyle(fontSize: 9)),
                popup: const SelectPopup(
                  items: SelectItemList(
                    children: [
                      SelectItemButton(value: 'Wrap', child: Text('Wrap (Tile)')),
                      SelectItemButton(value: 'Clamp', child: Text('Clamp (Edge)')),
                      SelectItemButton(value: 'Mirror', child: Text('Mirror (Ping-Pong)')),
                    ],
                  ),
                ).call,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Select<String>(
                value: s.addressY,
                onChanged: (val) {
                  if (val != null) vm.setAddressModeY(val);
                },
                itemBuilder: (context, item) => Text('Y: $item', style: const TextStyle(fontSize: 9)),
                popup: const SelectPopup(
                  items: SelectItemList(
                    children: [
                      SelectItemButton(value: 'Wrap', child: Text('Wrap (Tile)')),
                      SelectItemButton(value: 'Clamp', child: Text('Clamp (Edge)')),
                      SelectItemButton(value: 'Mirror', child: Text('Mirror (Ping-Pong)')),
                    ],
                  ),
                ).call,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
