import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';

/// The slot button API: a button's live state is a value.
void main() {
  const icon = IconData(0xe000);

  test('copyWith changes only the named field', () {
    const base = EditorButtonState(icon: icon, tooltip: 'AI');
    final active = base.copyWith(active: true);
    expect(active.active, isTrue);
    expect(active.icon, icon);
    expect(active.tooltip, 'AI');
    expect(active.label, isNull);
    expect(active.tone, EditorTone.neutral);
    expect(active.enabled, isTrue);
    expect(active.badge, isNull);
    expect(active.busy, isFalse);
    expect(base.copyWith(label: 'AI', badge: '3').copyWith(busy: true), const EditorButtonState(icon: icon, tooltip: 'AI', label: 'AI', badge: '3', busy: true));
  });

  test('equal fields are equal with equal hash codes; a different badge is not', () {
    const a = EditorButtonState(icon: icon, tooltip: 'AI', tone: EditorTone.warning, badge: '2');
    const b = EditorButtonState(icon: icon, tooltip: 'AI', tone: EditorTone.warning, badge: '2');
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == a.copyWith(badge: '3'), isFalse);
  });

  test('slots resolve by name (EditorToolbarButton.group names a slot)', () {
    expect(EditorSlot.values.byName('statusBarRight'), EditorSlot.statusBarRight);
    expect(EditorSlot.values.map((s) => s.name), ['levelToolbarAfterBlueprints', 'levelToolbarEnd', 'statusBarLeft', 'statusBarRight']);
  });

  test('a slot button carries its slot, order, state, command and optional menu', () {
    final state = ValueNotifier(const EditorButtonState(icon: icon, tooltip: 'AI'));
    final command = EditorCommand(id: 'ai.toggle', label: 'AI', canExecute: () => true, execute: (_) {});
    final button = EditorSlotButton(id: 'ai', slot: EditorSlot.levelToolbarAfterBlueprints, state: state, command: command);
    expect(button.order, 0);
    expect(button.menu, isNull);
    expect(button.state.value.tooltip, 'AI');
  });
}
