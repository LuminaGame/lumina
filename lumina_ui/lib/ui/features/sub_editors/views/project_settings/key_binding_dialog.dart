import 'package:flutter/services.dart';
import 'package:lumina/lumina.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../../core/theme/editor_theme.dart';

/// Supported key categories in the picker.
const List<String> kKeyCategories = [
  'All',
  'Navigation & Controls',
  'Keyboard: Letters',
  'Keyboard: Numbers & Function',
  'Keyboard: Modifiers & System',
  'Keyboard: Numpad',
  'Keyboard: Symbols',
  'Mouse',
  'Gamepad',
];

/// A single selectable key or axis option in the dialog.
class KeyOption {
  final int keyId;
  final String id;
  final String label;
  final String category;
  final IconData icon;
  final List<String> searchTerms;

  const KeyOption({
    required this.keyId,
    required this.id,
    required this.label,
    required this.category,
    required this.icon,
    this.searchTerms = const [],
  });

  bool matches(String query, String categoryFilter) {
    if (categoryFilter != 'All' && category != categoryFilter) return false;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (label.toLowerCase().contains(q)) return true;
    if (id.toLowerCase().contains(q)) return true;
    if (category.toLowerCase().contains(q)) return true;
    for (final term in searchTerms) {
      if (term.toLowerCase().contains(q)) return true;
    }
    return false;
  }
}

/// Helper to categorize a [LuminaKey].
String _luminaKeyCategory(LuminaKey key) {
  final id = key.id;
  if (id.startsWith('Mouse')) return 'Mouse';
  if (id.startsWith('Gamepad')) return 'Gamepad';
  if (id.startsWith('KeyNumpad')) return 'Keyboard: Numpad';
  if (id.startsWith('KeyF') && RegExp(r'^KeyF\d+$').hasMatch(id)) return 'Keyboard: Numbers & Function';
  if (RegExp(r'^Key\d$').hasMatch(id)) return 'Keyboard: Numbers & Function';
  if (RegExp(r'^Key[A-Z]$').hasMatch(id)) return 'Keyboard: Letters';
  if (const [
    'KeyEscape', 'KeySpace', 'KeyEnter', 'KeyTab', 'KeyBackspace',
    'KeyDelete', 'KeyInsert', 'KeyHome', 'KeyEnd', 'KeyPageUp',
    'KeyPageDown', 'KeyArrowUp', 'KeyArrowDown', 'KeyArrowLeft', 'KeyArrowRight',
  ].contains(id)) {
    return 'Navigation & Controls';
  }
  if (const [
    'KeyLeftShift', 'KeyRightShift', 'KeyLeftControl', 'KeyRightControl',
    'KeyLeftAlt', 'KeyRightAlt', 'KeyLeftMeta', 'KeyRightMeta',
    'KeyCapsLock', 'KeyNumLock', 'KeyScrollLock', 'KeyPrintScreen',
    'KeyPause', 'KeyContextMenu',
  ].contains(id)) {
    return 'Keyboard: Modifiers & System';
  }
  return 'Keyboard: Symbols';
}

