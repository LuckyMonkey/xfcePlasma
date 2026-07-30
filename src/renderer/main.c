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
#include <errno.h>
#include <sys/inotify.h>

#ifndef XFCE_PLASMA_VERSION
#define XFCE_PLASMA_VERSION "unknown"
#endif

static volatile sig_atomic_t fade_out_requested = 0;
static volatile sig_atomic_t terminate_requested = 0;

static void request_fade_out(int sig) {
    (void)sig;
    fade_out_requested = 1;
}

static void request_termination(int sig) {
    (void)sig;
    terminate_requested = 1;
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

static int read_target_fps(void) {
    const char *value = getenv("WALLPAPER_FPS");
    char *end = NULL;
    long parsed;

    if (!value || !*value) return 30;
    errno = 0;
    parsed = strtol(value, &end, 10);
    if (errno != 0 || end == value || *end != '\0' || parsed < 1 || parsed > 240) {
        fprintf(stderr, "warning: invalid WALLPAPER_FPS=%s; using 30\n", value);
        return 30;
    }
    return (int)parsed;
}

static float read_render_scale(void) {
    const char *value = getenv("WALLPAPER_RENDER_SCALE");
    char *end = NULL;
    float parsed;

    if (!value || !*value) return 1.0f;
    errno = 0;
    parsed = strtof(value, &end);
    if (errno != 0 || end == value || *end != '\0' || parsed < 0.25f || parsed > 1.0f) {
        fprintf(stderr, "warning: invalid WALLPAPER_RENDER_SCALE=%s; using 1.0\n", value);
        return 1.0f;
    }
    return parsed;
}

static int scaled_dimension(int value, float scale) {
    float scaled = (float)value * scale;
    if (scaled < 1.0f) return 1;
    if (scaled > (float)INT_MAX) return value;
    return (int)(scaled + 0.5f);
}

static RenderTexture2D load_color_render_target(int width, int height) {
    RenderTexture2D target = {0};
    Image image = GenImageColor(width, height, BLACK);
    target.id = rlLoadFramebuffer();
    target.texture = LoadTextureFromImage(image);
    UnloadImage(image);
    if (target.id == 0U || target.texture.id == 0U) goto failure;
    rlFramebufferAttach(target.id, target.texture.id, RL_ATTACHMENT_COLOR_CHANNEL0,
        RL_ATTACHMENT_TEXTURE2D, 0);
    if (!rlFramebufferComplete(target.id)) goto failure;
    return target;

failure:
    if (target.texture.id != 0U) rlUnloadTexture(target.texture.id);
    if (target.id != 0U) rlUnloadFramebuffer(target.id);
    return (RenderTexture2D){0};
}

static void unload_color_render_target(RenderTexture2D target) {
    if (target.texture.id != 0U) rlUnloadTexture(target.texture.id);
    if (target.id != 0U) rlUnloadFramebuffer(target.id);
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



#define ACTIVE_SHADER_PATH "shader.fs"
#define RELOAD_FADE_SECONDS 0.35f

typedef struct ManagedShader {
    Shader shader;
    int resolution_location;
    int time_location;
    int speed_location;
    int fade_location;
    int fade_target_location;
} ManagedShader;

static const char *fallback_fragment_shader =
    "#version 330\n"
    "in vec2 fragTexCoord;\n"
    "uniform float time;\n"
    "uniform vec2 resolution;\n"
    "uniform float fade;\n"
    "out vec4 finalColor;\n"
    "void main(void) {\n"
    "    vec2 uv = fragTexCoord;\n"
    "    float aspect = resolution.x/max(resolution.y, 1.0);\n"
    "    uv.x = (uv.x - 0.5)*aspect + 0.5;\n"
    "    float pulse = 0.08*sin(time*0.35);\n"
    "    vec3 low = vec3(0.04, 0.08, 0.16);\n"
    "    vec3 high = vec3(0.18, 0.38, 0.58);\n"
    "    vec3 color = mix(low, high, clamp(uv.y + pulse, 0.0, 1.0));\n"
    "    color += 0.035*cos(6.28318*uv.x + time*0.2);\n"
    "    finalColor = vec4(color*fade, 1.0);\n"
    "}\n";

static bool shader_is_custom(Shader shader) {
    return IsShaderValid(shader) && shader.id != rlGetShaderIdDefault();
}

static void unload_candidate(Shader shader) {
    if (shader_is_custom(shader)) UnloadShader(shader);
}

static bool populate_managed_shader(Shader shader, ManagedShader *managed) {
    if (!shader_is_custom(shader)) return false;
    managed->shader = shader;
    managed->resolution_location = GetShaderLocation(shader, "resolution");
    managed->time_location = GetShaderLocation(shader, "time");
    managed->speed_location = GetShaderLocation(shader, "speed");
    managed->fade_location = GetShaderLocation(shader, "fade");
    managed->fade_target_location = GetShaderLocation(shader, "fadeTarget");
    if (managed->resolution_location < 0 || managed->time_location < 0) {
        fprintf(stderr, "shader rejected: required resolution/time uniform missing\n");
        return false;
    }
    return true;
}

static bool load_shader_file(const char *path, ManagedShader *managed) {
    Shader candidate = LoadShader(NULL, path);
    if (!populate_managed_shader(candidate, managed)) {
        unload_candidate(candidate);
        fprintf(stderr, "shader rejected: could not compile %s; keeping current shader\n", path);
        return false;
    }
    return true;
}

static bool load_fallback_shader(ManagedShader *managed) {
    Shader candidate = LoadShaderFromMemory(NULL, fallback_fragment_shader);
    if (!populate_managed_shader(candidate, managed)) {
        unload_candidate(candidate);
        fprintf(stderr, "fatal: built-in fallback shader could not compile\n");
        return false;
    }
    return true;
}

static bool replace_shader(ManagedShader *active, const char *path) {
    ManagedShader candidate;
    if (!load_shader_file(path, &candidate)) return false;
    UnloadShader(active->shader);
    *active = candidate;
    fprintf(stderr, "shader reloaded: %s\n", path);
    return true;
}

static int open_shader_watch(void) {
    int descriptor = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
    if (descriptor < 0) {
        fprintf(stderr, "warning: live shader reload unavailable: %s\n", strerror(errno));
        return -1;
    }
    if (inotify_add_watch(descriptor, ".", IN_CLOSE_WRITE | IN_MOVED_TO | IN_CREATE) < 0) {
        fprintf(stderr, "warning: cannot watch shader directory: %s\n", strerror(errno));
        close(descriptor);
        return -1;
    }
    return descriptor;
}

static bool shader_file_changed(int descriptor) {
    union {
        char bytes[4096];
        struct inotify_event alignment;
    } buffer;
    bool changed = false;

    for (;;) {
        ssize_t length = read(descriptor, buffer.bytes, sizeof(buffer.bytes));
        if (length < 0) {
            if (errno == EINTR) continue;
            if (errno != EAGAIN && errno != EWOULDBLOCK)
                fprintf(stderr, "warning: shader watch read failed: %s\n", strerror(errno));
            return changed;
        }
        if (length == 0) return changed;

        size_t offset = 0;
        size_t available = (size_t)length;
        while (offset < available) {
            const struct inotify_event *event =
                (const struct inotify_event *)(const void *)(buffer.bytes + offset);
            if (event->len > 0U && strcmp(event->name, ACTIVE_SHADER_PATH) == 0)
                changed = true;
            offset += sizeof(*event) + (size_t)event->len;
        }
    }
}

int main(int argc, char **argv) {
    Window parent = 0;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--version")) {
            printf("xfce-plasma-renderer %s\n", XFCE_PLASMA_VERSION);
            return 0;
        }
        if (!strcmp(argv[i], "--wid") && i + 1 < argc)
            parent = strtoul(argv[++i], NULL, 0);
    }
    SetConfigFlags(FLAG_WINDOW_UNDECORATED | FLAG_VSYNC_HINT | FLAG_WINDOW_RESIZABLE);

    Display *d = XOpenDisplay(NULL);
    if (d) XSetErrorHandler(ignore_x_error);
    int width = 800, height = 450;
    if (d) {
        width = DisplayWidth(d, DefaultScreen(d));
        height = DisplayHeight(d, DefaultScreen(d));
    }

    InitWindow(width, height, "xfcePlasma Background");

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
    signal(SIGTERM, request_termination);
    signal(SIGINT, request_termination);

    ManagedShader active_shader;
    if (!load_shader_file(ACTIVE_SHADER_PATH, &active_shader) &&
        !load_fallback_shader(&active_shader)) {
        CloseWindow();
        if (d) XCloseDisplay(d);
        return 1;
    }
    int shader_watch = open_shader_watch();
    int reload_state = 0;
    float reload_start = 0.0f;
    float fade_target = 0.0f;
    float fade_seconds = 2.40f;
    float start_time = (float)GetTime();
    float last_time = start_time;
    float shader_time = start_time;
    float fade_out_start = -1.0f;
    int target_fps = read_target_fps();
    float render_scale = read_render_scale();
    RenderTexture2D render_target = {0};
    int target_width = 0;
    int target_height = 0;
    bool low_power = false;
    fprintf(stderr, "performance: fps=%d render-scale=%.2f\n", target_fps, (double)render_scale);
    SetTargetFPS(target_fps);
    while (!terminate_requested) {
        if (!parent && IsKeyPressed(KEY_F)) ToggleFullscreen();
        if (d && !parent) {
            Window own = find_pid_wait(d, DefaultRootWindow(d),
                XInternAtom(d, "_NET_WM_PID", False), (unsigned long)getpid());
            if (own) XLowerWindow(d, own);
            XFlush(d);
        }
        int screen_width = GetScreenWidth();
        int screen_height = GetScreenHeight();
        int wanted_width = scaled_dimension(screen_width, render_scale);
        int wanted_height = scaled_dimension(screen_height, render_scale);
        bool scaled_rendering = render_scale < 0.999f;
        if (scaled_rendering && (render_target.id == 0U || target_width != wanted_width || target_height != wanted_height)) {
            if (render_target.id != 0U) unload_color_render_target(render_target);
            render_target = load_color_render_target(wanted_width, wanted_height);
            if (render_target.id == 0U || render_target.texture.id == 0U) {
                fprintf(stderr, "warning: render-scale framebuffer unavailable; using native resolution\n");
                render_target = (RenderTexture2D){0};
                render_scale = 1.0f;
                scaled_rendering = false;
                wanted_width = screen_width;
                wanted_height = screen_height;
            } else {
                target_width = wanted_width;
                target_height = wanted_height;
                fprintf(stderr, "render target: %dx%d (desktop %dx%d)\n",
                    target_width, target_height, screen_width, screen_height);
            }
        }
        float resolution[2] = {(float)wanted_width, (float)wanted_height};
        float real_time = (float)GetTime();
        if (shader_watch >= 0 && shader_file_changed(shader_watch) && reload_state == 0) {
            reload_state = 1;
            reload_start = real_time;
            fprintf(stderr, "shader change detected; validating candidate\n");
        }
        float reload_fade = 1.0f;
        if (reload_state == 1) {
            float progress = clamp01((real_time - reload_start) / RELOAD_FADE_SECONDS);
            reload_fade = 1.0f - smoothstep01(progress);
            if (progress >= 1.0f) {
                (void)replace_shader(&active_shader, ACTIVE_SHADER_PATH);
                reload_state = 2;
                reload_start = real_time;
                reload_fade = 0.0f;
            }
        } else if (reload_state == 2) {
            float progress = clamp01((real_time - reload_start) / RELOAD_FADE_SECONDS);
            reload_fade = smoothstep01(progress);
            if (progress >= 1.0f) reload_state = 0;
        }
        float dt = real_time - last_time;
        if (dt < 0.0f || dt > 1.0f) dt = 0.0f;
        last_time = real_time;
        float speed = read_wallpaper_speed();
        shader_time += dt * speed;
        bool should_use_low_power =
            speed <= 0.0001f && reload_state == 0 &&
            !fade_out_requested && (real_time - start_time) >= fade_seconds;
        if (should_use_low_power != low_power) {
            low_power = should_use_low_power;
            SetTargetFPS(low_power && target_fps > 5 ? 5 : target_fps);
        }
        float time = real_time;
        if (fade_out_requested && fade_out_start < 0.0f) fade_out_start = time;
        float fade;
        if (fade_out_start >= 0.0f) {
            fade = 1.0f - smoothstep01((time - fade_out_start) / fade_seconds);
            if (fade <= 0.001f) break;
        } else {
            fade = smoothstep01((time - start_time) / fade_seconds);
        }
        fade *= reload_fade;
        SetShaderValue(active_shader.shader, active_shader.resolution_location, resolution, SHADER_UNIFORM_VEC2);
        SetShaderValue(active_shader.shader, active_shader.time_location, &shader_time, SHADER_UNIFORM_FLOAT);
        SetShaderValue(active_shader.shader, active_shader.speed_location, &speed, SHADER_UNIFORM_FLOAT);
        SetShaderValue(active_shader.shader, active_shader.fade_location, &fade, SHADER_UNIFORM_FLOAT);
        SetShaderValue(active_shader.shader, active_shader.fade_target_location, &fade_target, SHADER_UNIFORM_FLOAT);
        if (scaled_rendering) {
            BeginTextureMode(render_target);
            ClearBackground(BLACK);
            BeginShaderMode(active_shader.shader);
            DrawRectangle(0, 0, wanted_width, wanted_height, WHITE);
            EndShaderMode();
            EndTextureMode();
            BeginDrawing();
            ClearBackground(BLACK);
            DrawTexturePro(render_target.texture,
                (Rectangle){0.0f, 0.0f, (float)wanted_width, (float)-wanted_height},
                (Rectangle){0.0f, 0.0f, (float)screen_width, (float)screen_height},
                (Vector2){0.0f, 0.0f}, 0.0f, WHITE);
            EndDrawing();
        } else {
            BeginDrawing(); BeginShaderMode(active_shader.shader);
            DrawRectangle(0, 0, screen_width, screen_height, WHITE);
            EndShaderMode(); EndDrawing();
        }
    }
    if (shader_watch >= 0) close(shader_watch);
    if (render_target.id != 0U) unload_color_render_target(render_target);
    UnloadShader(active_shader.shader);
    CloseWindow();
    if (d) XCloseDisplay(d);
    return 0;
}
