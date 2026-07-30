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
    GtkComboBoxText *performance_combo;
    GtkComboBoxText *backend_combo;
    GtkFlowBox *gallery;
    GtkFileChooser *shader_chooser;
    GtkWidget *wallpaper_state;
    GtkWidget *renderer_state;
    GtkWidget *everyday_desktop_state;
    GtkWidget *delete_shader_button;
    GtkWidget *speed_state;
    GtkWidget *game_state;
    GtkWidget *picom_state;
    GtkWidget *desktop_state;
    GtkWidget *monitor_state;
    GtkTextBuffer *shader_source;
    GtkTextBuffer *diagnostics;
    GtkWidget *shortcut_entries[SHORTCUT_COUNT];
    gboolean refreshing_gallery;
} SettingsApp;

static const gchar *shortcut_actions[SHORTCUT_COUNT] = {
    "wallpaper-prev", "wallpaper-next", "speed-up", "speed-down",
    "stop-wallpaper", "open-settings"
};
static const gchar *shortcut_labels[SHORTCUT_COUNT] = {
    "Previous wallpaper", "Next wallpaper", "Faster animation",
    "Slower animation", "Emergency wallpaper stop", "Open settings"
};

static void wallpaper_apply(GtkButton *button, gpointer data);
static void video_add(GtkButton *button, gpointer data);
static void stream_add(GtkButton *button, gpointer data);
static void source_remove(GtkButton *button, gpointer data);
static void gallery_selection_changed(GtkFlowBox *box, gpointer data);
static void gallery_child_activated(GtkFlowBox *box, GtkFlowBoxChild *child, gpointer data);
static GtkWidget *page_grid(void);

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
    gchar *origin = capture_control("wallpaper", "origin", name, NULL);
    gtk_widget_set_sensitive(app->delete_shader_button, g_strcmp0(origin, "local") == 0);
    g_free(origin);
    g_free(source);
    g_free(name);
}

static void wallpaper_changed(GtkComboBox *box, gpointer data) {
    (void)box;
    load_selected_shader(data);
}

static void set_gallery_image(GtkImage *image, const gchar *path, gint width, gint height) {
    GError *error = NULL;
    GdkPixbuf *pixbuf = NULL;
    if (path && *path) pixbuf = gdk_pixbuf_new_from_file_at_scale(path, width, height, TRUE, &error);
    if (pixbuf) {
        gtk_image_set_from_pixbuf(image, pixbuf);
        g_object_unref(pixbuf);
    } else {
        gtk_image_set_from_icon_name(image, "image-missing", GTK_ICON_SIZE_DIALOG);
    }
    g_clear_error(&error);
}

static void clear_gallery(SettingsApp *app) {
    GList *children = gtk_container_get_children(GTK_CONTAINER(app->gallery));
    for (GList *item = children; item; item = item->next) gtk_widget_destroy(GTK_WIDGET(item->data));
    g_list_free(children);
}

