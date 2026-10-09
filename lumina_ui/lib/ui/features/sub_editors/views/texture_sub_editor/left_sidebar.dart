part of '../texture_sub_editor.dart';

/// The left sidebar: texture metrics and channel toggles.
mixin _TextureSubEditorLeftSidebar on _TextureSubEditorStateBase {
  Widget _buildLeftSidebar() {
    final vm = _viewModel;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // 1. Texture Metrics Card
        const Row(
          children: [
            Icon(LucideIcons.info, size: 12, color: Colors.teal),
            SizedBox(width: 6),
            Text('TEXTURE METRICS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal)),
          ],
        ),
        const SizedBox(height: 10),
        _buildMetricRow('Resolution', '${vm.width} × ${vm.height} px'),
        _buildMetricRow('Aspect Ratio', vm.aspectRatioStr),
        _buildMetricRow('Uncompressed Size', vm.uncompressedSizeStr),
        _buildMetricRow('Estimated Size', vm.estimatedSizeStr),
        _buildMetricRow('Total Mipmaps', '${vm.mipChain.length} Levels'),
        _buildMetricRow('Active Channels', vm.channelMaskStr),

        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 14),

        // 2. Channel Isolation Card
        const Row(
          children: [
            Icon(LucideIcons.layers, size: 12, color: Colors.orange),
            SizedBox(width: 6),
            Text('CHANNEL ISOLATOR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
          ],
        ),
        const SizedBox(height: 10),

        _buildChannelRow('Red Channel (R)', Colors.red, vm.showR, (val) => vm.setChannelMask(r: val)),
        _buildChannelRow('Green Channel (G)', Colors.green, vm.showG, (val) => vm.setChannelMask(g: val)),
        _buildChannelRow('Blue Channel (B)', Colors.blue, vm.showB, (val) => vm.setChannelMask(b: val)),
        _buildChannelRow('Alpha Channel (A)', Colors.purple, vm.showA, (val) => vm.setChannelMask(a: val)),

        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Alpha as Greyscale', style: TextStyle(fontSize: 9.5, color: EditorColors.foreground)),
            Switch(
              value: vm.viewAlphaAsGreyscale,
              onChanged: (val) => vm.setChannelMask(alphaAsGreyscale: val),
            ),
          ],
        ),

        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 14),

        // 3. Mipmap Level Inspector
        const Row(
          children: [
            Icon(LucideIcons.pyramid, size: 12, color: Colors.cyan),
            SizedBox(width: 6),
            Text('MIPMAP INSPECTOR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.cyan)),
          ],
        ),
        const SizedBox(height: 10),

        Select<int>(
          value: vm.selectedMip,
          onChanged: (val) {
            if (val != null) vm.selectMip(val);
          },
          itemBuilder: (context, item) {
            final mip = item < vm.mipChain.length ? vm.mipChain[item] : null;
            return Text('Mip $item (${mip?.width}×${mip?.height})', style: const TextStyle(fontSize: 9.5));
          },
          popup: SelectPopup(
            items: SelectItemList(
              children: List.generate(vm.mipChain.length, (idx) {
                final m = vm.mipChain[idx];
                return SelectItemButton(
                  value: idx,
                  child: Text('Mip $idx — ${m.width} × ${m.height} px'),
                );
              }),
            ),
          ).call,
        ),
        const SizedBox(height: 8),
        Text(
          'Viewing Mip ${vm.selectedMip}: ${vm.activeMip.width} × ${vm.activeMip.height} px (${(vm.activeMip.pixels.length / 1024.0).toStringAsFixed(1)} KB)',
          style: const TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground),
        ),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
          Text(value, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
        ],
      ),
    );
  }

  Widget _buildChannelRow(String label, Color dotColor, bool isChecked, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 9.5, color: EditorColors.foreground)),
          ),
          Checkbox(
            state: isChecked ? CheckboxState.checked : CheckboxState.unchecked,
            onChanged: (state) => onChanged(state == CheckboxState.checked),
          ),
        ],
      ),
    );
  }
}
