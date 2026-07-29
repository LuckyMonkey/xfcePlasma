#include <gtk/gtk.h>
#include <glib/gstdio.h>

#ifndef XFCE_PLASMA_VERSION
#define XFCE_PLASMA_VERSION "unknown"
#endif

#define SHORTCUT_COUNT 6

typedef struct SettingsApp {
    GtkWidget *window;
    GtkWidget *message;
    GtkComboBoxText *wallpaper_combo;
    GtkComboBoxText *speed_combo;
    GtkFileChooser *shader_chooser;
    GtkWidget *wallpaper_state;
    GtkWidget *speed_state;
    GtkWidget *game_state;
    GtkWidget *picom_state;
    GtkWidget *desktop_state;
    GtkWidget *monitor_state;
    GtkTextBuffer *shader_source;
    GtkTextBuffer *diagnostics;
    GtkWidget *shortcut_entries[SHORTCUT_COUNT];
} SettingsApp;

static const gchar *shortcut_actions[SHORTCUT_COUNT] = {
    "wallpaper-prev", "wallpaper-next", "speed-up", "speed-down",
    "stop-wallpaper", "open-settings"
};
static const gchar *shortcut_labels[SHORTCUT_COUNT] = {
    "Previous wallpaper", "Next wallpaper", "Faster animation",
    "Slower animation", "Emergency wallpaper stop", "Open settings"
};

static gchar *control_path(void) {
    const gchar *configured = g_getenv("XFCE_PLASMA_SETTINGS_COMMAND");
    if (configured && *configured) return g_strdup(configured);
    return g_build_filename(g_get_home_dir(), ".local", "bin",
                            "xfce-plasma-settings", NULL);
}

static gboolean run_control(const gchar *first, const gchar *second,
                            const gchar *third, const gchar *fourth,
                            gchar **output, gchar **error_output) {
    gchar *control = control_path();
    gchar *argv[7];
    gchar *standard_output = NULL;
    gchar *standard_error = NULL;
    GError *error = NULL;
    gint wait_status = 0;
    guint index = 0;

    argv[index++] = control;
    if (first) argv[index++] = (gchar *)first;
    if (second) argv[index++] = (gchar *)second;
    if (third) argv[index++] = (gchar *)third;
    if (fourth) argv[index++] = (gchar *)fourth;
    argv[index] = NULL;

    gboolean spawned = g_spawn_sync(NULL, argv, NULL, G_SPAWN_DEFAULT, NULL,
                                    NULL, &standard_output, &standard_error,
                                    &wait_status, &error);
    gboolean succeeded = spawned && g_spawn_check_wait_status(wait_status, &error);
    if (output) *output = standard_output ? standard_output : g_strdup("");
    else g_free(standard_output);
    if (error_output) {
        if (standard_error && *standard_error) {
            *error_output = standard_error;
        } else if (error) {
            *error_output = g_strdup(error->message);
            g_free(standard_error);
        } else {
            *error_output = standard_error ? standard_error : g_strdup("");
        }
    } else g_free(standard_error);
    g_clear_error(&error);
    g_free(control);
    return succeeded;
}

static gchar *capture_control(const gchar *first, const gchar *second,
                              const gchar *third, const gchar *fourth) {
    gchar *output = NULL;
    gchar *error = NULL;
    if (!run_control(first, second, third, fourth, &output, &error)) {
        g_free(output);
        output = error;
    } else g_free(error);
    return g_strstrip(output);
}

static void set_message(SettingsApp *app, const gchar *message) {
    gtk_label_set_text(GTK_LABEL(app->message), message ? message : "");
}

static void load_selected_shader(SettingsApp *app) {
    gchar *name = gtk_combo_box_text_get_active_text(app->wallpaper_combo);
    if (!name) return;
    gchar *source = capture_control("wallpaper", "read", name, NULL);
    gtk_text_buffer_set_text(app->shader_source, source, -1);
    g_free(source);
    g_free(name);
}

static void wallpaper_changed(GtkComboBox *box, gpointer data) {
    (void)box;
    load_selected_shader(data);
}