static void refresh_gallery(SettingsApp *app, const gchar *catalog,
                            const gchar *current, const gchar *wanted) {
    gchar **lines = g_strsplit(catalog, "\n", -1);
    GtkFlowBoxChild *selected_child = NULL;
    GtkFlowBoxChild *first_child = NULL;
    app->refreshing_gallery = TRUE;
    clear_gallery(app);
    for (guint index = 0; lines[index]; index++) {
        if (!*lines[index]) continue;
        gchar **fields = g_strsplit(lines[index], "\t", 11);
        if (g_strv_length(fields) < 11) { g_strfreev(fields); continue; }
        GtkWidget *child = gtk_flow_box_child_new();
        GtkWidget *card = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 14);
        GtkWidget *image = gtk_image_new();
        GtkWidget *text = gtk_box_new(GTK_ORIENTATION_VERTICAL, 5);
        GtkWidget *title = gtk_label_new(fields[2]);
        GtkWidget *description = gtk_label_new(fields[4]);
        GtkWidget *secondary = gtk_label_new(NULL);
        gchar *secondary_text = g_strdup_printf("%s  ·  %s  ·  %s", fields[3], fields[9],
            g_strcmp0(fields[7], "local") == 0 ? "LOCAL" : "BUNDLED");
        set_gallery_image(GTK_IMAGE(image), fields[6], 176, 99);
        gtk_label_set_ellipsize(GTK_LABEL(title), PANGO_ELLIPSIZE_END);
        gtk_label_set_xalign(GTK_LABEL(title), 0.0f);
        gtk_label_set_xalign(GTK_LABEL(description), 0.0f);
        gtk_label_set_xalign(GTK_LABEL(secondary), 0.0f);
        gtk_label_set_line_wrap(GTK_LABEL(description), TRUE);
        gtk_label_set_max_width_chars(GTK_LABEL(description), 72);
        gtk_label_set_text(GTK_LABEL(secondary), secondary_text);
        gtk_style_context_add_class(gtk_widget_get_style_context(title), "gallery-title");
        gtk_style_context_add_class(gtk_widget_get_style_context(description), "dim-label");
        gtk_style_context_add_class(gtk_widget_get_style_context(secondary), "dim-label");
        gtk_style_context_add_class(gtk_widget_get_style_context(card), "shader-card");
        gtk_widget_set_hexpand(child, TRUE);
        gtk_widget_set_halign(child, GTK_ALIGN_FILL);
        gtk_widget_set_hexpand(card, TRUE);
        gtk_widget_set_hexpand(text, TRUE);
        gtk_widget_set_valign(image, GTK_ALIGN_START);
        gtk_box_pack_start(GTK_BOX(card), image, FALSE, FALSE, 0);
        gtk_box_pack_start(GTK_BOX(text), title, FALSE, FALSE, 0);
        gtk_box_pack_start(GTK_BOX(text), description, TRUE, TRUE, 0);
        gtk_box_pack_start(GTK_BOX(text), secondary, FALSE, FALSE, 0);
        gtk_box_pack_start(GTK_BOX(card), text, TRUE, TRUE, 0);
        gtk_container_add(GTK_CONTAINER(child), card);
        g_object_set_data_full(G_OBJECT(child), "source-key", g_strdup(fields[0]), g_free);
        g_object_set_data_full(G_OBJECT(child), "source-type", g_strdup(fields[9]), g_free);
        g_object_set_data_full(G_OBJECT(child), "source-reference", g_strdup(fields[10]), g_free);
        g_object_set_data_full(G_OBJECT(child), "shader-display", g_strdup(fields[2]), g_free);
        g_object_set_data_full(G_OBJECT(child), "shader-category", g_strdup(fields[3]), g_free);
        g_object_set_data_full(G_OBJECT(child), "shader-description", g_strdup(fields[4]), g_free);
        g_object_set_data_full(G_OBJECT(child), "shader-thumbnail", g_strdup(fields[6]), g_free);
        g_object_set_data_full(G_OBJECT(child), "shader-origin", g_strdup(fields[7]), g_free);
        if (g_strcmp0(fields[0], current) == 0)
            gtk_style_context_add_class(gtk_widget_get_style_context(child), "active-shader");
        gtk_flow_box_insert(app->gallery, child, -1);
        if (!first_child) first_child = GTK_FLOW_BOX_CHILD(child);
        if (g_strcmp0(fields[0], wanted) == 0) selected_child = GTK_FLOW_BOX_CHILD(child);
        g_free(secondary_text);
        g_strfreev(fields);
    }
    if (!selected_child) selected_child = first_child;
    if (selected_child) {
        gtk_flow_box_select_child(app->gallery, selected_child);
    }
    app->refreshing_gallery = FALSE;
    gtk_widget_show_all(GTK_WIDGET(app->gallery));
    g_strfreev(lines);
}