/// Helper to return a friendly user-facing label for a [LuminaKey].
String _luminaKeyLabel(LuminaKey key) {
  final id = key.id;
  if (RegExp(r'^Key[A-Z]$').hasMatch(id)) return id.substring(3);
  if (RegExp(r'^Key\d$').hasMatch(id)) return id.substring(3);
  if (RegExp(r'^KeyF\d+$').hasMatch(id)) return id.substring(3);
  return switch (id) {
    'KeyEscape' => 'Escape',
    'KeySpace' => 'Space',
    'KeyEnter' => 'Enter',
    'KeyTab' => 'Tab',
    'KeyBackspace' => 'Backspace',
    'KeyDelete' => 'Delete',
    'KeyInsert' => 'Insert',
    'KeyHome' => 'Home',
    'KeyEnd' => 'End',
    'KeyPageUp' => 'Page Up',
    'KeyPageDown' => 'Page Down',
    'KeyArrowUp' => 'Arrow Up',
    'KeyArrowDown' => 'Arrow Down',
    'KeyArrowLeft' => 'Arrow Left',
    'KeyArrowRight' => 'Arrow Right',
    'KeyLeftShift' => 'Left Shift',
    'KeyRightShift' => 'Right Shift',
    'KeyLeftControl' => 'Left Ctrl',
    'KeyRightControl' => 'Right Ctrl',
    'KeyLeftAlt' => 'Left Alt',
    'KeyRightAlt' => 'Right Alt',
    'KeyLeftMeta' => 'Left Meta (Win/Cmd)',
    'KeyRightMeta' => 'Right Meta (Win/Cmd)',
    'KeyCapsLock' => 'Caps Lock',
    'KeyNumLock' => 'Num Lock',
    'KeyScrollLock' => 'Scroll Lock',
    'KeyPrintScreen' => 'Print Screen',
    'KeyPause' => 'Pause',
    'KeyContextMenu' => 'Context Menu',
    'KeyNumpad0' => 'Numpad 0',
    'KeyNumpad1' => 'Numpad 1',
    'KeyNumpad2' => 'Numpad 2',
    'KeyNumpad3' => 'Numpad 3',
    'KeyNumpad4' => 'Numpad 4',
    'KeyNumpad5' => 'Numpad 5',
    'KeyNumpad6' => 'Numpad 6',
    'KeyNumpad7' => 'Numpad 7',
    'KeyNumpad8' => 'Numpad 8',
    'KeyNumpad9' => 'Numpad 9',
    'KeyNumpadAdd' => 'Numpad Add (+)',
    'KeyNumpadSubtract' => 'Numpad Subtract (-)',
    'KeyNumpadMultiply' => 'Numpad Multiply (*)',
    'KeyNumpadDivide' => 'Numpad Divide (/)',
    'KeyNumpadDecimal' => 'Numpad Decimal (.)',
    'KeyNumpadEnter' => 'Numpad Enter',
    'KeyNumpadEqual' => 'Numpad Equal (=)',
    'KeyNumpadComma' => 'Numpad Comma (,)',
    'KeyMinus' => 'Minus (-)',
    'KeyEqual' => 'Equal (=)',
    'KeyBracketLeft' => 'Bracket Left ([)',
    'KeyBracketRight' => 'Bracket Right (])',
    'KeyBackslash' => r'Backslash (\)',
    'KeySemicolon' => 'Semicolon (;)',
    'KeyQuote' => "Quote (')",
    'KeyBackquote' => 'Backquote (`)',
    'KeyComma' => 'Comma (,)',
    'KeyPeriod' => 'Period (.)',
    'KeySlash' => 'Slash (/)',
    'KeyIntlBackslash' => r'Intl Backslash (\)',
    'MouseLeft' => 'Mouse Left',
    'MouseRight' => 'Mouse Right',
    'MouseMiddle' => 'Mouse Middle',
    'MouseThumb1' => 'Mouse Thumb 1',
    'MouseThumb2' => 'Mouse Thumb 2',
    'MouseX' => 'Mouse X (Axis)',
    'MouseY' => 'Mouse Y (Axis)',
    'GamepadFaceButtonBottom' => 'Gamepad Face Button Bottom (A/Cross)',
    'GamepadFaceButtonRight' => 'Gamepad Face Button Right (B/Circle)',
    'GamepadLeftThumbstick' => 'Gamepad Left Thumbstick',
    'GamepadRightThumbstick' => 'Gamepad Right Thumbstick',
    'GamepadLeftStickX' => 'Gamepad Left Stick X (Axis)',
    'GamepadLeftStickY' => 'Gamepad Left Stick Y (Axis)',
    _ => id,
  };
}