static void refresh_wallpapers(SettingsApp *app) {
    gchar *selected = gtk_combo_box_text_get_active_text(app->wallpaper_combo);
    gchar *list = capture_control("wallpaper", "list", NULL, NULL);
    gchar *current = capture_control("wallpaper", "current", NULL, NULL);
    gchar **names = g_strsplit(list, "\n", -1);
    gtk_combo_box_text_remove_all(app->wallpaper_combo);
    for (guint index = 0; names[index]; index++) {
        if (*names[index]) gtk_combo_box_text_append(app->wallpaper_combo, names[index], names[index]);
    }
    const gchar *wanted = selected && *selected ? selected : current;
    if (!gtk_combo_box_set_active_id(GTK_COMBO_BOX(app->wallpaper_combo), wanted))
        gtk_combo_box_set_active(GTK_COMBO_BOX(app->wallpaper_combo), 0);
    gtk_label_set_text(GTK_LABEL(app->wallpaper_state), current);
    g_strfreev(names);
    g_free(selected);
    g_free(current);
    g_free(list);
}

static void refresh_shortcuts(SettingsApp *app) {
    for (guint index = 0; index < SHORTCUT_COUNT; index++) {
        gchar *value = capture_control("shortcuts", "get", shortcut_actions[index], NULL);
        gtk_entry_set_text(GTK_ENTRY(app->shortcut_entries[index]), value);
        g_free(value);
    }
}

static void refresh_status(SettingsApp *app) {
    gchar *speed = capture_control("speed", "current", NULL, NULL);
    gchar *game = capture_control("game", "status", NULL, NULL);
    gchar *picom = capture_control("picom", "status", NULL, NULL);
    gchar *desktop = capture_control("desktop", "status", NULL, NULL);
    gchar *monitors = capture_control("monitors", "status", NULL, NULL);
    gtk_label_set_text(GTK_LABEL(app->speed_state), speed);
    gtk_label_set_text(GTK_LABEL(app->game_state), game);
    gtk_label_set_text(GTK_LABEL(app->picom_state), picom);
    gtk_label_set_text(GTK_LABEL(app->desktop_state), desktop);
    gtk_label_set_text(GTK_LABEL(app->monitor_state), monitors);
    g_free(monitors); g_free(desktop); g_free(picom); g_free(game); g_free(speed);
}

static void refresh_all(SettingsApp *app) {
    refresh_wallpapers(app);
    refresh_shortcuts(app);
    refresh_status(app);
}

static void report_action(SettingsApp *app, gboolean succeeded,
                          gchar *output, gchar *error) {
    gchar *text = succeeded ? output : error;
    set_message(app, text && *text ? g_strstrip(text) : (succeeded ? "Done" : "Action failed"));
    g_free(error); g_free(output);
    refresh_all(app);
}

static void wallpaper_apply(GtkButton *button, gpointer data) {
    (void)button;
    SettingsApp *app = data;
    gchar *name = gtk_combo_box_text_get_active_text(app->wallpaper_combo);
    if (!name) return;
    gchar *output = NULL, *error = NULL;
    gboolean ok = run_control("wallpaper", "set", name, NULL, &output, &error);
    report_action(app, ok, output, error);
    g_free(name);
}

static void wallpaper_relative(GtkButton *button, gpointer data) {
    SettingsApp *app = data;
    const gchar *action = g_object_get_data(G_OBJECT(button), "action");
    gchar *output = NULL, *error = NULL;
    gboolean ok = run_control("wallpaper", action, NULL, NULL, &output, &error);
    report_action(app, ok, output, error);
}

static void wallpaper_import(GtkButton *button, gpointer data) {
    (void)button;
    SettingsApp *app = data;
    gchar *filename = gtk_file_chooser_get_filename(app->shader_chooser);
    if (!filename) { set_message(app, "Choose a .fs shader first"); return; }
    gchar *output = NULL, *error = NULL;
    gboolean ok = run_control("wallpaper", "user-add", filename, NULL, &output, &error);
    report_action(app, ok, output, error);
    g_free(filename);
}

static void shader_reload(GtkButton *button, gpointer data) {
    (void)button;
    load_selected_shader(data);
    set_message(data, "Shader source reloaded");
}