static void refresh_wallpapers(SettingsApp *app) {
    gchar *selected = gtk_combo_box_text_get_active_text(app->wallpaper_combo);
    gchar *list = capture_control("wallpaper", "list", NULL, NULL);
    gchar *catalog = capture_control("background", "catalog", NULL, NULL);
    gchar *current = capture_control("wallpaper", "current", NULL, NULL);
    gchar *current_source = capture_control("background", "current", NULL, NULL);
    gchar **names = g_strsplit(list, "\n", -1);
    gtk_combo_box_text_remove_all(app->wallpaper_combo);
    for (guint index = 0; names[index]; index++) {
        if (*names[index]) gtk_combo_box_text_append(app->wallpaper_combo, names[index], names[index]);
    }
    const gchar *wanted = selected && *selected ? selected : current;
    if (!gtk_combo_box_set_active_id(GTK_COMBO_BOX(app->wallpaper_combo), wanted) &&
        !gtk_combo_box_set_active_id(GTK_COMBO_BOX(app->wallpaper_combo), current))
        gtk_combo_box_set_active(GTK_COMBO_BOX(app->wallpaper_combo), 0);
    gtk_label_set_text(GTK_LABEL(app->wallpaper_state), current_source);
    refresh_gallery(app, catalog, current_source, current_source);
    g_strfreev(names);
    g_free(selected);
    g_free(current);
    g_free(current_source);
    g_free(catalog);
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
    gchar *renderer = capture_control("wallpaper", "status", NULL, NULL);
    gchar *speed = capture_control("speed", "current", NULL, NULL);
    gchar *game = capture_control("game", "status", NULL, NULL);
    gchar *picom = capture_control("picom", "status", NULL, NULL);
    gchar *desktop = capture_control("desktop", "status", NULL, NULL);
    gchar *monitors = capture_control("monitors", "status", NULL, NULL);
    gtk_label_set_text(GTK_LABEL(app->speed_state), speed);
    gtk_label_set_text(GTK_LABEL(app->renderer_state), renderer);
    gtk_label_set_text(GTK_LABEL(app->everyday_desktop_state), desktop);
    gtk_label_set_text(GTK_LABEL(app->game_state), game);
    gtk_label_set_text(GTK_LABEL(app->picom_state), picom);
    gtk_label_set_text(GTK_LABEL(app->desktop_state), desktop);
    gtk_label_set_text(GTK_LABEL(app->monitor_state), monitors);
    g_free(monitors); g_free(desktop); g_free(picom); g_free(game); g_free(speed); g_free(renderer);
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
    GList *selected = gtk_flow_box_get_selected_children(app->gallery);
    if (!selected) return;
    const gchar *key = g_object_get_data(G_OBJECT(selected->data), "source-key");
    gchar *output = NULL, *error = NULL;
    gboolean ok = run_control("background", "use", key, NULL, &output, &error);
    g_list_free(selected);
    report_action(app, ok, output, error);
}

static void source_remove(GtkButton *button, gpointer data) {
    (void)button;
    SettingsApp *app = data;
    GList *selected = gtk_flow_box_get_selected_children(app->gallery);
    if (!selected) return;
    const gchar *key = g_object_get_data(G_OBJECT(selected->data), "source-key");
    const gchar *type = g_object_get_data(G_OBJECT(selected->data), "source-type");
    const gchar *origin = g_object_get_data(G_OBJECT(selected->data), "shader-origin");
    if (g_strcmp0(origin, "local") != 0 || g_strcmp0(type, "Shader") == 0) {
        set_message(app, "Only local video and stream entries can be removed here");
        g_list_free(selected); return;
    }
    GtkWidget *dialog = gtk_message_dialog_new(GTK_WINDOW(app->window), GTK_DIALOG_MODAL,
        GTK_MESSAGE_WARNING, GTK_BUTTONS_NONE,
        "Remove this local source entry? The original media file will not be deleted.");
    gtk_dialog_add_buttons(GTK_DIALOG(dialog), "Cancel", GTK_RESPONSE_CANCEL,
        "Remove source", GTK_RESPONSE_ACCEPT, NULL);
    if (gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_ACCEPT) {
        gchar *output = NULL, *error = NULL;
        gboolean ok = run_control("background", "remove-source", key, NULL, &output, &error);
        report_action(app, ok, output, error);
    }
    gtk_widget_destroy(dialog);
    g_list_free(selected);
}

