# Editor graphics device

Open **Edit → Editor Preferences → General › Graphics Device** to choose a Vulkan graphics device. The list contains the devices detected on this machine and **Automatic**. It also shows the device currently used by the renderer.

The selection is saved immediately in `launcher_settings.json` under `graphics_device`, shared with the launcher. Restart the editor to apply it to its render session. Project editor hosts read it before creating their first render engine. An unavailable saved device falls back to automatic selection.

`FILAMENT_GPU` and a numeric `VK_DEVICE_INDEX` take precedence over the saved preference. When either controls selection, the list is disabled and explains the override. Remove the override and restart to use the saved setting.
