#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char **dart_entrypoint_arguments;
  // A plugin process's never-shown window (see activate_plugin_process).
  GtkWidget *plugin_process_window;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Whether the editor started this executable to run one isolated plugin's
// process part (`--lumina-plugin-process`, `PluginProcessLaunch.flag` in
// Dart).
static gboolean is_plugin_process(MyApplication *self) {
  for (char **arg = self->dart_entrypoint_arguments; arg != nullptr && *arg;
       arg++) {
    if (g_strcmp0(*arg, "--lumina-plugin-process") == 0) {
      return TRUE;
    }
  }
  return FALSE;
}

// flutter_linux warns on stderr whenever the software renderer is chosen; a
// plugin process chooses it on purpose (activate_plugin_process).
static void skip_software_renderer_warning(const gchar *domain,
                                           GLogLevelFlags level,
                                           const gchar *message,
                                           gpointer user_data) {
  if (message != nullptr &&
      g_str_has_prefix(message, "Using the software renderer")) {
    return;
  }
  g_log_default_handler(domain, level, message, user_data);
}

// A plugin process runs the same Dart entry point (it branches on the flag
// before anything that needs a view) and never draws a frame.
//
// It cannot run without a view: flutter_linux 3.47 exports
// fl_engine_new_headless (a plain fl_engine_new) but not fl_engine_start, and
// the only public path that starts an engine is realizing an FlView inside a
// GtkWindow. An FlView in a GtkOffscreenWindow does start it, but GDK then
// asserts in the engine's monitor lookup (Gdk-CRITICAL on every start, and
// gdk_wayland_display_get_monitor_at_window rejects the window on Wayland).
// So the view is realized in a plain 1x1 toplevel that is never shown: on X11
// an unmapped window that no window manager, taskbar or pager lists; on
// Wayland a surface with no shell role, which no compositor displays. It
// never takes focus.
//
// The engine uses flutter_linux's software renderer: the realized view then
// creates no GDK GL context and no GL compositor (on Mesa that alone is about
// 30 MB and 65 threads per process). No native plugin is registered, as on
// Windows: the editor's (window_manager, media_kit, screen_retriever, mouse
// capture, volume) all serve a visible window, and registering them opens
// audio devices; a process part reaches native code through FFI. The process
// ends when its Dart code calls exit().
static void activate_plugin_process(MyApplication *self) {
  // No GtkApplicationWindow keeps the application running: hold it.
  g_application_hold(G_APPLICATION(self));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  // The engine reads FLUTTER_LINUX_RENDERER once, when the view creates it;
  // the plugin's own child processes inherit the editor's value again.
  g_autofree gchar *previous_renderer =
      g_strdup(g_getenv("FLUTTER_LINUX_RENDERER"));
  g_setenv("FLUTTER_LINUX_RENDERER", "software", TRUE);
  const guint handler = g_log_set_handler(
      nullptr, G_LOG_LEVEL_WARNING, skip_software_renderer_warning, nullptr);
  FlView *view = fl_view_new(project);
  g_log_remove_handler(nullptr, handler);
  if (previous_renderer != nullptr) {
    g_setenv("FLUTTER_LINUX_RENDERER", previous_renderer, TRUE);
  } else {
    g_unsetenv("FLUTTER_LINUX_RENDERER");
  }

  GtkWindow *hidden = GTK_WINDOW(gtk_window_new(GTK_WINDOW_TOPLEVEL));
  gtk_window_set_title(hidden, "lumina_ui plugin process");
  gtk_window_set_default_size(hidden, 1, 1);
  gtk_window_set_skip_taskbar_hint(hidden, TRUE);
  gtk_window_set_skip_pager_hint(hidden, TRUE);
  gtk_window_set_accept_focus(hidden, FALSE);
  self->plugin_process_window = GTK_WIDGET(g_object_ref(hidden));

  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(hidden), GTK_WIDGET(view));
  // Realizing the view realizes the window too (never mapped) and starts the
  // engine.
  gtk_widget_realize(GTK_WIDGET(view));
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication *self, FlView *view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication *application) {
  MyApplication *self = MY_APPLICATION(application);
  if (is_plugin_process(self)) {
    activate_plugin_process(self);
    return;
  }
  GtkWindow *window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = FALSE;
#ifdef GDK_WINDOWING_X11
  GdkScreen *screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar *wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar *header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "lumina_ui");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "lumina_ui");
  }

  gtk_window_set_default_size(window, 1920, 1080);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView *view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication *application,
                                                  gchar ***arguments,
                                                  int *exit_status) {
  MyApplication *self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication *application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication *application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject *object) {
  MyApplication *self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  if (self->plugin_process_window != nullptr) {
    gtk_widget_destroy(self->plugin_process_window);
    g_clear_object(&self->plugin_process_window);
  }
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass *klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication *self) {}

MyApplication *my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
