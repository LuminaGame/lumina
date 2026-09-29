//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <lumina_mouse_capture/lumina_mouse_capture_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) lumina_mouse_capture_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "LuminaMouseCapturePlugin");
  lumina_mouse_capture_plugin_register_with_registrar(lumina_mouse_capture_registrar);
}
