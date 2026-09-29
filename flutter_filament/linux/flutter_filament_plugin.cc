#include "include/flutter_filament/flutter_filament_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#define FLUTTER_FILAMENT_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), flutter_filament_plugin_get_type(), \
                              FlutterFilamentPlugin))

struct _FlutterFilamentPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(FlutterFilamentPlugin, flutter_filament_plugin, G_TYPE_OBJECT)

static void flutter_filament_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(flutter_filament_plugin_parent_class)->dispose(object);
}

static void flutter_filament_plugin_class_init(FlutterFilamentPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = flutter_filament_plugin_dispose;
}

static void flutter_filament_plugin_init(FlutterFilamentPlugin* self) {}

void flutter_filament_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  FlutterFilamentPlugin* plugin = FLUTTER_FILAMENT_PLUGIN(
      g_object_new(flutter_filament_plugin_get_type(), nullptr));
  g_object_unref(plugin);
}