static void gallery_selection_changed(GtkFlowBox *box, gpointer data) {
    SettingsApp *app = data;
    if (app->refreshing_gallery) return;
    GList *selected = gtk_flow_box_get_selected_children(box);
    if (selected) {
        GtkFlowBoxChild *child = GTK_FLOW_BOX_CHILD(selected->data);
        const gchar *type = g_object_get_data(G_OBJECT(child), "source-type");
        const gchar *reference = g_object_get_data(G_OBJECT(child), "source-reference");
        if (g_strcmp0(type, "Shader") == 0)
            gtk_combo_box_set_active_id(GTK_COMBO_BOX(app->wallpaper_combo), reference);
    }
    g_list_free(selected);
}

static void gallery_child_activated(GtkFlowBox *box, GtkFlowBoxChild *child, gpointer data) {
    SettingsApp *app = data;
    gtk_flow_box_select_child(box, child);
    wallpaper_apply(NULL, app);
}

static void wallpaper_relative(GtkButton *button, gpointer data) {
    SettingsApp *app = data;
    const gchar *action = g_object_get_data(G_OBJECT(button), "action");
    gchar *output = NULL, *error = NULL;
    gboolean ok = run_control("background", action, NULL, NULL, &output, &error);
    report_action(app, ok, output, error);
}

static void video_add(GtkButton *button, gpointer data) {
    (void)button;
    SettingsApp *app = data;
    GtkWidget *dialog = gtk_file_chooser_dialog_new("Add local video", GTK_WINDOW(app->window),
        GTK_FILE_CHOOSER_ACTION_OPEN, "Cancel", GTK_RESPONSE_CANCEL,
        "Add muted video", GTK_RESPONSE_ACCEPT, NULL);
    GtkFileFilter *common = gtk_file_filter_new();
    gtk_file_filter_set_name(common, "Common video files");
    const gchar *patterns[] = {"*.mp4", "*.webm", "*.mkv", "*.mov", "*.avi", "*.m4v", NULL};
    for (guint index = 0; patterns[index]; index++) gtk_file_filter_add_pattern(common, patterns[index]);
    gtk_file_chooser_add_filter(GTK_FILE_CHOOSER(dialog), common);
    GtkFileFilter *all = gtk_file_filter_new();
    gtk_file_filter_set_name(all, "All files (mpv determines codec support)");
    gtk_file_filter_add_pattern(all, "*");
    gtk_file_chooser_add_filter(GTK_FILE_CHOOSER(dialog), all);
    if (gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_ACCEPT) {
        gchar *filename = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
        gchar *output = NULL, *error = NULL;
        gboolean ok = run_control("background", "video", filename, NULL, &output, &error);
        report_action(app, ok, output, error);
        g_free(filename);
    }
    gtk_widget_destroy(dialog);
}