static void shader_save(GtkButton *button, gpointer data) {
    (void)button;
    SettingsApp *app = data;
    gchar *name = gtk_combo_box_text_get_active_text(app->wallpaper_combo);
    if (!name) return;
    GtkTextIter begin, end;
    gtk_text_buffer_get_bounds(app->shader_source, &begin, &end);
    gchar *text = gtk_text_buffer_get_text(app->shader_source, &begin, &end, FALSE);
    gchar *temporary = NULL;
    GError *file_error = NULL;
    gint descriptor = g_file_open_tmp("xfce-plasma-shader-XXXXXX", &temporary, &file_error);
    if (descriptor < 0) {
        set_message(app, file_error->message);
        g_clear_error(&file_error); g_free(text); g_free(name); return;
    }
    close(descriptor);
    if (!g_file_set_contents(temporary, text, -1, &file_error)) {
        set_message(app, file_error->message);
        g_clear_error(&file_error); g_unlink(temporary); g_free(temporary); g_free(text); g_free(name); return;
    }
    gchar *output = NULL, *error = NULL;
    gboolean ok = run_control("wallpaper", "replace", name, temporary, &output, &error);
    g_unlink(temporary); g_free(temporary); g_free(text); g_free(name);
    report_action(app, ok, output, error);
}

static gchar *prompt_shader_name(SettingsApp *app) {
    GtkWidget *dialog = gtk_dialog_new_with_buttons("New shader", GTK_WINDOW(app->window),
        GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT, "Cancel", GTK_RESPONSE_CANCEL,
        "Create", GTK_RESPONSE_ACCEPT, NULL);
    GtkWidget *entry = gtk_entry_new();
    gtk_entry_set_placeholder_text(GTK_ENTRY(entry), "my-shader.fs");
    gtk_container_set_border_width(GTK_CONTAINER(gtk_dialog_get_content_area(GTK_DIALOG(dialog))), 12);
    gtk_box_pack_start(GTK_BOX(gtk_dialog_get_content_area(GTK_DIALOG(dialog))), entry, FALSE, FALSE, 0);
    gtk_widget_show_all(dialog);
    gchar *name = NULL;
    if (gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_ACCEPT) {
        const gchar *entered = gtk_entry_get_text(GTK_ENTRY(entry));
        if (*entered) name = g_str_has_suffix(entered, ".fs") ? g_strdup(entered) : g_strconcat(entered, ".fs", NULL);
    }
    gtk_widget_destroy(dialog);
    return name;
}

static void shader_create(GtkButton *button, gpointer data) {
    (void)button;
    SettingsApp *app = data;
    gchar *name = prompt_shader_name(app);
    if (!name) return;
    gchar *template_name = gtk_combo_box_text_get_active_text(app->wallpaper_combo);
    gchar *output = NULL, *error = NULL;
    gboolean ok = run_control("wallpaper", "create", name,
                              template_name ? template_name : "tie-dye.fs", &output, &error);
    report_action(app, ok, output, error);
    if (ok) gtk_combo_box_set_active_id(GTK_COMBO_BOX(app->wallpaper_combo), name);
    g_free(template_name); g_free(name);
}

static void shader_remove(GtkButton *button, gpointer data) {
    (void)button;
    SettingsApp *app = data;
    gchar *name = gtk_combo_box_text_get_active_text(app->wallpaper_combo);
    if (!name) return;
    gchar *question = g_strdup_printf("Remove “%s”? This deletes its local shader source.", name);
    GtkWidget *dialog = gtk_message_dialog_new(GTK_WINDOW(app->window), GTK_DIALOG_MODAL,
        GTK_MESSAGE_WARNING, GTK_BUTTONS_NONE, "%s", question);
    gtk_dialog_add_buttons(GTK_DIALOG(dialog), "Cancel", GTK_RESPONSE_CANCEL,
                           "Remove", GTK_RESPONSE_ACCEPT, NULL);
    gint response = gtk_dialog_run(GTK_DIALOG(dialog));
    gtk_widget_destroy(dialog); g_free(question);
    if (response == GTK_RESPONSE_ACCEPT) {
        gchar *output = NULL, *error = NULL;
        gboolean ok = run_control("wallpaper", "remove", name, NULL, &output, &error);
        report_action(app, ok, output, error);
    }
    g_free(name);
}

