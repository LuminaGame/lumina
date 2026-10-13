part of '../details_widget.dart';

/// The Details rows for a short text and for another actor of the level
/// (`PropertyEditorType.text` / `actorReference`).
mixin _DetailsReferenceFields on _DetailsWidgetStateBase {
  /// A text field committed (one undo step) when it is submitted.
  Widget _textPropertyField(EditorActorNode actor, EditorComponentNode comp, PropertyDescriptor prop, Object? value) => TextField(
    key: ValueKey('details_text_${comp.id}_${prop.id}'),
    initialValue: value?.toString() ?? '',
    style: const TextStyle(fontSize: 10),
    onSubmitted: (v) => widget.viewModel.updateComponentPropertyWithTransaction(actor.id, comp.id, prop.id, v.trim()),
  );

  /// A picker over the level's actors of the descriptor's type, without
  /// [actor] and the actors whose same property already leads to it (a
  /// cycle), plus None.
  Widget _actorReferenceField(EditorActorNode actor, EditorComponentNode comp, PropertyDescriptor prop, Object? value) {
    final actors = widget.viewModel.actors;
    final byId = {for (final a in actors) a.id: a};
    String? refOf(EditorActorNode a) =>
        a.components.where((c) => c.type == comp.type).firstOrNull?.properties[prop.id] as String?;
    bool leadsTo(EditorActorNode a) {
      final seen = <String>{};
      for (var ref = refOf(a); ref != null && ref.isNotEmpty && seen.add(ref); ref = byId[ref] == null ? null : refOf(byId[ref]!)) {
        if (ref == actor.id) return true;
      }
      return false;
    }

    final options = [
      for (final a in actors)
        if (a.id != actor.id && (prop.type == null || a.type == prop.type) && !leadsTo(a)) a,
    ];
    final current = value is String && options.any((a) => a.id == value) ? value : '';
    return Select<String>(
      key: ValueKey('details_actor_ref_${comp.id}_${prop.id}'),
      value: current,
      onChanged: (v) => widget.viewModel.updateComponentPropertyWithTransaction(actor.id, comp.id, prop.id, v ?? ''),
      itemBuilder: (context, item) => Text(item.isEmpty ? 'None' : (byId[item]?.name ?? item), style: const TextStyle(fontSize: 10)),
      popup: SelectPopup(
        items: SelectItemList(
          children: [
            const SelectItemButton(value: '', child: Text('None')),
            for (final a in options) SelectItemButton(value: a.id, child: Text(a.name)),
          ],
        ),
      ).call,
    );
  }
}
