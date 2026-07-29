#include "raylib.h"
#include "rlgl.h"
#define Font X11Font
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#undef Font
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdio.h>
#include <signal.h>
#include <limits.h>

static volatile sig_atomic_t fade_out_requested = 0;

static void request_fade_out(int sig) {
    (void)sig;
    fade_out_requested = 1;
}

static float clamp01(float v) {
    if (v < 0.0f) return 0.0f;
    if (v > 1.0f) return 1.0f;
    return v;
}

static float smoothstep01(float t) {
    t = clamp01(t);
    return t * t * (3.0f - 2.0f * t);
}

static unsigned int positive_dimension(int value) {
    return value > 0 ? (unsigned int)value : 1U;
}

static bool resolve_speed_path(char *buffer, size_t capacity) {
    const char *explicit_path = getenv("WALLPAPER_SPEED_FILE");
    const char *state_home = getenv("XDG_STATE_HOME");
    const char *home = getenv("HOME");
    int written;

    if (explicit_path && *explicit_path) {
        written = snprintf(buffer, capacity, "%s", explicit_path);
    } else if (state_home && *state_home) {
        written = snprintf(buffer, capacity, "%s/tie-dye-wallpaper/speed", state_home);
    } else if (home && *home) {
        written = snprintf(buffer, capacity, "%s/.local/state/tie-dye-wallpaper/speed", home);
    } else {
        return false;
    }
    return written >= 0 && (size_t)written < capacity;
}

static float read_wallpaper_speed(void) {
    char path[PATH_MAX];
    if (!resolve_speed_path(path, sizeof(path))) return 1.0f;
    FILE *f = fopen(path, "r");
    if (!f) return 1.0f;
    float speed = 1.0f;
    if (fscanf(f, "%f", &speed) != 1) speed = 1.0f;
    fclose(f);
    if (speed < 0.0f) speed = 0.0f;
    if (speed > 4.0f) speed = 4.0f;
    return speed;
}

static Window find_pid(Display *d, Window w, Atom pid_atom, unsigned long pid) {
    Atom type; int format; unsigned long n, left, *value = NULL;
    if (XGetWindowProperty(d, w, pid_atom, 0, 1, False, XA_CARDINAL,
        &type, &format, &n, &left, (unsigned char **)&value) == Success && value) {
        bool hit = n && *value == pid; XFree(value); if (hit) return w;
    }
    Window root, parent, *children = NULL, hit = 0; unsigned count = 0;
    if (XQueryTree(d, w, &root, &parent, &children, &count))
        for (unsigned i = 0; i < count && !hit; i++) hit = find_pid(d, children[i], pid_atom, pid);
    if (children) XFree(children);
    return hit;
}

static Window find_pid_wait(Display *d, Window root, Atom pid_atom, unsigned long pid) {
    Window own = 0;
    for (int attempt = 0; attempt < 40 && !own; attempt++) {
        own = find_pid(d, root, pid_atom, pid);
        if (!own) usleep(50000);
    }
    return own;
}

static int ignore_x_error(Display *d, XErrorEvent *e) {
    char msg[128];
    XGetErrorText(d, e->error_code, msg, sizeof(msg));
    fprintf(stderr, "ignored X error: %s (request %u resource 0x%lx)\n",
            msg, e->request_code, e->resourceid);
    return 0;
}

static void set_desktop_hints(Display *d, Window w) {
    Atom type_atom = XInternAtom(d, "_NET_WM_WINDOW_TYPE", False);
    Atom state_atom = XInternAtom(d, "_NET_WM_STATE", False);
    Atom protocols = XInternAtom(d, "WM_PROTOCOLS", False);
    Atom wm_delete = XInternAtom(d, "WM_DELETE_WINDOW", False);
    XSetWindowAttributes attrs;

    attrs.override_redirect = True;
    XChangeWindowAttributes(d, w, CWOverrideRedirect, &attrs);
    XDeleteProperty(d, w, type_atom);
    XDeleteProperty(d, w, state_atom);
    XDeleteProperty(d, w, protocols);
    XDeleteProperty(d, w, wm_delete);
    XMoveResizeWindow(d, w, 0, 0, positive_dimension(DisplayWidth(d, DefaultScreen(d))), positive_dimension(DisplayHeight(d, DefaultScreen(d))));
    XLowerWindow(d, w);
    XMapWindow(d, w);
    XFlush(d);
}