static void stream_add(GtkButton *button, gpointer data) {
    (void)button;
    SettingsApp *app = data;
    GtkWidget *dialog = gtk_dialog_new_with_buttons("Add RTSP stream", GTK_WINDOW(app->window),
        GTK_DIALOG_MODAL, "Cancel", GTK_RESPONSE_CANCEL, "Save stream", GTK_RESPONSE_ACCEPT, NULL);
    GtkWidget *grid = page_grid();
    GtkWidget *id_entry = gtk_entry_new();
    GtkWidget *url_entry = gtk_entry_new();
    GtkWidget *user_entry = gtk_entry_new();
    GtkWidget *password_entry = gtk_entry_new();
    gtk_entry_set_placeholder_text(GTK_ENTRY(id_entry), "front-door");
    gtk_entry_set_placeholder_text(GTK_ENTRY(url_entry), "rtsp://camera.local/stream");
    gtk_entry_set_visibility(GTK_ENTRY(password_entry), FALSE);
    gtk_grid_attach(GTK_GRID(grid), gtk_label_new("Source ID"), 0, 0, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), id_entry, 1, 0, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), gtk_label_new("RTSP URL"), 0, 1, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), url_entry, 1, 1, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), gtk_label_new("Username (optional)"), 0, 2, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), user_entry, 1, 2, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), gtk_label_new("Password (optional)"), 0, 3, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), password_entry, 1, 3, 1, 1);
    gtk_container_add(GTK_CONTAINER(gtk_dialog_get_content_area(GTK_DIALOG(dialog))), grid);
    gtk_widget_show_all(dialog);
    if (gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_ACCEPT) {
        const gchar *id = gtk_entry_get_text(GTK_ENTRY(id_entry));
        const gchar *url = gtk_entry_get_text(GTK_ENTRY(url_entry));
        const gchar *user = gtk_entry_get_text(GTK_ENTRY(user_entry));
        const gchar *password = gtk_entry_get_text(GTK_ENTRY(password_entry));
        gchar *protected_url = g_strdup(url);
        if (*user && g_str_has_prefix(url, "rtsp://")) {
            gchar *escaped_user = g_uri_escape_string(user, NULL, TRUE);
            gchar *escaped_password = g_uri_escape_string(password, NULL, TRUE);
            g_free(protected_url);
            protected_url = g_strdup_printf("rtsp://%s:%s@%s", escaped_user, escaped_password, url + 7);
            g_free(escaped_password); g_free(escaped_user);
        }
        gchar *output = NULL, *error = NULL;
        gboolean ok = run_control("background", "add-stream", id, protected_url, &output, &error);
        report_action(app, ok, output, error);
        if (ok) set_message(app, "Stream saved. Select it in the Collection and choose Use selected to connect.");
        g_free(protected_url);
    }
    gtk_widget_destroy(dialog);
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

static void create_from_template(SettingsApp *app, const gchar *template_name) {
    gchar *name = prompt_shader_name(app);
    if (!name) return;
    gchar *output = NULL, *error = NULL;
    gboolean ok = run_control("wallpaper", "create", name, template_name, &output, &error);
    report_action(app, ok, output, error);
    if (ok) gtk_combo_box_set_active_id(GTK_COMBO_BOX(app->wallpaper_combo), name);
    g_free(name);
}

static void shader_create(GtkButton *button, gpointer data) {
    (void)button;
    create_from_template(data, "plasma.fs");
}

