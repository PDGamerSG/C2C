#include "C2CLinuxGTK.h"

#if defined(__linux__)
#include <gtk/gtk.h>
#include <stdlib.h>
#include <string.h>

static C2CLinuxGTKCallbacks active_callbacks;
static GtkWidget *status_label;
static GtkWidget *history_list;
static char *pending_rows;
static GtkWidget *settings_window;

void c2c_linux_set_rows(const char *rows_text);

static void quit_clicked(GtkWidget *widget, gpointer data) {
    (void)widget;
    C2CLinuxGTKCallbacks *callbacks = data;
    if (callbacks->on_quit) callbacks->on_quit(callbacks->context);
    g_application_quit(g_application_get_default());
}

static void search_changed(GtkEditable *editable, gpointer data) {
    C2CLinuxGTKCallbacks *callbacks = data;
    if (callbacks->on_search) callbacks->on_search(callbacks->context, gtk_editable_get_text(editable));
}

static void settings_save(GtkWidget *widget, gpointer data) {
    (void)widget;
    GtkWidget **controls = data;
    C2CLinuxGTKCallbacks *callbacks = g_object_get_data(G_OBJECT(controls[0]), "c2c-callbacks");
    GtkSpinButton *limit = GTK_SPIN_BUTTON(controls[1]);
    GtkDropDown *appearance = GTK_DROP_DOWN(controls[2]);
    const char *appearance_value = gtk_string_list_get_string(GTK_STRING_LIST(gtk_drop_down_get_model(appearance)), gtk_drop_down_get_selected(appearance));
    char *json = g_strdup_printf("{\"retentionLimit\":%d,\"appearance\":\"%s\"}", gtk_spin_button_get_value_as_int(limit), appearance_value ? appearance_value : "system");
    if (callbacks && callbacks->on_settings) callbacks->on_settings(callbacks->context, json);
    g_free(json);
    gtk_window_destroy(GTK_WINDOW(settings_window));
    settings_window = NULL;
    g_free(controls);
}

static void show_settings(GtkWidget *widget, gpointer data) {
    (void)widget;
    C2CLinuxGTKCallbacks *callbacks = data;
    if (settings_window) { gtk_window_present(GTK_WINDOW(settings_window)); return; }
    settings_window = gtk_window_new();
    gtk_window_set_title(GTK_WINDOW(settings_window), "C2C Settings");
    gtk_window_set_default_size(GTK_WINDOW(settings_window), 360, 180);
    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
    gtk_widget_set_margin_top(box, 16); gtk_widget_set_margin_bottom(box, 16);
    gtk_widget_set_margin_start(box, 16); gtk_widget_set_margin_end(box, 16);
    gtk_window_set_child(GTK_WINDOW(settings_window), box);
    GtkWidget *limit = gtk_spin_button_new_with_range(1, 100000, 1);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(limit), 500);
    gtk_box_append(GTK_BOX(box), gtk_label_new("History limit"));
    gtk_box_append(GTK_BOX(box), limit);
    GtkStringList *appearance_model = gtk_string_list_new((const char *[]) { "light", "dark", "system", NULL });
    GtkWidget *appearance = gtk_drop_down_new(G_LIST_MODEL(appearance_model), NULL);
    gtk_box_append(GTK_BOX(box), gtk_label_new("Appearance"));
    gtk_box_append(GTK_BOX(box), appearance);
    GtkWidget *save = gtk_button_new_with_label("Save");
    GtkWidget **controls = g_new0(GtkWidget *, 3);
    controls[0] = save; controls[1] = limit; controls[2] = appearance;
    g_object_set_data(G_OBJECT(save), "c2c-callbacks", callbacks);
    g_signal_connect(save, "clicked", G_CALLBACK(settings_save), controls);
    gtk_box_append(GTK_BOX(box), save);
    gtk_window_present(GTK_WINDOW(settings_window));
}

static void row_action(GtkWidget *widget, gpointer data) {
    const char *action = g_object_get_data(G_OBJECT(widget), "c2c-action");
    const char *id = g_object_get_data(G_OBJECT(widget), "c2c-id");
    C2CLinuxGTKCallbacks *callbacks = data;
    if (!action || !id) return;
    if (strcmp(action, "activate") == 0 && callbacks->on_activate) callbacks->on_activate(callbacks->context, id);
    if (strcmp(action, "pin") == 0 && callbacks->on_pin) callbacks->on_pin(callbacks->context, id);
    if (strcmp(action, "delete") == 0 && callbacks->on_delete) callbacks->on_delete(callbacks->context, id);
}

static void clear_list(void) {
    if (!history_list) return;
    GtkWidget *child = gtk_widget_get_first_child(history_list);
    while (child) {
        GtkWidget *next = gtk_widget_get_next_sibling(child);
        gtk_list_box_remove(GTK_LIST_BOX(history_list), child);
        child = next;
    }
}

static GtkWidget *action_button(const char *label, const char *action, const char *id, C2CLinuxGTKCallbacks *callbacks) {
    GtkWidget *button = gtk_button_new_with_label(label);
    char *owned_action = g_strdup(action);
    char *owned_id = g_strdup(id);
    g_object_set_data_full(G_OBJECT(button), "c2c-action", owned_action, g_free);
    g_object_set_data_full(G_OBJECT(button), "c2c-id", owned_id, g_free);
    g_signal_connect(button, "clicked", G_CALLBACK(row_action), callbacks);
    return button;
}