/// Helper to return search aliases for a key.
List<String> _luminaKeySearchTerms(LuminaKey key) {
  return switch (key.id) {
    'KeyEscape' => ['esc', 'escape', 'cancel'],
    'KeyEnter' => ['return', 'enter'],
    'KeySpace' => ['space', 'spacebar'],
    'KeyLeftShift' => ['shift', 'left shift', 'lshift'],
    'KeyRightShift' => ['shift', 'right shift', 'rshift'],
    'KeyLeftControl' => ['ctrl', 'control', 'left ctrl', 'lctrl'],
    'KeyRightControl' => ['ctrl', 'control', 'right ctrl', 'rctrl'],
    'KeyLeftAlt' => ['alt', 'left alt', 'lalt', 'option'],
    'KeyRightAlt' => ['alt', 'right alt', 'ralt', 'alt gr'],
    'KeyLeftMeta' => ['win', 'windows', 'cmd', 'command', 'meta', 'super'],
    'KeyRightMeta' => ['win', 'windows', 'cmd', 'command', 'meta', 'super'],
    'KeyDelete' => ['del', 'delete'],
    'KeyBackspace' => ['backspace', 'bksp'],
    'MouseLeft' => ['click', 'left click', 'lmb'],
    'MouseRight' => ['right click', 'rmb'],
    'MouseMiddle' => ['middle click', 'wheel click', 'mmb'],
    'GamepadFaceButtonBottom' => ['a', 'cross', 'bottom'],
    'GamepadFaceButtonRight' => ['b', 'circle', 'right'],
    _ => const [],
  };
}

IconData _luminaKeyIcon(LuminaKey key, String cat) {
  if (cat == 'Mouse') return key.isAnalog ? LucideIcons.move : LucideIcons.mouse;
  if (cat == 'Gamepad') return LucideIcons.gamepad2;
  return switch (key.id) {
    'KeyEscape' => LucideIcons.undo2,
    'KeyArrowUp' => LucideIcons.arrowUp,
    'KeyArrowDown' => LucideIcons.arrowDown,
    'KeyArrowLeft' => LucideIcons.arrowLeft,
    'KeyArrowRight' => LucideIcons.arrowRight,
    'KeyEnter' => LucideIcons.cornerDownLeft,
    'KeyBackspace' || 'KeyDelete' => LucideIcons.delete,
    'KeySpace' => LucideIcons.space,
    _ => LucideIcons.keyboard,
  };
}

int _categoryRank(String cat) => switch (cat) {
  'Navigation & Controls' => 1,
  'Keyboard: Letters' => 2,
  'Keyboard: Numbers & Function' => 3,
  'Keyboard: Modifiers & System' => 4,
  'Mouse' => 5,
  'Gamepad' => 6,
  'Keyboard: Numpad' => 7,
  'Keyboard: Symbols' => 8,
  _ => 9,
};

/// Precomputed catalog of all supported key options.
final List<KeyOption> kAllKeyOptions = () {
  final list = <KeyOption>[];
  for (final k in LuminaKey.values) {
    if (k.keyId == null) continue;
    final cat = _luminaKeyCategory(k);
    list.add(KeyOption(
      keyId: k.keyId!,
      id: k.id,
      label: _luminaKeyLabel(k),
      category: cat,
      icon: _luminaKeyIcon(k, cat),
      searchTerms: _luminaKeySearchTerms(k),
    ));
  }
  list.sort((a, b) {
    final rankA = _categoryRank(a.category);
    final rankB = _categoryRank(b.category);
    if (rankA != rankB) return rankA.compareTo(rankB);
    return a.label.compareTo(b.label);
  });
  return List<KeyOption>.unmodifiable(list);
}();

/// Resolves a pressed [LogicalKeyboardKey] to a canonical (keyId, label).
({int keyId, String label}) resolveKeyFromLogical(LogicalKeyboardKey key) {
  final lk = LuminaKey.fromKeyId(key.keyId);
  if (lk != null) {
    return (keyId: lk.keyId!, label: _luminaKeyLabel(lk));
  }
  final label = key.keyLabel.isNotEmpty ? key.keyLabel : (key.debugName ?? 'Key ${key.keyId}');
  return (keyId: key.keyId, label: label);
}

/// Modal dialog allowing users to bind an input key either by pressing any key
/// (including Escape, Space, Enter, etc.) or by selecting from a categorized
/// search Combobox / quick-pick list.
class KeyBindingDialog extends StatefulWidget {
  final int? initialKeyId;
  final String initialKeyLabel;
  final void Function(int keyId, String keyLabel) onKeySelected;
  final VoidCallback onClose;

  const KeyBindingDialog({
    super.key,
    this.initialKeyId,
    this.initialKeyLabel = '',
    required this.onKeySelected,
    required this.onClose,
  });

  @override
  State<KeyBindingDialog> createState() => _KeyBindingDialogState();
}

