import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/features/sub_editors/sub_editor_binding.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/texture_editor_view_model.dart';

class TextureSubEditor extends StatefulWidget {
  final String assetName;
  final String? assetPath;
  final RealAssetInfo? asset;
  final TextureEditorViewModel? viewModel;
  final VoidCallback? onClose;
  final SubEditorBindCallback? onBind;

  const TextureSubEditor({
    super.key,
    required this.assetName,
    this.assetPath,
    this.asset,
    this.viewModel,
    this.onClose,
    this.onBind,
  });

  @override
  State<TextureSubEditor> createState() => _TextureSubEditorState();
}

class _TextureSubEditorState extends State<TextureSubEditor> {
  late final TextureEditorViewModel _viewModel;
  late final bool _ownsViewModel;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    final path = widget.assetPath ?? widget.asset?.lmasPath ?? widget.asset?.relativePath ?? 'contents/textures/${widget.assetName}.lmas';
    _viewModel = widget.viewModel ?? TextureEditorViewModel(assetPath: path);
    widget.onBind?.call(_viewModel, _viewModel.save, () => _viewModel.isDirty);

    if (_ownsViewModel) {
      _viewModel.load();
    }
  }

  @override
  void dispose() {
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final isDirty = _viewModel.isDirty;

        if (_viewModel.isLoading) {
          return Container(
            color: EditorColors.background,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Decoding texture payload & generating MIP chain...', style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
                ],
              ),
            ),
          );
        }

        if (_viewModel.hasError) {
          return Container(
            color: EditorColors.background,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.triangleAlert, size: 28, color: EditorColors.logError),
                  const SizedBox(height: 8),
                  Text('Failed to load texture asset at ${_viewModel.assetPath}', style: const TextStyle(fontSize: 11, color: EditorColors.foreground)),
                  const SizedBox(height: 16),
                  OutlineButton(
                    onPressed: widget.onClose,
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          color: EditorColors.background,
          child: Column(
            children: [
              // 1. Top Toolbar
              _buildToolbar(isDirty),
              const Divider(height: 1),

              // 2. Main 3-Panel Workspace
              Expanded(
                child: ResizablePanel.horizontal(
                  children: [
                    // Left Panel: Metadata & Channel Isolation & MIP Selection
                    ResizablePane(
                      initialSize: 260,
                      minSize: 220,
                      child: Container(
                        color: EditorColors.cardHeader,
                        child: _buildLeftSidebar(),
                      ),
                    ),

                    // Center Panel: Zoom/Pan Canvas with Pixel Inspector Bar
                    ResizablePane.flex(
                      child: Column(
                        children: [
                          Expanded(
                            child: _buildCanvas(),
                          ),
                          const Divider(height: 1),
                          _buildPixelInspectorBar(),
                        ],
                      ),
                    ),

                    // Right Panel: Compression, MipGen, and Sampler Settings
                    ResizablePane(
                      initialSize: 290,
                      minSize: 240,
                      child: Container(
                        color: EditorColors.cardHeader,
                        child: _buildRightSidebar(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbar(bool isDirty) {
    final vm = _viewModel;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: EditorColors.card,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text('TEXTURE 2D', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.teal)),
          ),
          const SizedBox(width: 8),
          Text(
            '${widget.assetName}${isDirty ? ' *' : ''}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EditorColors.foreground),
          ),
          const SizedBox(width: 12),

          OutlineBadge(
            child: Text('${vm.width} × ${vm.height}', style: const TextStyle(fontSize: 9)),
          ),
          const SizedBox(width: 6),

          OutlineBadge(
            child: Text('${vm.mipChain.length} Mips', style: const TextStyle(fontSize: 9)),
          ),
          const Spacer(),

          // Reimport Button
          OutlineButton(
            size: ButtonSize.small,
            onPressed: vm.sourceFilePath != null ? () => vm.reimport() : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.refreshCw, size: 11),
                SizedBox(width: 4),
                Text('Reimport', style: TextStyle(fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Save Button
          PrimaryButton(
            size: ButtonSize.small,
            onPressed: isDirty ? () => vm.save() : null,
            child: const Text('Save', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),

          // Close Button
          GhostButton(
            size: ButtonSize.small,
            onPressed: widget.onClose,
            child: const Icon(LucideIcons.x, size: 14),
          ),
        ],
      ),
    );
  }

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

  Widget _buildCanvas() {
    final vm = _viewModel;
    return Stack(
      children: [
        // Zoom/Pan Canvas with Mouse Events
        Positioned.fill(
          child: Listener(
            onPointerSignal: (signal) {
              if (signal is PointerScrollEvent) {
                final delta = signal.scrollDelta.dy;
                final zoomFactor = delta < 0 ? 1.15 : 0.85;
                vm.setZoom(vm.zoom * zoomFactor);
              }
            },
            child: GestureDetector(
              onPanUpdate: (details) {
                vm.setPan(vm.pan + details.delta);
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return MouseRegion(
                    onHover: (event) {
                      final size = constraints.biggest;
                      final center = Offset(size.width / 2, size.height / 2) + vm.pan;
                      final imgW = vm.activeMip.width * vm.zoom;
                      final imgH = vm.activeMip.height * vm.zoom;
                      final imgLeft = center.dx - imgW / 2;
                      final imgTop = center.dy - imgH / 2;

                      final localX = event.localPosition.dx - imgLeft;
                      final localY = event.localPosition.dy - imgTop;

                      if (localX >= 0 && localX < imgW && localY >= 0 && localY < imgH) {
                        final u = (localX / imgW).clamp(0.0, 1.0);
                        final v = (localY / imgH).clamp(0.0, 1.0);
                        final px = (u * vm.activeMip.width).floor().clamp(0, vm.activeMip.width - 1);
                        final py = (v * vm.activeMip.height).floor().clamp(0, vm.activeMip.height - 1);
                        vm.setHover(u, v, px, py);
                      } else {
                        vm.clearHover();
                      }
                    },
                    onExit: (_) => vm.clearHover(),
                    child: CustomPaint(
                      painter: _TextureCanvasPainter(
                        image: vm.activeMipUiImage,
                        zoom: vm.zoom,
                        pan: vm.pan,
                        mipWidth: vm.activeMip.width,
                        mipHeight: vm.activeMip.height,
                      ),
                      size: Size.infinite,
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // Floating HUD: Zoom Controls
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: EditorColors.card.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: EditorColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Zoom: ${(vm.zoom * 100).toInt()}%',
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground),
                ),
                const SizedBox(width: 8),
                // The zoom also takes a typed percentage.
                SizedBox(
                  width: 170,
                  child: SliderField(
                    key: const ValueKey('texture_zoom_slider'),
                    value: vm.zoom * 100,
                    defaultValue: 100,
                    min: 10,
                    max: 3200,
                    unit: '%',
                    fractionDigits: 0,
                    onChanged: (v) => vm.setZoom(v / 100),
                    onCommit: (v) => vm.setZoom(v / 100),
                    onReset: () => vm.setZoom(1.0),
                  ),
                ),
                const SizedBox(width: 8),
                OutlineButton(
                  size: ButtonSize.small,
                  onPressed: vm.resetZoom,
                  child: const Text('Reset', style: TextStyle(fontSize: 8.5)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPixelInspectorBar() {
    final vm = _viewModel;
    final hasHover = vm.hoverU != null && vm.hoverRgba != null;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: EditorColors.card,
      child: Row(
        children: [
          const Icon(LucideIcons.crosshair, size: 12, color: Colors.cyan),
          const SizedBox(width: 6),
          if (hasHover) ...[
            Text(
              'UV: ${vm.hoverU!.toStringAsFixed(4)}, ${vm.hoverV!.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 9.5, fontFamily: EditorTypography.monoFamily, color: EditorColors.foreground),
            ),
            const SizedBox(width: 12),
            Text(
              'XY: ${vm.hoverX}, ${vm.hoverY}',
              style: const TextStyle(fontSize: 9.5, fontFamily: EditorTypography.monoFamily, color: EditorColors.foreground),
            ),
            const SizedBox(width: 12),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Color.fromARGB(vm.hoverRgba!.$4, vm.hoverRgba!.$1, vm.hoverRgba!.$2, vm.hoverRgba!.$3),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'RGBA: (${vm.hoverRgba!.$1}, ${vm.hoverRgba!.$2}, ${vm.hoverRgba!.$3}, ${vm.hoverRgba!.$4})',
              style: const TextStyle(fontSize: 9.5, fontFamily: EditorTypography.monoFamily, fontWeight: FontWeight.bold, color: Colors.cyan),
            ),
            const SizedBox(width: 8),
            Text(
              '${vm.hoverHex}',
              style: const TextStyle(fontSize: 9.5, fontFamily: EditorTypography.monoFamily, color: EditorColors.mutedForeground),
            ),
          ] else ...[
            const Text(
              'Hover over the canvas to inspect exact pixel RGBA & UV coordinates',
              style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

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

class _TextureCanvasPainter extends CustomPainter {
  final ui.Image? image;
  final double zoom;
  final ui.Offset pan;
  final int mipWidth;
  final int mipHeight;

  _TextureCanvasPainter({
    required this.image,
    required this.zoom,
    required this.pan,
    required this.mipWidth,
    required this.mipHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Checkerboard background for alpha transparency
    final checkPaint1 = Paint()..color = EditorColors.popover;
    final checkPaint2 = Paint()..color = EditorColors.secondary;
    const checkSize = 16.0;

    for (double y = 0; y < size.height; y += checkSize) {
      for (double x = 0; x < size.width; x += checkSize) {
        final isEven = ((x / checkSize).floor() + (y / checkSize).floor()) % 2 == 0;
        canvas.drawRect(Rect.fromLTWH(x, y, checkSize, checkSize), isEven ? checkPaint1 : checkPaint2);
      }
    }

    if (image == null || mipWidth == 0 || mipHeight == 0) return;

    final center = Offset(size.width / 2, size.height / 2) + pan;
    final drawW = mipWidth * zoom;
    final drawH = mipHeight * zoom;
    final destRect = Rect.fromCenter(center: center, width: drawW, height: drawH);

    // 2. Draw Decoded Image (Nearest-neighbor FilterQuality.none for pixel-crisp display at zoom >= 1.0)
    final imagePaint = Paint()
      ..filterQuality = zoom >= 1.0 ? FilterQuality.none : FilterQuality.low
      ..isAntiAlias = zoom < 1.0;

    canvas.drawImageRect(
      image!,
      Rect.fromLTWH(0, 0, image!.width.toDouble(), image!.height.toDouble()),
      destRect,
      imagePaint,
    );

    // 3. Draw Pixel Grid Overlay when zoomed in >= 800%
    if (zoom >= 8.0) {
      final gridPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..strokeWidth = 0.5;

      final stepX = drawW / mipWidth;
      final stepY = drawH / mipHeight;

      for (int x = 0; x <= mipWidth; x++) {
        final gx = destRect.left + x * stepX;
        canvas.drawLine(Offset(gx, destRect.top), Offset(gx, destRect.bottom), gridPaint);
      }
      for (int y = 0; y <= mipHeight; y++) {
        final gy = destRect.top + y * stepY;
        canvas.drawLine(Offset(destRect.left, gy), Offset(destRect.right, gy), gridPaint);
      }
    }

    // Border around texture
    final borderPaint = Paint()
      ..color = Colors.teal.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(destRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _TextureCanvasPainter oldDelegate) => true;
}
