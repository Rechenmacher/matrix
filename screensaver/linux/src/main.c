/**
 * matrix-screensaver — Linux screensaver using WebKitGTK to render
 * the Matrix digital rain web app.
 *
 * Modes:
 *   (no args)          — standalone fullscreen window (works with any DE)
 *   --window-id <XID>  — embed into an existing X11 window (XScreenSaver)
 *   --root             — render on the root window (legacy X11 screensavers)
 *
 * The web assets are loaded from (in order):
 *   1. $MATRIX_SCREENSAVER_WEB_ROOT (env var, for development)
 *   2. $XDG_DATA_HOME/matrix-screensaver/  (~/.local/share/matrix-screensaver/)
 *   3. /usr/share/matrix-screensaver/
 */

#include <gtk/gtk.h>

#ifdef USE_WEBKIT2GTK_4
#include <webkit2/webkit2.h>
#else
#include <webkit/webkit.h>
#endif
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <signal.h>

/* Default URL parameters — Matrix 1 (1999) movie style, matching Mac/Windows */
#define DEFAULT_PARAMS \
    "skipIntro=true" \
    "&suppressWarnings=true" \
    "&version=classic" \
    "&font=matrixcode" \
    "&numColumns=90" \
    "&fallSpeed=0.3" \
    "&cycleSpeed=0.015" \
    "&raindropLength=1.0" \
    "&bloomStrength=1.0" \
    "&bloomSize=0.7" \
    "&highPassThreshold=0.0" \
    "&cursorHSL=0.33,1,0.1" \
    "&cursorIntensity=0.0" \
    "&isolateCursor=false" \
    "&brightnessDecay=3.0" \
    "&baseBrightness=-0.8" \
    "&baseContrast=1.5" \
    "&paletteHSL=0.33,0.95,0,0,0.33,1,0.3,30,0.33,1,0.6,70,0.34,0.85,0.8,100" \
    "&fps=60" \
    "&resolution=1"

static GtkWindow *window = NULL;
static gboolean grace_period = TRUE;
static double initial_mouse_x = -1;
static double initial_mouse_y = -1;

static void quit_screensaver(void)
{
    g_application_quit(G_APPLICATION(gtk_window_get_application(window)));
}

/* Input handlers — exit on any interaction after the grace period */

static gboolean on_key_pressed(GtkEventControllerKey *controller,
                                guint keyval, guint keycode,
                                GdkModifierType state, gpointer data)
{
    (void)controller; (void)keyval; (void)keycode; (void)state; (void)data;
    if (!grace_period)
        quit_screensaver();
    return TRUE;
}

static void on_motion(GtkEventControllerMotion *controller,
                      double x, double y, gpointer data)
{
    (void)controller; (void)data;
    if (grace_period) return;

    if (initial_mouse_x < 0) {
        initial_mouse_x = x;
        initial_mouse_y = y;
        return;
    }

    double dx = x - initial_mouse_x;
    double dy = y - initial_mouse_y;
    if (dx * dx + dy * dy > 100.0)  /* 10px threshold */
        quit_screensaver();
}

static void on_click(GtkGestureClick *gesture, int n_press,
                     double x, double y, gpointer data)
{
    (void)gesture; (void)n_press; (void)x; (void)y; (void)data;
    if (!grace_period)
        quit_screensaver();
}

static gboolean end_grace_period(gpointer data)
{
    (void)data;
    grace_period = FALSE;
    return G_SOURCE_REMOVE;
}

/**
 * Locate the web root directory containing index.html.
 * Returns a newly allocated string or NULL.
 */