static void speed_apply(GtkButton *button, gpointer data) {
    (void)button;
    SettingsApp *app = data;
    gchar *preset = gtk_combo_box_text_get_active_text(app->speed_combo);
    if (!preset) return;
    gchar *output = NULL, *error = NULL;
    gboolean ok = run_control("speed", preset, NULL, NULL, &output, &error);
    report_action(app, ok, output, error);
    g_free(preset);
}

static void simple_action(GtkButton *button, gpointer data) {
    SettingsApp *app = data;
    const gchar *section = g_object_get_data(G_OBJECT(button), "section");
    const gchar *action = g_object_get_data(G_OBJECT(button), "action");
    gchar *output = NULL, *error = NULL;
    gboolean ok = run_control(section, action, NULL, NULL, &output, &error);
    report_action(app, ok, output, error);
}

static gboolean shortcut_key_press(GtkWidget *widget, GdkEventKey *event, gpointer data) {
    (void)data;
    GdkModifierType modifiers = event->state & gtk_accelerator_get_default_mod_mask();
    if (!gtk_accelerator_valid(event->keyval, modifiers)) return FALSE;
    gchar *accelerator = gtk_accelerator_name(event->keyval, modifiers);
    gtk_entry_set_text(GTK_ENTRY(widget), accelerator);
    g_free(accelerator);
    return TRUE;
}

static void shortcut_action(GtkButton *button, gpointer data) {
    SettingsApp *app = data;
    guint index = GPOINTER_TO_UINT(g_object_get_data(G_OBJECT(button), "shortcut-index"));
    const gchar *verb = g_object_get_data(G_OBJECT(button), "shortcut-verb");
    const gchar *accelerator = gtk_entry_get_text(GTK_ENTRY(app->shortcut_entries[index]));
    gchar *output = NULL, *error = NULL;
    gboolean ok;
    if (g_strcmp0(verb, "set") == 0) {
        if (!*accelerator) { set_message(app, "Press a key combination in the shortcut field first"); return; }
        ok = run_control("shortcuts", "set", shortcut_actions[index], accelerator, &output, &error);
    } else ok = run_control("shortcuts", verb, shortcut_actions[index], NULL, &output, &error);
    report_action(app, ok, output, error);
}

static void refresh_clicked(GtkButton *button, gpointer data) {
    (void)button; refresh_all(data); set_message(data, "Status refreshed");
}

static void diagnostics_refresh(GtkButton *button, gpointer data) {
    (void)button;
    SettingsApp *app = data;
    gchar *report = capture_control("diagnostics", NULL, NULL, NULL);
    gtk_text_buffer_set_text(app->diagnostics, report, -1);
    set_message(app, "Diagnostics refreshed"); g_free(report);
}

static GtkWidget *new_button(const gchar *label, GCallback callback, SettingsApp *app) {
    GtkWidget *button = gtk_button_new_with_label(label);
    g_signal_connect(button, "clicked", callback, app);
    return button;
}

static GtkWidget *action_button(const gchar *label, const gchar *section,
                                const gchar *action, SettingsApp *app) {
    GtkWidget *button = new_button(label, G_CALLBACK(simple_action), app);
    g_object_set_data(G_OBJECT(button), "section", (gpointer)section);
    g_object_set_data(G_OBJECT(button), "action", (gpointer)action);
    return button;
}

static GtkWidget *page_grid(void) {
    GtkWidget *grid = gtk_grid_new();
    gtk_grid_set_row_spacing(GTK_GRID(grid), 9);
    gtk_grid_set_column_spacing(GTK_GRID(grid), 9);
    gtk_container_set_border_width(GTK_CONTAINER(grid), 14);
    return grid;
}

static GtkWidget *state_label(void) {
    GtkWidget *label = gtk_label_new("checking…");
    gtk_label_set_xalign(GTK_LABEL(label), 0.0f);
    return label;
}

