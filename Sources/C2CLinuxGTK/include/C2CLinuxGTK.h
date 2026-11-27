#ifndef C2C_LINUX_GTK_H
#define C2C_LINUX_GTK_H

typedef struct {
    void *context;
    void (*on_poll)(void *context);
    void (*on_search)(void *context, const char *query);
    void (*on_pinned_filter)(void *context, int enabled);
    void (*on_activate)(void *context, const char *id);
    void (*on_preview)(void *context, const char *id);
    void (*on_pin)(void *context, const char *id);
    void (*on_delete)(void *context, const char *id);
    void (*on_group)(void *context, const char *id, const char *group);
    void (*on_clear)(void *context);
    void (*on_settings)(void *context, const char *settings_json);
    void (*on_export)(void *context);
    void (*on_import)(void *context);
} C2CLinuxGTKCallbacks;

int c2c_linux_run(const C2CLinuxGTKCallbacks *callbacks);
void c2c_linux_set_rows(const char *rows_json);
void c2c_linux_set_status(const char *status);
void c2c_linux_stop(void);

#endif
