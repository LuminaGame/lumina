import 'dart:async';

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../core/theme/editor_theme.dart';
import '../services/android_devices.dart';

/// The Play on Device section of Play's dropdown: the Android devices and
/// emulators as a tree (Connected devices / Emulators), each with its status
/// dot, name and `Android <version> ("<codename>") | <abi>` line, a loading
/// row while adb answers, "No devices" when there are none, and Refresh.
/// [onChoose] runs the game on the chosen device. Empty without an Android
/// SDK.
List<MenuItem> playOnDeviceMenuItems({required AndroidDeviceList list, required bool runActive, required void Function(AndroidDevice device) onChoose}) {
  if (!list.available) return const [];
  final connected = list.connected;
  final emulators = list.emulators;
  return [
    const MenuDivider(),
    const MenuLabel(
      key: ValueKey('play_on_device_section'),
      leading: Icon(LucideIcons.smartphone, size: 12),
      child: Text('Play on Device', style: TextStyle(fontSize: 10)),
    ),
    if (list.loading)
      const MenuButton(
        key: ValueKey('play_on_device_loading'),
        enabled: false,
        leading: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(size: 10, strokeWidth: 1.5)),
        child: Text('Looking for devices…', style: TextStyle(fontSize: 10)),
      ),
    if (list.error != null && !list.loading)
      MenuButton(
        key: const ValueKey('play_on_device_error'),
        enabled: false,
        child: Text('adb failed: ${list.error}', style: const TextStyle(fontSize: 9, color: EditorColors.destructive)),
      ),
    if (list.loadedOnce && !list.loading && list.error == null && list.devices.isEmpty)
      const MenuButton(
        key: ValueKey('play_on_device_none'),
        enabled: false,
        child: Text('No devices', style: TextStyle(fontSize: 10)),
      ),
    if (connected.isNotEmpty) ...[
      _group('Connected devices', 'play_on_device_group_connected'),
      for (final d in connected) _deviceRow(d, list, runActive, onChoose),
    ],
    if (emulators.isNotEmpty) ...[_group('Emulators', 'play_on_device_group_emulators'), for (final d in emulators) _deviceRow(d, list, runActive, onChoose)],
    MenuButton(
      key: const ValueKey('play_on_device_refresh'),
      enabled: !list.loading,
      autoClose: false,
      leading: const Icon(LucideIcons.refreshCw, size: 12),
      onPressed: (ctx) => unawaited(list.refresh()),
      child: const Text('Refresh', style: TextStyle(fontSize: 10)),
    ),
  ];
}

MenuItem _group(String title, String key) => MenuLabel(
  key: ValueKey(key),
  leading: const Padding(
    padding: EdgeInsets.only(left: 8),
    child: Icon(LucideIcons.chevronDown, size: 10, color: EditorColors.mutedForeground),
  ),
  child: Text(title, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
);

MenuItem _deviceRow(AndroidDevice d, AndroidDeviceList list, bool runActive, void Function(AndroidDevice) onChoose) {
  final hint = d.hint;
  final dot = switch (d.state) {
    AndroidDeviceState.online => const Color(0xFF22C55E),
    AndroidDeviceState.stopped => const Color(0x00000000),
    _ => const Color(0xFFF59E0B),
  };
  return MenuButton(
    key: ValueKey('play_on_device_${d.id}'),
    enabled: d.canRun && !runActive,
    onPressed: (ctx) => onChoose(d),
    leading: Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: ValueKey('play_on_device_dot_${d.id}'),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
              border: d.state == AndroidDeviceState.stopped ? Border.all(color: EditorColors.mutedForeground) : null,
            ),
          ),
          const SizedBox(width: 6),
          Icon(d.isEmulator ? LucideIcons.monitorSmartphone : LucideIcons.smartphone, size: 12),
        ],
      ),
    ),
    trailing: list.lastDeviceId == d.id ? const Icon(LucideIcons.check, size: 12) : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(d.name, style: const TextStyle(fontSize: 10)),
        Text(d.description, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
        if (hint != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(hint, style: const TextStyle(fontSize: 9, color: Color(0xFFF59E0B))),
          ),
      ],
    ),
  );
}