int main(int argc, char **argv) {
    Window parent = 0;
    for (int i = 1; i < argc; i++) if (!strcmp(argv[i], "--wid") && i + 1 < argc)
        parent = strtoul(argv[++i], NULL, 0);
    SetConfigFlags(FLAG_WINDOW_UNDECORATED | FLAG_VSYNC_HINT | FLAG_WINDOW_RESIZABLE);

    Display *d = XOpenDisplay(NULL);
    if (d) XSetErrorHandler(ignore_x_error);
    int width = 800, height = 450;
    if (d) {
        width = DisplayWidth(d, DefaultScreen(d));
        height = DisplayHeight(d, DefaultScreen(d));
    }

    InitWindow(width, height, "Tie Dye GPU Wallpaper");

    if (d) {
        XWindowAttributes a;
        Window own = find_pid_wait(d, DefaultRootWindow(d),
            XInternAtom(d, "_NET_WM_PID", False), (unsigned long)getpid());

        if (parent && XGetWindowAttributes(d, parent, &a)) {
            if (own) {
                XReparentWindow(d, own, parent, 0, 0);
                XResizeWindow(d, own, positive_dimension(a.width), positive_dimension(a.height));
                XMapWindow(d, own);
                XFlush(d);
            }
            width = a.width;
            height = a.height;
        } else {
            SetWindowPosition(0, 0);
            SetWindowSize(width, height);
            if (own) set_desktop_hints(d, own);
        }
    }

    signal(SIGUSR1, request_fade_out);

    Shader shader = LoadShader(0, "shader.fs");
    int resLoc = GetShaderLocation(shader, "resolution");
    int timeLoc = GetShaderLocation(shader, "time");
    int fadeLoc = GetShaderLocation(shader, "fade");
    int fadeTargetLoc = GetShaderLocation(shader, "fadeTarget");
    float fade_target = 0.0f;
    float fade_seconds = 2.40f;
    float start_time = (float)GetTime();
    float last_time = start_time;
    float shader_time = start_time;
    float fade_out_start = -1.0f;
    SetTargetFPS(30);
    while (true) {
        if (!parent && IsKeyPressed(KEY_F)) ToggleFullscreen();
        if (d && !parent) {
            Window own = find_pid_wait(d, DefaultRootWindow(d),
                XInternAtom(d, "_NET_WM_PID", False), (unsigned long)getpid());
            if (own) XLowerWindow(d, own);
            XFlush(d);
        }
        float resolution[2] = {(float)GetScreenWidth(), (float)GetScreenHeight()};
        float real_time = (float)GetTime();
        float dt = real_time - last_time;
        if (dt < 0.0f || dt > 1.0f) dt = 0.0f;
        last_time = real_time;
        shader_time += dt * read_wallpaper_speed();
        float time = real_time;
        if (fade_out_requested && fade_out_start < 0.0f) fade_out_start = time;
        float fade;
        if (fade_out_start >= 0.0f) {
            fade = 1.0f - smoothstep01((time - fade_out_start) / fade_seconds);
            if (fade <= 0.001f) break;
        } else {
            fade = smoothstep01((time - start_time) / fade_seconds);
        }
        SetShaderValue(shader, resLoc, resolution, SHADER_UNIFORM_VEC2);
        SetShaderValue(shader, timeLoc, &shader_time, SHADER_UNIFORM_FLOAT);
        SetShaderValue(shader, fadeLoc, &fade, SHADER_UNIFORM_FLOAT);
        SetShaderValue(shader, fadeTargetLoc, &fade_target, SHADER_UNIFORM_FLOAT);
        BeginDrawing(); BeginShaderMode(shader);
        DrawRectangle(0, 0, GetScreenWidth(), GetScreenHeight(), WHITE);
        EndShaderMode(); EndDrawing();
    }
    UnloadShader(shader); CloseWindow();
    return 0;
}