static GtkWidget *warning_banner(void) {
    GtkWidget *frame = gtk_frame_new(NULL);
    GtkWidget *label = gtk_label_new(NULL);
    gtk_label_set_markup(GTK_LABEL(label), "<b>Photosensitive epilepsy and motion-sickness warning</b>\n"
        "Animated patterns, flashing contrast, parallax, and rapid motion may cause symptoms. "
        "Use Frozen or Slow and stop immediately if you feel unwell.");
    gtk_label_set_line_wrap(GTK_LABEL(label), TRUE);
    gtk_label_set_xalign(GTK_LABEL(label), 0.0f);
    gtk_widget_set_margin_start(label, 10); gtk_widget_set_margin_end(label, 10);
    gtk_widget_set_margin_top(label, 8); gtk_widget_set_margin_bottom(label, 8);
    gtk_container_add(GTK_CONTAINER(frame), label);
    return frame;
}

static GtkWidget *wallpaper_page(SettingsApp *app) {
    GtkWidget *grid = page_grid();
    GtkWidget *previous = new_button("Previous", G_CALLBACK(wallpaper_relative), app);
    GtkWidget *next = new_button("Next", G_CALLBACK(wallpaper_relative), app);
    g_object_set_data(G_OBJECT(previous), "action", (gpointer)"prev");
    g_object_set_data(G_OBJECT(next), "action", (gpointer)"next");
    app->wallpaper_combo = GTK_COMBO_BOX_TEXT(gtk_combo_box_text_new());
    g_signal_connect(app->wallpaper_combo, "changed", G_CALLBACK(wallpaper_changed), app);
    app->wallpaper_state = state_label();
    app->shader_chooser = GTK_FILE_CHOOSER(gtk_file_chooser_button_new("Choose a fragment shader", GTK_FILE_CHOOSER_ACTION_OPEN));
    GtkFileFilter *filter = gtk_file_filter_new();
    gtk_file_filter_set_name(filter, "GLSL fragment shaders (*.fs)");
    gtk_file_filter_add_pattern(filter, "*.fs");
    gtk_file_chooser_add_filter(app->shader_chooser, filter);
    GtkWidget *view = gtk_text_view_new();
    gtk_text_view_set_monospace(GTK_TEXT_VIEW(view), TRUE);
    gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(view), GTK_WRAP_NONE);
    app->shader_source = gtk_text_view_get_buffer(GTK_TEXT_VIEW(view));
    GtkWidget *scroll = gtk_scrolled_window_new(NULL, NULL);
    gtk_widget_set_vexpand(scroll, TRUE);
    gtk_container_add(GTK_CONTAINER(scroll), view);

    gtk_grid_attach(GTK_GRID(grid), warning_banner(), 0, 0, 5, 1);
    gtk_grid_attach(GTK_GRID(grid), gtk_label_new("Active"), 0, 1, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), app->wallpaper_state, 1, 1, 4, 1);
    gtk_grid_attach(GTK_GRID(grid), GTK_WIDGET(app->wallpaper_combo), 0, 2, 3, 1);
    gtk_grid_attach(GTK_GRID(grid), new_button("Apply", G_CALLBACK(wallpaper_apply), app), 3, 2, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), previous, 0, 3, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), next, 1, 3, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), new_button("New from selected", G_CALLBACK(shader_create), app), 2, 3, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), new_button("Remove", G_CALLBACK(shader_remove), app), 3, 3, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), gtk_label_new("Shader source (changes reload live when this profile is active)"), 0, 4, 4, 1);
    gtk_grid_attach(GTK_GRID(grid), scroll, 0, 5, 5, 1);
    gtk_grid_attach(GTK_GRID(grid), new_button("Reload code", G_CALLBACK(shader_reload), app), 0, 6, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), new_button("Save code", G_CALLBACK(shader_save), app), 1, 6, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), GTK_WIDGET(app->shader_chooser), 2, 6, 2, 1);
    gtk_grid_attach(GTK_GRID(grid), new_button("Import", G_CALLBACK(wallpaper_import), app), 4, 6, 1, 1);
    return grid;
}