class _KeyBindingDialogState extends State<KeyBindingDialog> {
  late int? _selectedKeyId;
  late String _selectedKeyLabel;
  bool _isListening = true;

  final FocusNode _captureFocus = FocusNode(debugLabel: 'key_binding_capture_focus');
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _selectedKeyId = widget.initialKeyId;
    _selectedKeyLabel = widget.initialKeyLabel;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isListening) {
        _captureFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _captureFocus.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<KeyOption> get _filteredOptions {
    final query = _searchController.text;
    return kAllKeyOptions.where((opt) => opt.matches(query, _selectedCategory)).toList();
  }

  void _onKeyPressed(LogicalKeyboardKey key) {
    final resolved = resolveKeyFromLogical(key);
    setState(() {
      _selectedKeyId = resolved.keyId;
      _selectedKeyLabel = resolved.label;
      _isListening = false;
    });
  }

  void _confirmSelection() {
    if (_selectedKeyId != null) {
      widget.onKeySelected(_selectedKeyId!, _selectedKeyLabel);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOptions;
    final currentOption = _selectedKeyId != null
        ? kAllKeyOptions.cast<KeyOption?>().firstWhere((o) => o?.keyId == _selectedKeyId, orElse: () => null)
        : null;
    final currentIcon = currentOption?.icon ?? LucideIcons.keyboard;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 540, maxHeight: 600),
      child: AlertDialog(
        key: const ValueKey('key_binding_dialog'),
        title: Row(
          children: [
            const Icon(LucideIcons.keyboard, size: 18),
            const SizedBox(width: 8),
            const Text('Key Binding', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Spacer(),
            GhostButton(
              key: const ValueKey('key_binding_dialog_close_x'),
              density: ButtonDensity.icon,
              onPressed: widget.onClose,
              child: const Icon(LucideIcons.x, size: 14),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Current Selection Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: EditorColors.cardHeader,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: EditorColors.border),
                ),
                child: Row(
                  children: [
                    const Text('Selected Key: ', style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
                    Container(
                      key: const ValueKey('key_binding_selected_preview'),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: EditorColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: EditorColors.primary),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(currentIcon, size: 13, color: EditorColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            _selectedKeyLabel.isEmpty ? 'None' : _selectedKeyLabel,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EditorColors.foreground),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedKeyId != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'ID: 0x${_selectedKeyId!.toRadixString(16)}',
                        style: const TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 2. Interactive "Press a Key" Section
              Focus(
                key: const ValueKey('key_binding_press_focus'),
                focusNode: _captureFocus,
                onKeyEvent: (node, event) {
                  if (!_isListening || event is! KeyDownEvent) return KeyEventResult.ignored;
                  _onKeyPressed(event.logicalKey);
                  return KeyEventResult.handled;
                },
                child: GestureDetector(
                  onTap: () {
                    setState(() => _isListening = true);
                    _captureFocus.requestFocus();
                  },
                  child: Container(
                    key: const ValueKey('key_binding_press_box'),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _isListening ? EditorColors.primary.withValues(alpha: 0.08) : EditorColors.cardHeader,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _isListening ? EditorColors.primary : EditorColors.border,
                        width: _isListening ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isListening ? LucideIcons.radio : LucideIcons.keyboard,
                          size: 18,
                          color: _isListening ? EditorColors.primary : EditorColors.mutedForeground,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isListening ? 'Listening for key… Press ANY key now' : 'Click here and press any key',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: _isListening ? FontWeight.bold : FontWeight.normal,
                                  color: _isListening ? EditorColors.primary : EditorColors.foreground,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isListening
                                    ? 'Press Escape, Space, Enter, or any other key to assign'
                                    : 'Pressing a key will instantly select it for this binding',
                                style: const TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground),
                              ),
                            ],
                          ),
                        ),
                        if (_isListening)
                          OutlineButton(
                            key: const ValueKey('key_binding_stop_listening'),
                            density: ButtonDensity.compact,
                            onPressed: () => setState(() => _isListening = false),
                            child: const Text('Stop', style: TextStyle(fontSize: 9.5)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 3. Search & Filter Bar
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Category', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
                        const SizedBox(height: 4),
                        Select<String>(
                          key: const ValueKey('key_binding_category_select'),
                          value: _selectedCategory,
                          onChanged: (cat) {
                            if (cat != null) setState(() => _selectedCategory = cat);
                          },
                          itemBuilder: (context, cat) => Text(cat, style: const TextStyle(fontSize: 10)),
                          popup: SelectPopup(
                            items: SelectItemList(
                              children: [
                                for (final cat in kKeyCategories)
                                  SelectItemButton(value: cat, child: Text(cat, style: const TextStyle(fontSize: 10))),
                              ],
                            ),
                          ).call,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Search', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
                        const SizedBox(height: 4),
                        TextField(
                          key: const ValueKey('key_binding_search_field'),
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          placeholder: const Text('Search keys (e.g. Escape, W, Mouse…)'),
                          features: [
                            const InputFeature.leading(Icon(LucideIcons.search, size: 12)),
                            if (_searchController.text.isNotEmpty)
                              InputFeature.trailing(
                                GhostButton(
                                  density: ButtonDensity.icon,
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                  child: const Icon(LucideIcons.x, size: 11),
                                ),
                              ),
                          ],
                          onChanged: (_) {
                            if (_isListening) setState(() => _isListening = false);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 4. Combobox Dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Key Combobox', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
                  const SizedBox(height: 4),
                  Select<int>(
                    key: const ValueKey('key_binding_combobox'),
                    value: filtered.any((o) => o.keyId == _selectedKeyId) ? _selectedKeyId : null,
                    placeholder: const Text('Select a key from combobox…', style: TextStyle(fontSize: 10.5)),
                    onChanged: (id) {
                      if (id != null) {
                        final opt = kAllKeyOptions.firstWhere((o) => o.keyId == id);
                        setState(() {
                          _selectedKeyId = opt.keyId;
                          _selectedKeyLabel = opt.label;
                          _isListening = false;
                        });
                      }
                    },
                    itemBuilder: (context, id) {
                      final opt = kAllKeyOptions.firstWhere((o) => o.keyId == id);
                      return Row(
                        children: [
                          Icon(opt.icon, size: 12),
                          const SizedBox(width: 6),
                          Text(opt.label, style: const TextStyle(fontSize: 10.5)),
                          const Spacer(),
                          Text(opt.category, style: const TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground)),
                        ],
                      );
                    },
                    popup: SelectPopup(
                      items: SelectItemList(
                        children: [
                          for (final opt in filtered)
                            SelectItemButton(
                              value: opt.keyId,
                              child: Row(
                                children: [
                                  Icon(opt.icon, size: 12),
                                  const SizedBox(width: 6),
                                  Text(opt.label, style: const TextStyle(fontSize: 10.5)),
                                  const Spacer(),
                                  Text(opt.category, style: const TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ).call,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 5. Scrollable Quick-Pick List
              Text('Quick Select (${filtered.length} matches)', style: const TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
              const SizedBox(height: 4),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: EditorColors.border),
                  borderRadius: BorderRadius.circular(4),
                  color: EditorColors.cardHeader,
                ),
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('No keys match the search criteria', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                      )
                    : ListView.builder(
                        key: const ValueKey('key_binding_quick_pick_list'),
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) {
                          final opt = filtered[idx];
                          final isSelected = opt.keyId == _selectedKeyId;
                          return Clickable(
                            key: ValueKey('key_binding_option_${opt.keyId}'),
                            onPressed: () {
                              setState(() {
                                _selectedKeyId = opt.keyId;
                                _selectedKeyLabel = opt.label;
                                _isListening = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              color: isSelected ? EditorColors.primary.withValues(alpha: 0.18) : Colors.transparent,
                              child: Row(
                                children: [
                                  Icon(
                                    opt.icon,
                                    size: 13,
                                    color: isSelected ? EditorColors.primary : EditorColors.foreground,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    opt.label,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? EditorColors.primary : EditorColors.foreground,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    opt.category,
                                    style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          OutlineButton(
            key: const ValueKey('key_binding_cancel'),
            onPressed: widget.onClose,
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            key: const ValueKey('key_binding_assign'),
            enabled: _selectedKeyId != null,
            onPressed: _selectedKeyId != null ? _confirmSelection : null,
            child: const Text('Assign Key'),
          ),
        ],
      ),
    );
  }
}
