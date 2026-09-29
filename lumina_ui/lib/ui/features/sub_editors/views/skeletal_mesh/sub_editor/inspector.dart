part of '../skeletal_mesh_sub_editor.dart';

/// Right inspector panel: socket, bone and skin-weight-map inspectors.
mixin _SkeletalMeshInspector on _SkeletalMeshSubEditorStateBase {

  Widget _buildRightInspectorPanel() {
    final vm = _viewModel;
    final socket = vm.selectedSocket;
    final bone = vm.selectedBone;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (socket != null) ...[
          _buildSocketInspector(socket),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
        ] else if (bone != null) ...[
          _buildBoneInspector(bone),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
        ],

        // Material slots sit above the skin-weight tools: they are the section-level
        // bindings, the weight map is per-vertex diagnostics.
        SkeletalMaterialSlotsPanel(viewModel: vm),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),

        // Always show Skin Weight Map & Vertex Inspector
        _buildSkinWeightMapInspector(),
      ],
    );
  }

  Widget _buildSocketInspector(SkeletalMeshSocket socket) {
    final vm = _viewModel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.crosshair, size: 12, color: Colors.amber),
            const SizedBox(width: 6),
            const Text('SOCKET DETAILS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber)),
            const Spacer(),
            GhostButton(
              size: ButtonSize.small,
              onPressed: () => _confirmRemoveSocket(socket.name),
              child: const Icon(LucideIcons.trash2, size: 12, color: EditorColors.logError),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Socket Name
        const Text('Socket Name', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
        const SizedBox(height: 4),
        SyncedTextField(
          key: ValueKey('socket_name_${socket.name}'),
          text: socket.name,
          onSubmitted: (val) {
            vm.renameSocket(socket.name, val);
          },
        ),
        const SizedBox(height: 10),

        // Parent Bone
        const Text('Parent Bone', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
        const SizedBox(height: 4),
        Select<String>(
          value: socket.parentBone,
          onChanged: (val) {
            if (val != null) vm.reparentSocket(socket.name, val);
          },
          itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 10)),
          popup: SelectPopup(
            items: SelectItemList(
              children: vm.allBoneNames.map((b) => SelectItemButton(value: b, child: Text(b))).toList(),
            ),
          ).call,
        ),
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 12),

        // Relative Location
        const Text('Relative Location', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
        const SizedBox(height: 6),
        _buildVector3Inputs(
          socket.relativeLocation,
          (newVec) => vm.setSocketTransform(socket.name, location: newVec),
        ),
        const SizedBox(height: 12),

        // Relative Rotation
        const Text('Relative Rotation', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
        const SizedBox(height: 6),
        _buildVector3Inputs(
          socket.relativeRotation.sublist(0, 3),
          (newVec) => vm.setSocketTransform(socket.name, rotation: newVec),
        ),
        const SizedBox(height: 12),

        // Relative Scale
        const Text('Relative Scale', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
        const SizedBox(height: 6),
        _buildVector3Inputs(
          socket.relativeScale,
          (newVec) => vm.setSocketTransform(socket.name, scale: newVec),
        ),
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 12),

        // Preview Asset
        const Text('Preview Attached Mesh', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
        const SizedBox(height: 4),
        // A picker over the project's meshes; the
        // path is stored project-relative, as MCP set_skeletal_socket does.
        AssetPickerSelect(
          key: ValueKey('skeletal_socket_preview_${socket.name}'),
          keyPrefix: 'skeletal_socket_preview_picker_${socket.name}',
          placeholder: '— none —',
          selectedPath: socket.previewAssetPath,
          assets: vm.availablePreviewMeshes,
          onSelected: (asset) => vm.setSocketPreviewAsset(socket.name, asset.relativePath),
          onCleared: () => vm.setSocketPreviewAsset(socket.name, null),
        ),
      ],
    );
  }

  Widget _buildVector3Inputs(List<double> vec, ValueChanged<List<double>> onChanged) {
    return Row(
      children: [
        _buildAxisField('X', vec.isNotEmpty ? vec[0] : 0.0, Colors.red, (v) {
          final copy = List<double>.from(vec);
          copy[0] = v;
          onChanged(copy);
        }),
        const SizedBox(width: 6),
        _buildAxisField('Y', vec.length > 1 ? vec[1] : 0.0, Colors.green, (v) {
          final copy = List<double>.from(vec);
          copy[1] = v;
          onChanged(copy);
        }),
        const SizedBox(width: 6),
        _buildAxisField('Z', vec.length > 2 ? vec[2] : 0.0, Colors.blue, (v) {
          final copy = List<double>.from(vec);
          copy[2] = v;
          onChanged(copy);
        }),
      ],
    );
  }

  Widget _buildAxisField(String axis, double val, Color color, ValueChanged<double> onValChanged) {
    return Expanded(
      child: Container(
        height: 28,
        decoration: BoxDecoration(
          color: EditorColors.card,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: EditorColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(3)),
              ),
              child: Text(axis, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: color)),
            ),
            Expanded(
              child: SyncedTextField(
                text: val.toStringAsFixed(1),
                onChanged: (s) {
                  final parsed = double.tryParse(s);
                  if (parsed != null) onValChanged(parsed);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoneInspector(GlbNode bone) {
    final vm = _viewModel;
    final sockets = vm.getSocketsForBone(bone.name);
    final retarget = vm.boneRetargeting[bone.name] ?? 'Animation';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(LucideIcons.bone, size: 12, color: Colors.purple),
            SizedBox(width: 6),
            Text('BONE DETAILS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple)),
          ],
        ),
        const SizedBox(height: 10),

        _buildDetailRow('Bone Name', bone.name),
        _buildDetailRow('Node Index', '${bone.index}'),
        _buildDetailRow('Child Count', '${bone.children.length}'),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),

        const Text('Translation Retargeting', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
        const SizedBox(height: 6),
        Select<String>(
          value: retarget,
          onChanged: (val) {
            if (val != null) vm.setBoneRetargeting(bone.name, val);
          },
          itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 10.5)),
          popup: SelectPopup(
            items: SelectItemList(
              children: const [
                SelectItemButton(value: 'Animation', child: Text('Animation (Default)')),
                SelectItemButton(value: 'Skeleton', child: Text('Skeleton')),
                SelectItemButton(value: 'AnimationScaled', child: Text('Animation Scaled')),
              ],
            ),
          ).call,
        ),
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 12),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Direct Sockets (${sockets.length})', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
            OutlineButton(
              size: ButtonSize.small,
              onPressed: () => vm.addSocket(parentBone: bone.name),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.plus, size: 10),
                  SizedBox(width: 4),
                  Text('Add Socket', style: TextStyle(fontSize: 9)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...sockets.map((s) => _buildSocketRow(s, 0)),
      ],
    );
  }

  Widget _buildSkinWeightMapInspector() {
    final vm = _viewModel;
    final inspected = vm.inspectedVertex;
    final influences = inspected != null ? vm.getVertexInfluences(inspected) : <String, double>{};
    final weightSum = inspected != null ? vm.getVertexWeightSum(inspected) : 1.0;
    final isNormalized = (weightSum - 1.0).abs() <= 0.01;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.flame, size: 12, color: Colors.orange),
            const SizedBox(width: 6),
            const Text('SKIN WEIGHT MAP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
            const Spacer(),
            OutlineBadge(
              child: Text('${vm.maxInfluences} Max Influences', style: const TextStyle(fontSize: 8.5)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Color Spectrum Legend
        Container(
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            gradient: const LinearGradient(
              colors: [
                Colors.blue,
                Colors.cyan,
                Colors.green,
                Colors.yellow,
                Colors.red,
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0.0 (No Influence)', style: TextStyle(fontSize: 8, color: Colors.blue)),
            Text('0.5', style: TextStyle(fontSize: 8, color: Colors.green)),
            Text('1.0 (Full Influence)', style: TextStyle(fontSize: 8, color: Colors.red)),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),

        // Vertex Inspect Card
        Row(
          children: [
            const Icon(LucideIcons.scan, size: 12, color: Colors.cyan),
            const SizedBox(width: 6),
            const Text('VERTEX INSPECT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.cyan)),
            const Spacer(),
            if (inspected != null)
              GhostButton(
                size: ButtonSize.small,
                onPressed: () => vm.setInspectedVertex(null),
                child: const Text('Clear', style: TextStyle(fontSize: 8.5)),
              ),
          ],
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: TextField(
                placeholder: const Text('Inspect vertex #id...'),
                initialValue: inspected != null ? '$inspected' : '',
                onSubmitted: (val) {
                  final id = int.tryParse(val.trim());
                  if (id != null && id >= 0 && id < vm.vertexCount) {
                    vm.setInspectedVertex(id);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (inspected != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: EditorColors.card,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: EditorColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Vertex #$inspected', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.cyan)),
                    if (!isNormalized)
                      DestructiveBadge(
                        child: Text('Non-normalized: ${weightSum.toStringAsFixed(2)}', style: const TextStyle(fontSize: 8)),
                      )
                    else
                      OutlineBadge(
                        child: Text('Sum: ${weightSum.toStringAsFixed(2)}', style: const TextStyle(fontSize: 8, color: Colors.green)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                const Divider(height: 1),
                const SizedBox(height: 6),

                if (influences.isEmpty)
                  const Text('No bone influences recorded for this vertex', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground))
                else
                  ...influences.entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key, style: const TextStyle(fontSize: 9.5, color: EditorColors.foreground)),
                          Text(e.value.toStringAsFixed(3), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.orange)),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ] else
          const Text(
            'Enter a vertex ID above or click the mesh to inspect its local position and bone influence table.',
            style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
          ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
          Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
        ],
      ),
    );
  }
}