static GtkWidget *motion_page(SettingsApp *app) {
    GtkWidget *grid = page_grid();
    app->speed_state = state_label();
    app->speed_combo = GTK_COMBO_BOX_TEXT(gtk_combo_box_text_new());
    const gchar *presets[] = {"frozen", "slow", "medium", "fast", "motion-sickness", NULL};
    for (guint index = 0; presets[index]; index++) gtk_combo_box_text_append_text(app->speed_combo, presets[index]);
    gtk_combo_box_set_active(GTK_COMBO_BOX(app->speed_combo), 2);
    gtk_grid_attach(GTK_GRID(grid), warning_banner(), 0, 0, 5, 1);
    gtk_grid_attach(GTK_GRID(grid), gtk_label_new("Current speed"), 0, 1, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), app->speed_state, 1, 1, 2, 1);
    gtk_grid_attach(GTK_GRID(grid), GTK_WIDGET(app->speed_combo), 0, 2, 2, 1);
    gtk_grid_attach(GTK_GRID(grid), new_button("Apply preset", G_CALLBACK(speed_apply), app), 2, 2, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), action_button("Slower", "speed", "down", app), 0, 3, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), action_button("Faster", "speed", "up", app), 1, 3, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), action_button("Freeze", "speed", "freeze", app), 2, 3, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), action_button("Restore", "speed", "restore", app), 3, 3, 1, 1);
    GtkWidget *tip = gtk_label_new("Frozen keeps the current frame still. Slow is the safest animated preset. “Motion-sickness” is intentionally intense.");
    gtk_label_set_line_wrap(GTK_LABEL(tip), TRUE); gtk_label_set_xalign(GTK_LABEL(tip), 0.0f);
    gtk_grid_attach(GTK_GRID(grid), tip, 0, 5, 5, 1);
    return grid;
}

static void attach_service(GtkGrid *grid, gint row, const gchar *name,
                           GtkWidget **state, const gchar *section, SettingsApp *app) {
    GtkWidget *name_label = gtk_label_new(name); gtk_label_set_xalign(GTK_LABEL(name_label), 0.0f);
    *state = state_label();
    gtk_grid_attach(grid, name_label, 0, row, 1, 1); gtk_grid_attach(grid, *state, 1, row, 1, 1);
    gtk_grid_attach(grid, action_button("Start", section, "start", app), 2, row, 1, 1);
    gtk_grid_attach(grid, action_button("Stop", section, "stop", app), 3, row, 1, 1);
    gtk_grid_attach(grid, action_button("Restart", section, "restart", app), 4, row, 1, 1);
}

static GtkWidget *services_page(SettingsApp *app) {
    GtkWidget *grid = page_grid();
    attach_service(GTK_GRID(grid), 0, "Game mode guard", &app->game_state, "game", app);
    attach_service(GTK_GRID(grid), 1, "Picom effects", &app->picom_state, "picom", app);
    attach_service(GTK_GRID(grid), 2, "Transparent desktop", &app->desktop_state, "desktop", app);
    gtk_grid_attach(GTK_GRID(grid), gtk_label_new("Monitors"), 0, 4, 1, 1);
    app->monitor_state = state_label();
    gtk_grid_attach(GTK_GRID(grid), app->monitor_state, 1, 4, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), action_button("Synchronize", "monitors", "sync", app), 2, 4, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), action_button("Recover full stack", "recover", NULL, app), 0, 6, 2, 1);
    gtk_grid_attach(GTK_GRID(grid), new_button("Refresh status", G_CALLBACK(refresh_clicked), app), 2, 6, 1, 1);
    return grid;
}