static void shader_duplicate(GtkButton *button, gpointer data) {
    (void)button;
    SettingsApp *app = data;
    gchar *template_name = gtk_combo_box_text_get_active_text(app->wallpaper_combo);
    create_from_template(app, template_name ? template_name : "plasma.fs");
    g_free(template_name);
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

static GtkWidget *section_heading(const gchar *text) {
    GtkWidget *label = gtk_label_new(text);
    gtk_label_set_xalign(GTK_LABEL(label), 0.0f);
    gtk_style_context_add_class(gtk_widget_get_style_context(label), "section-heading");
    return label;
}

static GtkWidget *collection_page(SettingsApp *app) {
    GtkWidget *root = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10);
    GtkWidget *controls = page_grid();
    GtkWidget *previous = new_button("Previous", G_CALLBACK(wallpaper_relative), app);
    GtkWidget *next = new_button("Next", G_CALLBACK(wallpaper_relative), app);
    GtkWidget *gallery_scroll = gtk_scrolled_window_new(NULL, NULL);
    gtk_container_set_border_width(GTK_CONTAINER(root), 14);
    gtk_container_set_border_width(GTK_CONTAINER(controls), 0);
    g_object_set_data(G_OBJECT(previous), "action", (gpointer)"prev");
    g_object_set_data(G_OBJECT(next), "action", (gpointer)"next");

    app->wallpaper_state = state_label();
    app->renderer_state = state_label();
    app->everyday_desktop_state = state_label();
    app->speed_state = state_label();
    app->speed_combo = GTK_COMBO_BOX_TEXT(gtk_combo_box_text_new());
    const gchar *presets[] = {"frozen", "slow", "medium", "fast", "motion-sickness", NULL};
    for (guint index = 0; presets[index]; index++) gtk_combo_box_text_append_text(app->speed_combo, presets[index]);
    gtk_combo_box_set_active(GTK_COMBO_BOX(app->speed_combo), 2);

    gtk_grid_attach(GTK_GRID(controls), gtk_label_new("Current source"), 0, 0, 1, 1);
    gtk_grid_attach(GTK_GRID(controls), app->wallpaper_state, 1, 0, 2, 1);
    gtk_grid_attach(GTK_GRID(controls), gtk_label_new("Background"), 3, 0, 1, 1);
    gtk_grid_attach(GTK_GRID(controls), app->renderer_state, 4, 0, 1, 1);
    gtk_grid_attach(GTK_GRID(controls), gtk_label_new("Desktop icons"), 5, 0, 1, 1);
    gtk_grid_attach(GTK_GRID(controls), app->everyday_desktop_state, 6, 0, 1, 1);
    gtk_grid_attach(GTK_GRID(controls), previous, 0, 1, 1, 1);
    gtk_grid_attach(GTK_GRID(controls), next, 1, 1, 1, 1);
    gtk_grid_attach(GTK_GRID(controls), new_button("Use selected", G_CALLBACK(wallpaper_apply), app), 2, 1, 1, 1);
    gtk_grid_attach(GTK_GRID(controls), gtk_label_new("Motion"), 3, 1, 1, 1);
    gtk_grid_attach(GTK_GRID(controls), GTK_WIDGET(app->speed_combo), 4, 1, 1, 1);
    gtk_grid_attach(GTK_GRID(controls), new_button("Apply", G_CALLBACK(speed_apply), app), 5, 1, 1, 1);
    gtk_grid_attach(GTK_GRID(controls), app->speed_state, 6, 1, 1, 1);
    gtk_grid_attach(GTK_GRID(controls), action_button("Slower", "speed", "down", app), 3, 2, 1, 1);
    gtk_grid_attach(GTK_GRID(controls), action_button("Faster", "speed", "up", app), 4, 2, 1, 1);
    gtk_grid_attach(GTK_GRID(controls), action_button("Freeze", "speed", "freeze", app), 5, 2, 1, 1);
    gtk_grid_attach(GTK_GRID(controls), action_button("Resume", "speed", "restore", app), 6, 2, 1, 1);
    gtk_grid_attach(GTK_GRID(controls), new_button("Add video…", G_CALLBACK(video_add), app), 0, 2, 2, 1);
    gtk_grid_attach(GTK_GRID(controls), new_button("Add network stream…", G_CALLBACK(stream_add), app), 2, 2, 1, 1);
    GtkWidget *remove_source_button = new_button("Remove local source", G_CALLBACK(source_remove), app);
    gtk_style_context_add_class(gtk_widget_get_style_context(remove_source_button), "destructive-action");
    gtk_grid_attach(GTK_GRID(controls), remove_source_button, 0, 3, 2, 1);

    app->gallery = GTK_FLOW_BOX(gtk_flow_box_new());
    gtk_flow_box_set_selection_mode(app->gallery, GTK_SELECTION_SINGLE);
    gtk_flow_box_set_activate_on_single_click(app->gallery, FALSE);
    gtk_flow_box_set_homogeneous(app->gallery, TRUE);
    gtk_flow_box_set_min_children_per_line(app->gallery, 1);
    gtk_flow_box_set_max_children_per_line(app->gallery, 1);
    gtk_flow_box_set_row_spacing(app->gallery, 8);
    gtk_flow_box_set_column_spacing(app->gallery, 8);
    g_signal_connect(app->gallery, "selected-children-changed", G_CALLBACK(gallery_selection_changed), app);
    g_signal_connect(app->gallery, "child-activated", G_CALLBACK(gallery_child_activated), app);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(gallery_scroll), GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC);
    gtk_widget_set_vexpand(gallery_scroll, TRUE);
    gtk_container_add(GTK_CONTAINER(gallery_scroll), GTK_WIDGET(app->gallery));


    gtk_box_pack_start(GTK_BOX(root), warning_banner(), FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(root), section_heading("Everyday controls"), FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(root), controls, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(root), section_heading("Background collection — shaders featured"), FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(root), gallery_scroll, TRUE, TRUE, 0);
    return root;
}

