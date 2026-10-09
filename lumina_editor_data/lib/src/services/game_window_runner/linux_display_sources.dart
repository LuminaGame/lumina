/// The Linux runner's display part of `lumina_window_mode.cc`: the monitors
/// (GdkMonitor), the window's client size and its monitor.
/// `GameWindowRunnerService` puts it in place of `{{DISPLAY}}` in
/// [kLinuxWindowModeSource] (`linux_sources.dart`), so it uses that file's
/// globals.
///
/// GDK has no list of display modes: each monitor reports its current mode
/// only (X11 and Wayland alike). Wayland does not let a client place its
/// window, so a resize there is not centred.
library;

const String kLinuxDisplaySource = r'''
// --- Displays: monitors, client size, monitor moves ------------------------
//
// Channel methods: getDisplays → {monitors: [{name, device, primary, bounds,
// work, current: [w, h, hz], modes: [current], scale}], current, client:
// [w, h]} (device pixels); setClientSize {width, height} → [w, h];
// moveToMonitor {index} → bool. Calls displayChanged when monitors change.

static FlValue* rect_value(const GdkRectangle* r, gint scale) {
  FlValue* list = fl_value_new_list();
  fl_value_append_take(list, fl_value_new_int(r->x * scale));
  fl_value_append_take(list, fl_value_new_int(r->y * scale));
  fl_value_append_take(list, fl_value_new_int((r->x + r->width) * scale));
  fl_value_append_take(list, fl_value_new_int((r->y + r->height) * scale));
  return list;
}

static FlValue* mode_value(gint width, gint height, gint hz) {
  FlValue* list = fl_value_new_list();
  fl_value_append_take(list, fl_value_new_int(width));
  fl_value_append_take(list, fl_value_new_int(height));
  fl_value_append_take(list, fl_value_new_int(hz));
  return list;
}

static FlValue* monitor_value(GdkMonitor* monitor, gint index) {
  GdkRectangle bounds;
  GdkRectangle work;
  gdk_monitor_get_geometry(monitor, &bounds);
  gdk_monitor_get_workarea(monitor, &work);
  const gint scale = gdk_monitor_get_scale_factor(monitor);
  const gint hz = (gdk_monitor_get_refresh_rate(monitor) + 500) / 1000;
  const gchar* model = gdk_monitor_get_model(monitor);
  const gchar* maker = gdk_monitor_get_manufacturer(monitor);
  g_autofree gchar* name = model != nullptr && maker != nullptr
                               ? g_strdup_printf("%s %s", maker, model)
                               : g_strdup(model != nullptr ? model : "");
  g_autofree gchar* device = g_strdup_printf("%s#%d", model != nullptr ? model : "monitor", index);
  FlValue* value = fl_value_new_map();
  fl_value_set_string_take(value, "name", fl_value_new_string(name));
  fl_value_set_string_take(value, "device", fl_value_new_string(device));
  fl_value_set_string_take(value, "primary", fl_value_new_bool(gdk_monitor_is_primary(monitor)));
  fl_value_set_string_take(value, "bounds", rect_value(&bounds, scale));
  fl_value_set_string_take(value, "work", rect_value(&work, scale));
  fl_value_set_string_take(value, "current",
                           mode_value(bounds.width * scale, bounds.height * scale, hz));
  FlValue* modes = fl_value_new_list();
  fl_value_append_take(modes, mode_value(bounds.width * scale, bounds.height * scale, hz));
  fl_value_set_string_take(value, "modes", modes);
  fl_value_set_string_take(value, "scale", fl_value_new_float(scale));
  return value;
}

static FlValue* client_value() {
  gint width = 0;
  gint height = 0;
  gtk_window_get_size(g_window, &width, &height);
  const gint scale = gtk_widget_get_scale_factor(GTK_WIDGET(g_window));
  FlValue* list = fl_value_new_list();
  fl_value_append_take(list, fl_value_new_int(width * scale));
  fl_value_append_take(list, fl_value_new_int(height * scale));
  return list;
}

static GdkMonitor* window_monitor() {
  GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(g_window));
  GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(g_window));
  if (gdk_window != nullptr) return gdk_display_get_monitor_at_window(display, gdk_window);
  return gdk_display_get_primary_monitor(display);
}

static FlValue* displays_value() {
  GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(g_window));
  GdkMonitor* mine = window_monitor();
  const gint count = gdk_display_get_n_monitors(display);
  FlValue* monitors = fl_value_new_list();
  gint current = 0;
  for (gint i = 0; i < count; ++i) {
    GdkMonitor* monitor = gdk_display_get_monitor(display, i);
    if (monitor == mine) current = i;
    fl_value_append_take(monitors, monitor_value(monitor, i));
  }
  FlValue* value = fl_value_new_map();
  fl_value_set_string_take(value, "monitors", monitors);
  fl_value_set_string_take(value, "current", fl_value_new_int(current));
  fl_value_set_string_take(value, "client", client_value());
  return value;
}

static gint64 int_arg(FlValue* args, const char* key, gint64 fallback) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) return fallback;
  FlValue* v = fl_value_lookup_string(args, key);
  if (v == nullptr) return fallback;
  if (fl_value_get_type(v) == FL_VALUE_TYPE_INT) return fl_value_get_int(v);
  if (fl_value_get_type(v) == FL_VALUE_TYPE_FLOAT) return (gint64)fl_value_get_float(v);
  return fallback;
}

// Windowed: the window's size in logical pixels for width × height device
// pixels, clamped to the work area and centred on it (X11; Wayland places
// windows itself).
static FlValue* set_client_size(gint64 width, gint64 height) {
  if (!g_fullscreen) {
    gtk_window_unmaximize(g_window);
    GdkRectangle work;
    gdk_monitor_get_workarea(window_monitor(), &work);
    const gint scale = gtk_widget_get_scale_factor(GTK_WIDGET(g_window));
    const gint w = MAX(1, MIN((gint)(width / scale), work.width));
    const gint h = MAX(1, MIN((gint)(height / scale), work.height));
    gtk_window_resize(g_window, w, h);
    gtk_window_move(g_window, work.x + (work.width - w) / 2, work.y + (work.height - h) / 2);
    const gint scale_now = gtk_widget_get_scale_factor(GTK_WIDGET(g_window));
    FlValue* list = fl_value_new_list();
    fl_value_append_take(list, fl_value_new_int(w * scale_now));
    fl_value_append_take(list, fl_value_new_int(h * scale_now));
    return list;
  }
  return client_value();
}

static gboolean move_to_monitor(gint64 index) {
  GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(g_window));
  if (index < 0 || index >= gdk_display_get_n_monitors(display)) return FALSE;
  if (g_fullscreen) {
    gtk_window_fullscreen_on_monitor(g_window, gtk_widget_get_screen(GTK_WIDGET(g_window)),
                                     (gint)index);
    return TRUE;
  }
  GdkRectangle work;
  gdk_monitor_get_workarea(gdk_display_get_monitor(display, (gint)index), &work);
  gint w = 0;
  gint h = 0;
  gtk_window_get_size(g_window, &w, &h);
  gtk_window_move(g_window, work.x + (work.width - w) / 2, work.y + (work.height - h) / 2);
  return TRUE;
}

static void notify_display_changed() {
  if (g_channel == nullptr || g_window == nullptr) return;
  g_autoptr(FlValue) args = displays_value();
  fl_method_channel_invoke_method(g_channel, "displayChanged", args, nullptr,
                                  nullptr, nullptr);
}

static void monitors_changed_cb(GdkDisplay* display, GdkMonitor* monitor,
                                gpointer user_data) {
  notify_display_changed();
}

// The display methods; null for any other method.
static FlMethodResponse* handle_display_call(const gchar* method, FlValue* args) {
  if (strcmp(method, "getDisplays") == 0) {
    g_autoptr(FlValue) result = displays_value();
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }
  if (strcmp(method, "setClientSize") == 0) {
    g_autoptr(FlValue) result =
        set_client_size(int_arg(args, "width", 0), int_arg(args, "height", 0));
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }
  if (strcmp(method, "moveToMonitor") == 0) {
    g_autoptr(FlValue) result = fl_value_new_bool(move_to_monitor(int_arg(args, "index", -1)));
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }
  return nullptr;
}

static void watch_displays() {
  GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(g_window));
  g_signal_connect(display, "monitor-added", G_CALLBACK(monitors_changed_cb), nullptr);
  g_signal_connect(display, "monitor-removed", G_CALLBACK(monitors_changed_cb), nullptr);
}
''';