static char *find_web_root(void)
{
    /* 1. Environment variable override (for development) */
    const char *env = getenv("MATRIX_SCREENSAVER_WEB_ROOT");
    if (env) {
        char *path = g_build_filename(env, "index.html", NULL);
        if (g_file_test(path, G_FILE_TEST_EXISTS)) {
            g_free(path);
            return g_strdup(env);
        }
        g_free(path);
    }

    /* 2. XDG_DATA_HOME */
    const char *data_home = g_get_user_data_dir();
    if (data_home) {
        char *dir = g_build_filename(data_home, "matrix-screensaver", NULL);
        char *path = g_build_filename(dir, "index.html", NULL);
        if (g_file_test(path, G_FILE_TEST_EXISTS)) {
            g_free(path);
            return dir;
        }
        g_free(path);
        g_free(dir);
    }

    /* 3. System-wide */
    const char *sys = "/usr/share/matrix-screensaver";
    {
        char *path = g_build_filename(sys, "index.html", NULL);
        if (g_file_test(path, G_FILE_TEST_EXISTS)) {
            g_free(path);
            return g_strdup(sys);
        }
        g_free(path);
    }

    return NULL;
}

static void activate(GtkApplication *app, gpointer user_data)
{
    (void)user_data;

    char *web_root = find_web_root();
    if (!web_root) {
        g_printerr("matrix-screensaver: cannot find web assets (index.html).\n"
                    "Set MATRIX_SCREENSAVER_WEB_ROOT or run install.sh first.\n");
        g_application_quit(G_APPLICATION(app));
        return;
    }

    /* Build the file:// URL */
    char *index_path = g_build_filename(web_root, "index.html", NULL);
    char *file_uri = g_filename_to_uri(index_path, NULL, NULL);
    char *url = g_strdup_printf("%s?%s", file_uri, DEFAULT_PARAMS);

    /* Create fullscreen window */
    window = GTK_WINDOW(gtk_application_window_new(app));
    gtk_window_set_title(window, "Matrix Screensaver");
    gtk_window_set_decorated(window, FALSE);
    gtk_window_fullscreen(window);

    /* Black background via CSS */
    GtkCssProvider *css = gtk_css_provider_new();
    gtk_css_provider_load_from_string(css, "window { background-color: black; }");
    gtk_style_context_add_provider_for_display(
        gdk_display_get_default(),
        GTK_STYLE_PROVIDER(css),
        GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);

    /* WebKit web view */
    WebKitWebView *webview = WEBKIT_WEB_VIEW(webkit_web_view_new());

    WebKitSettings *settings = webkit_web_view_get_settings(webview);
    webkit_settings_set_enable_webgl(settings, TRUE);
    webkit_settings_set_allow_file_access_from_file_urls(settings, TRUE);
    webkit_settings_set_enable_developer_extras(settings, FALSE);

    webkit_web_view_load_uri(webview, url);

    gtk_window_set_child(window, GTK_WIDGET(webview));

    /* Input controllers for exit-on-interaction */
    GtkEventController *key_ctrl = gtk_event_controller_key_new();
    g_signal_connect(key_ctrl, "key-pressed", G_CALLBACK(on_key_pressed), NULL);
    gtk_widget_add_controller(GTK_WIDGET(window), key_ctrl);

    GtkEventController *motion_ctrl = gtk_event_controller_motion_new();
    g_signal_connect(motion_ctrl, "motion", G_CALLBACK(on_motion), NULL);
    gtk_widget_add_controller(GTK_WIDGET(window), motion_ctrl);

    GtkGesture *click_ctrl = gtk_gesture_click_new();
    g_signal_connect(click_ctrl, "pressed", G_CALLBACK(on_click), NULL);
    gtk_widget_add_controller(GTK_WIDGET(window), GTK_EVENT_CONTROLLER(click_ctrl));

    /* 2-second grace period before input monitoring */
    g_timeout_add(2000, end_grace_period, NULL);

    /* Hide cursor */
    gtk_widget_set_cursor_from_name(GTK_WIDGET(window), "none");

    gtk_window_present(window);

    g_free(url);
    g_free(file_uri);
    g_free(index_path);
    g_free(web_root);
}

static void on_sigterm(int sig)
{
    (void)sig;
    if (window)
        quit_screensaver();
}

int main(int argc, char *argv[])
{
    signal(SIGTERM, on_sigterm);

    GtkApplication *app = gtk_application_new(
        "com.rezmason.matrix-screensaver",
        G_APPLICATION_DEFAULT_FLAGS);

    g_signal_connect(app, "activate", G_CALLBACK(activate), NULL);

    int status = g_application_run(G_APPLICATION(app), argc, argv);
    g_object_unref(app);
    return status;
}