static void append_row(const char *line) {
    char **parts = g_strsplit(line, "\t", 3);
    if (!parts[0] || !parts[1] || !parts[2]) { g_strfreev(parts); return; }
    GtkWidget *row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
    GtkWidget *title = gtk_button_new_with_label(parts[2]);
    gtk_widget_set_hexpand(title, TRUE);
    gtk_widget_set_halign(title, GTK_ALIGN_FILL);
    g_object_set_data_full(G_OBJECT(title), "c2c-action", g_strdup("activate"), g_free);
    g_object_set_data_full(G_OBJECT(title), "c2c-id", g_strdup(parts[0]), g_free);
    g_signal_connect(title, "clicked", G_CALLBACK(row_action), &active_callbacks);
    gtk_box_append(GTK_BOX(row), title);
    gtk_box_append(GTK_BOX(row), action_button(strcmp(parts[1], "1") == 0 ? "Unpin" : "Pin", "pin", parts[0], &active_callbacks));
    gtk_box_append(GTK_BOX(row), action_button("Delete", "delete", parts[0], &active_callbacks));
    gtk_list_box_append(GTK_LIST_BOX(history_list), row);
    g_strfreev(parts);
}

static void activate(GtkApplication *application, gpointer data) {
    C2CLinuxGTKCallbacks *callbacks = data;
    GtkWidget *window = gtk_application_window_new(application);
    gtk_window_set_title(GTK_WINDOW(window), "C2C Clipboard History");
    gtk_window_set_default_size(GTK_WINDOW(window), 620, 520);

    GtkWidget *root = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
    gtk_widget_set_margin_top(root, 12);
    gtk_widget_set_margin_bottom(root, 12);
    gtk_widget_set_margin_start(root, 12);
    gtk_widget_set_margin_end(root, 12);
    gtk_window_set_child(GTK_WINDOW(window), root);

    GtkWidget *search = gtk_search_entry_new();
    gtk_search_entry_set_placeholder_text(GTK_SEARCH_ENTRY(search), "Search clipboard history");
    g_signal_connect(search, "search-changed", G_CALLBACK(search_changed), callbacks);
    gtk_box_append(GTK_BOX(root), search);

    history_list = gtk_list_box_new();
    gtk_list_box_set_selection_mode(GTK_LIST_BOX(history_list), GTK_SELECTION_NONE);
    gtk_widget_set_vexpand(history_list, TRUE);
    gtk_box_append(GTK_BOX(root), history_list);

    status_label = gtk_label_new("Ready");
    gtk_label_set_xalign(GTK_LABEL(status_label), 0.0f);
    gtk_box_append(GTK_BOX(root), status_label);

    GtkWidget *actions = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
    GtkWidget *clear = gtk_button_new_with_label("Clear history");
    GtkWidget *settings = gtk_button_new_with_label("Settings");
    GtkWidget *export_button = gtk_button_new_with_label("Export");
    GtkWidget *import_button = gtk_button_new_with_label("Import");
    GtkWidget *quit = gtk_button_new_with_label("Quit");
    if (callbacks->on_clear) g_signal_connect_swapped(clear, "clicked", G_CALLBACK(callbacks->on_clear), callbacks->context);
    if (callbacks->on_settings) g_signal_connect(settings, "clicked", G_CALLBACK(show_settings), callbacks);
    if (callbacks->on_export) g_signal_connect_swapped(export_button, "clicked", G_CALLBACK(callbacks->on_export), callbacks->context);
    if (callbacks->on_import) g_signal_connect_swapped(import_button, "clicked", G_CALLBACK(callbacks->on_import), callbacks->context);
    g_signal_connect(quit, "clicked", G_CALLBACK(quit_clicked), callbacks);
    gtk_box_append(GTK_BOX(actions), clear);
    gtk_box_append(GTK_BOX(actions), settings);
    gtk_box_append(GTK_BOX(actions), export_button);
    gtk_box_append(GTK_BOX(actions), import_button);
    gtk_box_append(GTK_BOX(actions), quit);
    gtk_box_append(GTK_BOX(root), actions);

    if (pending_rows) c2c_linux_set_rows(pending_rows);
    gtk_window_present(GTK_WINDOW(window));
}

int c2c_linux_run(const C2CLinuxGTKCallbacks *callbacks) {
    if (!callbacks) return 2;
    active_callbacks = *callbacks;
    GtkApplication *application = gtk_application_new("com.c2c.clipboard", G_APPLICATION_DEFAULT_FLAGS);
    g_signal_connect(application, "activate", G_CALLBACK(activate), &active_callbacks);
    int status = g_application_run(G_APPLICATION(application), 0, NULL);
    g_object_unref(application);
    return status;
}

void c2c_linux_set_rows(const char *rows_text) {
    g_free(pending_rows);
    pending_rows = g_strdup(rows_text ? rows_text : "");
    clear_list();
    if (!rows_text || !*rows_text) return;
    char **rows = g_strsplit(rows_text, "\n", -1);
    for (size_t index = 0; rows[index]; index++) {
        if (*rows[index]) append_row(rows[index]);
    }
    g_strfreev(rows);
}
void c2c_linux_set_status(const char *status) {
    if (status_label) gtk_label_set_text(GTK_LABEL(status_label), status ? status : "");
}
void c2c_linux_stop(void) { g_application_quit(g_application_get_default()); }

#else
int c2c_linux_run(const C2CLinuxGTKCallbacks *callbacks) { (void)callbacks; return 0; }
void c2c_linux_set_rows(const char *rows_json) { (void)rows_json; }
void c2c_linux_set_status(const char *status) { (void)status; }
void c2c_linux_stop(void) {}
#endif