static GtkWidget *shader_editor_page(SettingsApp *app) {
    GtkWidget *grid = page_grid();
    app->wallpaper_combo = GTK_COMBO_BOX_TEXT(gtk_combo_box_text_new());
    g_signal_connect(app->wallpaper_combo, "changed", G_CALLBACK(wallpaper_changed), app);
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
    GtkWidget *delete_button = new_button("Delete local shader", G_CALLBACK(shader_remove), app);
    app->delete_shader_button = delete_button;
    gtk_style_context_add_class(gtk_widget_get_style_context(delete_button), "destructive-action");

    GtkWidget *note = gtk_label_new("Bundled source remains editable for compatibility, but upgrades restore bundled files. Duplicate a shader before making a durable personal version.");
    gtk_label_set_line_wrap(GTK_LABEL(note), TRUE);
    gtk_label_set_xalign(GTK_LABEL(note), 0.0f);
    gtk_style_context_add_class(gtk_widget_get_style_context(note), "dim-label");

    gtk_grid_attach(GTK_GRID(grid), section_heading("GLSL source and local shaders"), 0, 0, 5, 1);
    gtk_grid_attach(GTK_GRID(grid), GTK_WIDGET(app->wallpaper_combo), 0, 1, 3, 1);
    gtk_grid_attach(GTK_GRID(grid), new_button("Create blank copy", G_CALLBACK(shader_create), app), 3, 1, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), new_button("Duplicate selected", G_CALLBACK(shader_duplicate), app), 4, 1, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), note, 0, 2, 5, 1);
    gtk_grid_attach(GTK_GRID(grid), scroll, 0, 3, 5, 1);
    gtk_grid_attach(GTK_GRID(grid), new_button("Reload source", G_CALLBACK(shader_reload), app), 0, 4, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), new_button("Replace / Save", G_CALLBACK(shader_save), app), 1, 4, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), delete_button, 2, 4, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), GTK_WIDGET(app->shader_chooser), 0, 5, 4, 1);
    gtk_grid_attach(GTK_GRID(grid), new_button("Import shader", G_CALLBACK(wallpaper_import), app), 4, 5, 1, 1);
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

static void advanced_choice_apply(GtkButton *button, gpointer data) {
    SettingsApp *app = data;
    const gchar *action = g_object_get_data(G_OBJECT(button), "advanced-action");
    GtkComboBoxText *combo = g_strcmp0(action, "performance") == 0 ? app->performance_combo : app->backend_combo;
    gchar *choice = gtk_combo_box_text_get_active_text(combo);
    gchar *output = NULL, *error = NULL;
    gboolean ok = run_control("background", action, choice, NULL, &output, &error);
    report_action(app, ok, output, error);
    g_free(choice);
}

static GtkWidget *media_performance_page(SettingsApp *app) {
    GtkWidget *grid = page_grid();
    GtkWidget *apply_performance;
    GtkWidget *apply_backend;
    app->performance_combo = GTK_COMBO_BOX_TEXT(gtk_combo_box_text_new());
    app->backend_combo = GTK_COMBO_BOX_TEXT(gtk_combo_box_text_new());
    const gchar *modes[] = {"automatic", "low", "balanced", "high", NULL};
    const gchar *backends[] = {"automatic", "mpv", "vlc", NULL};
    for (guint i = 0; modes[i]; i++) gtk_combo_box_text_append_text(app->performance_combo, modes[i]);
    for (guint i = 0; backends[i]; i++) gtk_combo_box_text_append_text(app->backend_combo, backends[i]);
    gtk_combo_box_set_active(GTK_COMBO_BOX(app->performance_combo), 0);
    gtk_combo_box_set_active(GTK_COMBO_BOX(app->backend_combo), 0);
    apply_performance = new_button("Apply", G_CALLBACK(advanced_choice_apply), app);
    apply_backend = new_button("Apply", G_CALLBACK(advanced_choice_apply), app);
    g_object_set_data(G_OBJECT(apply_performance), "advanced-action", (gpointer)"performance");
    g_object_set_data(G_OBJECT(apply_backend), "advanced-action", (gpointer)"backend");
    gtk_grid_attach(GTK_GRID(grid), section_heading("Media and performance"), 0, 0, 3, 1);
    gtk_grid_attach(GTK_GRID(grid), gtk_label_new("Performance mode"), 0, 1, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), GTK_WIDGET(app->performance_combo), 1, 1, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), apply_performance, 2, 1, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), gtk_label_new("Video backend"), 0, 2, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), GTK_WIDGET(app->backend_combo), 1, 2, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), apply_backend, 2, 2, 1, 1);
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