static GtkWidget *shortcuts_page(SettingsApp *app) {
    GtkWidget *grid = page_grid();
    GtkWidget *intro = gtk_label_new("Click a field, press any valid key combination, then Apply. Conflicting XFCE shortcuts are preserved and reported.");
    gtk_label_set_line_wrap(GTK_LABEL(intro), TRUE); gtk_label_set_xalign(GTK_LABEL(intro), 0.0f);
    gtk_grid_attach(GTK_GRID(grid), intro, 0, 0, 6, 1);
    for (guint index = 0; index < SHORTCUT_COUNT; index++) {
        GtkWidget *label = gtk_label_new(shortcut_labels[index]);
        gtk_label_set_xalign(GTK_LABEL(label), 0.0f);
        app->shortcut_entries[index] = gtk_entry_new();
        gtk_entry_set_placeholder_text(GTK_ENTRY(app->shortcut_entries[index]), "Unassigned — press a shortcut");
        g_signal_connect(app->shortcut_entries[index], "key-press-event", G_CALLBACK(shortcut_key_press), app);
        gtk_grid_attach(GTK_GRID(grid), label, 0, (gint)index + 1, 1, 1);
        gtk_grid_attach(GTK_GRID(grid), app->shortcut_entries[index], 1, (gint)index + 1, 2, 1);
        const gchar *verbs[] = {"set", "clear", "reset"};
        const gchar *button_labels[] = {"Apply", "Clear", "Default"};
        for (guint button_index = 0; button_index < 3; button_index++) {
            GtkWidget *button = new_button(button_labels[button_index], G_CALLBACK(shortcut_action), app);
            g_object_set_data(G_OBJECT(button), "shortcut-index", GUINT_TO_POINTER(index));
            g_object_set_data(G_OBJECT(button), "shortcut-verb", (gpointer)verbs[button_index]);
            gtk_grid_attach(GTK_GRID(grid), button, 3 + (gint)button_index, (gint)index + 1, 1, 1);
        }
    }
    return grid;
}

static GtkWidget *diagnostics_page(SettingsApp *app) {
    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10);
    gtk_container_set_border_width(GTK_CONTAINER(box), 14);
    GtkWidget *view = gtk_text_view_new();
    gtk_text_view_set_editable(GTK_TEXT_VIEW(view), FALSE); gtk_text_view_set_monospace(GTK_TEXT_VIEW(view), TRUE);
    app->diagnostics = gtk_text_view_get_buffer(GTK_TEXT_VIEW(view));
    GtkWidget *scroll = gtk_scrolled_window_new(NULL, NULL); gtk_container_add(GTK_CONTAINER(scroll), view);
    gtk_box_pack_start(GTK_BOX(box), new_button("Run diagnostics", G_CALLBACK(diagnostics_refresh), app), FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(box), scroll, TRUE, TRUE, 0);
    return box;
}

static gboolean refresh_timeout(gpointer data) { refresh_status(data); return G_SOURCE_CONTINUE; }

int main(int argc, char **argv) {
    if (argc > 1 && g_strcmp0(argv[1], "--version") == 0) {
        g_print("xfce-plasma-settings-ui %s\n", XFCE_PLASMA_VERSION);
        return 0;
    }
    gtk_init(&argc, &argv);
    SettingsApp app = {0};
    app.window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(app.window), "xfcePlasma Settings");
    gtk_window_set_default_size(GTK_WINDOW(app.window), 1040, 720);
    gtk_window_set_icon_name(GTK_WINDOW(app.window), "preferences-desktop");
    g_signal_connect(app.window, "destroy", G_CALLBACK(gtk_main_quit), NULL);
    GtkWidget *root = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    GtkWidget *notebook = gtk_notebook_new();
    app.message = gtk_label_new("");
    gtk_label_set_xalign(GTK_LABEL(app.message), 0.0f);
    gtk_widget_set_margin_start(app.message, 12); gtk_widget_set_margin_end(app.message, 12);
    gtk_widget_set_margin_top(app.message, 8); gtk_widget_set_margin_bottom(app.message, 8);
    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), wallpaper_page(&app), gtk_label_new("Wallpaper & Shaders"));
    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), motion_page(&app), gtk_label_new("Motion & Safety"));
    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), shortcuts_page(&app), gtk_label_new("Shortcuts"));
    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), services_page(&app), gtk_label_new("Desktop & Game Mode"));
    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), diagnostics_page(&app), gtk_label_new("Diagnostics"));
    gtk_box_pack_start(GTK_BOX(root), notebook, TRUE, TRUE, 0);
    gtk_box_pack_end(GTK_BOX(root), app.message, FALSE, FALSE, 0);
    gtk_container_add(GTK_CONTAINER(app.window), root);
    refresh_all(&app);
    g_timeout_add_seconds(5, refresh_timeout, &app);
    gtk_widget_show_all(app.window);
    gtk_main();
    return 0;
}
