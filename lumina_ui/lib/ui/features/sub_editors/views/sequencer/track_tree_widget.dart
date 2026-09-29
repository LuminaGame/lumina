import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import '../../view_models/sequencer_view_model.dart';
import 'package:lumina_ui/ui/core/widgets/editor_context_menu.dart';

class SequencerTrackTreeWidget extends StatefulWidget {
  final SequencerViewModel viewModel;
  final List<EditorActorNode>? levelActors;

  const SequencerTrackTreeWidget({
    super.key,
    required this.viewModel,
    this.levelActors,
  });

  @override
  State<SequencerTrackTreeWidget> createState() => _SequencerTrackTreeWidgetState();
}

class _SequencerTrackTreeWidgetState extends State<SequencerTrackTreeWidget> {
  String _filterText = '';
  final Set<String> _expandedTrackIds = {};

  Set<String> get _levelActorIds => widget.levelActors?.map((a) => a.id).toSet() ?? {};

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final filteredTracks = vm.tracks.where((t) {
      if (_filterText.isEmpty) return true;
      return t.actorName.toLowerCase().contains(_filterText.toLowerCase()) ||
          t.kind.name.toLowerCase().contains(_filterText.toLowerCase());
    }).toList();

    return Column(
      children: [
        // Outliner Header with Add Track Button
        Container(
          padding: const EdgeInsets.all(8),
          color: EditorColors.card,
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.listTree, size: 12, color: Colors.indigo),
                  const SizedBox(width: 6),
                  const Text(
                    'TRACK OUTLINER',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                  const Spacer(),
                  OutlineButton(
                    size: ButtonSize.small,
                    onPressed: () => _openAddTrackDialog(context),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.plus, size: 10),
                        SizedBox(width: 4),
                        Text('+ Track', style: TextStyle(fontSize: 9)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                placeholder: const Text('Filter tracks...', style: TextStyle(fontSize: 9.5)),
                onChanged: (val) {
                  setState(() => _filterText = val);
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Track Tree List
        Expanded(
          child: filteredTracks.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.film, size: 24, color: EditorColors.mutedForeground),
                        const SizedBox(height: 8),
                        const Text(
                          'No tracks bound yet',
                          style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
                        ),
                        const SizedBox(height: 8),
                        PrimaryButton(
                          size: ButtonSize.small,
                          onPressed: () => _openAddTrackDialog(context),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.plus, size: 11),
                              SizedBox(width: 4),
                              Text('+ Add Track', style: TextStyle(fontSize: 9.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: filteredTracks.length,
                  itemBuilder: (context, index) {
                    final track = filteredTracks[index];
                    final isSelected = vm.selectedTrackId == track.id;
                    final isMissing = widget.levelActors != null && vm.isActorMissing(track.actorId, _levelActorIds);
                    final isExpanded = _expandedTrackIds.contains(track.id) || _expandedTrackIds.isEmpty;

                    return EditorContextMenu(
                      items: [
                        MenuButton(
                          onPressed: (ctx) {
                            if (track.channels.isNotEmpty) {
                              vm.addKey(track.id, track.channels.first.name, vm.playheadFrame, 0.0);
                            }
                          },
                          child: Text(
                            'Add Keyframe at Frame ${vm.playheadFrame}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        MenuButton(
                          onPressed: (ctx) => _openRenameTrackDialog(context, track),
                          child: const Text('Rename Track...', style: TextStyle(fontSize: 10)),
                        ),
                        if (isMissing)
                          MenuButton(
                            onPressed: (ctx) => _openRebindDialog(context, track),
                            child: const Text('Rebind Actor...', style: TextStyle(fontSize: 10, color: Colors.orange)),
                          ),
                        const MenuDivider(),
                        MenuButton(
                          onPressed: (ctx) => _confirmDeleteTrack(track),
                          child: const Text('Delete Track', style: TextStyle(fontSize: 10, color: EditorColors.logError)),
                        ),
                      ],
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.indigo.withValues(alpha: 0.15) : Colors.transparent,
                          border: Border(bottom: BorderSide(color: EditorColors.border.withValues(alpha: 0.5))),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                vm.selectTrack(track.id);
                                setState(() {
                                  if (_expandedTrackIds.contains(track.id)) {
                                    _expandedTrackIds.remove(track.id);
                                  } else {
                                    _expandedTrackIds.add(track.id);
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                child: Row(
                                  children: [
                                    Icon(
                                      isExpanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                                      size: 11,
                                      color: EditorColors.mutedForeground,
                                    ),
                                    const SizedBox(width: 4),
                                    _getTrackKindIcon(track.kind),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        track.actorName,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected ? Colors.indigo : EditorColors.foreground,
                                        ),
                                      ),
                                    ),
                                    if (isMissing) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: EditorColors.logError.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: const Text(
                                          'MISSING',
                                          style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: EditorColors.logError),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      GhostButton(
                                        size: ButtonSize.small,
                                        onPressed: () => _openRebindDialog(context, track),
                                        child: const Icon(LucideIcons.link2, size: 10, color: Colors.orange),
                                      ),
                                    ],
                                    GhostButton(
                                      size: ButtonSize.small,
                                      onPressed: () {
                                        if (track.channels.isNotEmpty) {
                                          vm.addKey(track.id, track.channels.first.name, vm.playheadFrame, 0.0);
                                        }
                                      },
                                      child: const Icon(LucideIcons.plus, size: 11, color: Colors.cyan),
                                    ),
                                    GhostButton(
                                      size: ButtonSize.small,
                                      onPressed: () => _confirmDeleteTrack(track),
                                      child: const Icon(LucideIcons.trash2, size: 11, color: EditorColors.mutedForeground),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isExpanded)
                              ...track.channels.map((channel) {
                                return Container(
                                  padding: const EdgeInsets.only(left: 32, right: 12, top: 4, bottom: 4),
                                  color: EditorColors.background.withValues(alpha: 0.5),
                                  child: Row(
                                    children: [
                                      const Icon(LucideIcons.circleDot, size: 9, color: EditorColors.mutedForeground),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          channel.name,
                                          style: const TextStyle(fontSize: 9, color: EditorColors.foreground),
                                        ),
                                      ),
                                      Text(
                                        '${channel.keys.length} keys',
                                        style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _openAddTrackDialog(BuildContext context) {
    String? selectedActorId;
    String? selectedActorName;
    SequencerTrackKind selectedKind = SequencerTrackKind.transform;
    String propertyName = 'intensity';

    final actors = widget.levelActors ?? [];

    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Actor Track'),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Target Actor:', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
                    const SizedBox(height: 4),
                    if (actors.isNotEmpty)
                      Select<String>(
                        value: selectedActorId ?? actors.first.id,
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedActorId = val;
                              selectedActorName = actors.firstWhere((a) => a.id == val).name;
                            });
                          }
                        },
                        itemBuilder: (context, item) {
                          final a = actors.firstWhere((act) => act.id == item, orElse: () => actors.first);
                          return Text(a.name, style: const TextStyle(fontSize: 9.5));
                        },
                        popup: SelectPopup(
                          items: SelectItemList(
                            children: actors.map((a) {
                              return SelectItemButton(
                                value: a.id,
                                child: Text(a.name),
                              );
                            }).toList(),
                          ),
                        ).call,
                      )
                    else
                      TextField(
                        placeholder: const Text('Enter Actor Name/ID...', style: TextStyle(fontSize: 9.5)),
                        onChanged: (val) {
                          selectedActorId = val;
                          selectedActorName = val;
                        },
                      ),

                    const SizedBox(height: 10),
                    const Text('Track Kind:', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
                    const SizedBox(height: 4),
                    Select<SequencerTrackKind>(
                      value: selectedKind,
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedKind = val);
                        }
                      },
                      itemBuilder: (context, item) => Text(item.name.toUpperCase(), style: const TextStyle(fontSize: 9.5)),
                      popup: const SelectPopup(
                        items: SelectItemList(
                          children: [
                            SelectItemButton(value: SequencerTrackKind.transform, child: Text('Transform (9 Channels)')),
                            SelectItemButton(value: SequencerTrackKind.property, child: Text('Numeric Property')),
                            SelectItemButton(value: SequencerTrackKind.visibility, child: Text('Visibility (Bool)')),
                          ],
                        ),
                      ).call,
                    ),

                    if (selectedKind == SequencerTrackKind.property) ...[
                      const SizedBox(height: 10),
                      const Text('Property Name:', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
                      const SizedBox(height: 4),
                      TextField(
                        initialValue: propertyName,
                        placeholder: const Text('intensity / fieldOfView / etc.', style: TextStyle(fontSize: 9.5)),
                        onChanged: (val) => propertyName = val,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                OutlineButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                PrimaryButton(
                  onPressed: () {
                    final actId = selectedActorId ?? (actors.isNotEmpty ? actors.first.id : 'actor_${DateTime.now().millisecondsSinceEpoch}');
                    final actName = selectedActorName ?? (actors.isNotEmpty ? actors.first.name : actId);
                    widget.viewModel.addTrack(
                      actId,
                      actName,
                      selectedKind,
                      propertyName: selectedKind == SequencerTrackKind.property ? propertyName : null,
                    );
                    Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('Add Track'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openRenameTrackDialog(BuildContext context, SequencerTrack track) {
    String newName = track.actorName;
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Rename Sequencer Track'),
          content: TextField(
            initialValue: track.actorName,
            onChanged: (val) => newName = val,
          ),
          actions: [
            OutlineButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            PrimaryButton(
              onPressed: () {
                if (newName.isNotEmpty) {
                  widget.viewModel.renameTrack(track.id, newName);
                }
                Navigator.of(dialogCtx).pop();
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
  }

  void _openRebindDialog(BuildContext context, SequencerTrack track) {
    final actors = widget.levelActors ?? [];
    if (actors.isEmpty) return;

    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Rebind Track Actor'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: actors.map((a) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlineButton(
                    onPressed: () {
                      widget.viewModel.rebindActor(track.id, a.id, a.name);
                      Navigator.of(dialogCtx).pop();
                    },
                    child: Text(a.name, style: const TextStyle(fontSize: 9.5)),
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            OutlineButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteTrack(SequencerTrack track) {
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Delete Sequencer Track?'),
          content: Text('Are you sure you want to delete track "${track.actorName}" and all its keyframes?'),
          actions: [
            OutlineButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            DestructiveButton(
              onPressed: () {
                widget.viewModel.deleteTrack(track.id);
                Navigator.of(dialogCtx).pop();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Icon _getTrackKindIcon(SequencerTrackKind kind) {
    switch (kind) {
      case SequencerTrackKind.transform:
        return const Icon(LucideIcons.move3d, size: 12, color: Colors.cyan);
      case SequencerTrackKind.property:
        return const Icon(LucideIcons.slidersHorizontal, size: 12, color: Colors.purple);
      case SequencerTrackKind.visibility:
        return const Icon(LucideIcons.eye, size: 12, color: Colors.green);
    }
  }
}