static GtkWidget *advanced_page(SettingsApp *app) {
    GtkWidget *notebook = gtk_notebook_new();
    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), shader_editor_page(app), gtk_label_new("Shader Source"));
    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), shortcuts_page(app), gtk_label_new("Shortcuts"));
    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), services_page(app), gtk_label_new("Desktop & Game"));
    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), media_performance_page(app), gtk_label_new("Media & Performance"));
    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), diagnostics_page(app), gtk_label_new("Diagnostics"));
    return notebook;
}

static void load_css(void) {
    const gchar *css =
        ".section-heading { font-weight: bold; font-size: 1.08em; }"
        ".gallery-title { font-weight: bold; }"
        ".shader-card { padding: 7px; }"
        ".active-shader { border: 2px solid @theme_selected_bg_color; "
        "background-color: alpha(@theme_selected_bg_color, 0.12); }";
    GtkCssProvider *provider = gtk_css_provider_new();
    gtk_css_provider_load_from_data(provider, css, -1, NULL);
    gtk_style_context_add_provider_for_screen(gdk_screen_get_default(),
        GTK_STYLE_PROVIDER(provider), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    g_object_unref(provider);
}

static gboolean refresh_timeout(gpointer data) { refresh_status(data); return G_SOURCE_CONTINUE; }

int main(int argc, char **argv) {
    if (argc > 1 && g_strcmp0(argv[1], "--version") == 0) {
        g_print("xfce-plasma-settings-ui %s\n", XFCE_PLASMA_VERSION);
        return 0;
    }
    gtk_init(&argc, &argv);
    GtkSettings *gtk_settings = gtk_settings_get_default();
    if (gtk_settings) {
        g_object_set(gtk_settings, "gtk-application-prefer-dark-theme", TRUE, NULL);
    }
    load_css();
    SettingsApp app = {0};
    app.window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(app.window), "xfcePlasma Settings");
    gtk_window_set_default_size(GTK_WINDOW(app.window), 1040, 720);
    gtk_window_set_icon_name(GTK_WINDOW(app.window), "xfce-plasma");
    g_signal_connect(app.window, "destroy", G_CALLBACK(gtk_main_quit), NULL);
    GtkWidget *root = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    GtkWidget *notebook = gtk_notebook_new();
    app.message = gtk_label_new("");
    gtk_label_set_xalign(GTK_LABEL(app.message), 0.0f);
    gtk_widget_set_margin_start(app.message, 12); gtk_widget_set_margin_end(app.message, 12);
    gtk_widget_set_margin_top(app.message, 8); gtk_widget_set_margin_bottom(app.message, 8);
    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), collection_page(&app), gtk_label_new("Collection"));
    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), advanced_page(&app), gtk_label_new("Create / Advanced"));
    gtk_box_pack_start(GTK_BOX(root), notebook, TRUE, TRUE, 0);
    gtk_box_pack_end(GTK_BOX(root), app.message, FALSE, FALSE, 0);
    gtk_container_add(GTK_CONTAINER(app.window), root);
    refresh_all(&app);
    g_timeout_add_seconds(5, refresh_timeout, &app);
    gtk_widget_show_all(app.window);
    gtk_main();
    return 0;
}
