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
#include <time.h>
#include <sys/inotify.h>
#include <float.h>
#include <math.h>
#include <stdarg.h>

#ifndef XFCE_PLASMA_VERSION
#define XFCE_PLASMA_VERSION "unknown"
#endif

#define RELOAD_FADE_SECONDS 0.35f

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

static void trace_log_stderr(int log_level, const char *text, va_list args) {
    (void)log_level;
    vfprintf(stderr, text, args);
    fputc('\n', stderr);
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

static bool copy_path(char *buffer, size_t capacity, const char *value) {
    int written;
    if (!buffer || capacity == 0U || !value || !*value) return false;
    written = snprintf(buffer, capacity, "%s", value);
    return written >= 0 && (size_t)written < capacity;
}

static bool executable_directory(char *buffer, size_t capacity) {
    char executable[PATH_MAX];
    ssize_t length;
    char *slash;

    if (!buffer || capacity == 0U) return false;
    length = readlink("/proc/self/exe", executable, sizeof(executable) - 1U);
    if (length <= 0 || (size_t)length >= sizeof(executable)) return false;
    executable[length] = '\0';
    slash = strrchr(executable, '/');
    if (!slash) return false;
    if (slash == executable) slash[1] = '\0';
    else *slash = '\0';
    return copy_path(buffer, capacity, executable);
}

static bool sibling_path(char *buffer, size_t capacity, const char *name) {
    char directory[PATH_MAX];
    int written;
    if (!name || !*name || !executable_directory(directory, sizeof(directory))) return false;
    written = snprintf(buffer, capacity, "%s/%s", directory, name);
    return written >= 0 && (size_t)written < capacity;
}

static const char *path_basename(const char *path) {
    const char *slash;
    if (!path) return "";
    slash = strrchr(path, '/');
    return slash ? slash + 1 : path;
}

static bool path_directory(char *buffer, size_t capacity, const char *path) {
    const char *slash;
    size_t length;

    if (!buffer || capacity == 0U || !path || !*path) return false;
    slash = strrchr(path, '/');
    if (!slash) return copy_path(buffer, capacity, ".");
    if (slash == path) return copy_path(buffer, capacity, "/");
    length = (size_t)(slash - path);
    if (length >= capacity) return false;
    memcpy(buffer, path, length);
    buffer[length] = '\0';
    return true;
}

static bool resolve_shader_path(char *buffer, size_t capacity) {
    const char *explicit_path = getenv("WALLPAPER_SHADER_FILE");
    char candidate[PATH_MAX];

    if (explicit_path && *explicit_path) return copy_path(buffer, capacity, explicit_path);

    if (sibling_path(candidate, sizeof(candidate), "shader.fs") && access(candidate, R_OK) == 0)
        return copy_path(buffer, capacity, candidate);

    if (access("runtime/tie-dye-wallpaper/shader.fs", R_OK) == 0)
        return copy_path(buffer, capacity, "runtime/tie-dye-wallpaper/shader.fs");

    return copy_path(buffer, capacity, "shader.fs");
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
    FILE *f;
    float speed = 1.0f;

    if (!resolve_speed_path(path, sizeof(path))) return 1.0f;
    f = fopen(path, "r");
    if (!f) return 1.0f;
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
    SetTextureFilter(target.texture, TEXTURE_FILTER_BILINEAR);
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
    Atom type;
    int format;
    unsigned long n, left, *value = NULL;
    Window root, parent, *children = NULL, hit = 0;
    unsigned count = 0;

    if (XGetWindowProperty(d, w, pid_atom, 0, 1, False, XA_CARDINAL,
        &type, &format, &n, &left, (unsigned char **)&value) == Success && value) {
        bool matches = n && *value == pid;
        XFree(value);
        if (matches) return w;
    }
    if (XQueryTree(d, w, &root, &parent, &children, &count)) {
        for (unsigned i = 0; i < count && !hit; i++)
            hit = find_pid(d, children[i], pid_atom, pid);
    }
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
    XMoveResizeWindow(d, w, 0, 0,
        positive_dimension(DisplayWidth(d, DefaultScreen(d))),
        positive_dimension(DisplayHeight(d, DefaultScreen(d))));
    XLowerWindow(d, w);
    XMapWindow(d, w);
    XFlush(d);
}

typedef struct ManagedShader {
    Shader shader;
    int resolution_location;
    int time_location;
    int speed_location;
    int fade_location;
    int fade_target_location;
    int glyph_atlas_location;
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

static Texture2D make_glyph_fallback_texture(void) {
    Image image = GenImageColor(1, 1, WHITE);
    Texture2D texture = LoadTextureFromImage(image);
    UnloadImage(image);
    if (texture.id != 0U) SetTextureFilter(texture, TEXTURE_FILTER_POINT);
    return texture;
}

static bool resolve_glyph_atlas_path(char *buffer, size_t capacity) {
    const char *explicit_path = getenv("WALLPAPER_GLYPH_ATLAS");
    char candidate[PATH_MAX];

    if (explicit_path && *explicit_path) return copy_path(buffer, capacity, explicit_path);
    if (sibling_path(candidate, sizeof(candidate), "glyph-atlas.png") && access(candidate, R_OK) == 0)
        return copy_path(buffer, capacity, candidate);
    return false;
}

static Texture2D load_glyph_atlas(void) {
    char atlas_path[PATH_MAX];
    Texture2D fallback = make_glyph_fallback_texture();
    Image image;
    Texture2D atlas;

    if (!resolve_glyph_atlas_path(atlas_path, sizeof(atlas_path))) {
        fprintf(stderr, "glyph atlas: none found; using shader built-in glyphs\n");
        return fallback;
    }
    if (access(atlas_path, R_OK) != 0) {
        fprintf(stderr, "warning: glyph atlas unreadable: %s: %s; using built-in glyphs\n",
            atlas_path, strerror(errno));
        return fallback;
    }

    image = LoadImage(atlas_path);
    if (!image.data) {
        fprintf(stderr, "warning: glyph atlas could not be decoded: %s; using built-in glyphs\n",
            atlas_path);
        return fallback;
    }
    atlas = LoadTextureFromImage(image);
    UnloadImage(image);
    if (atlas.id == 0U) {
        fprintf(stderr, "warning: glyph atlas texture upload failed: %s; using built-in glyphs\n",
            atlas_path);
        return fallback;
    }

    if (fallback.id != 0U) UnloadTexture(fallback);
    SetTextureFilter(atlas, TEXTURE_FILTER_POINT);
    fprintf(stderr, "glyph atlas: %s\n", atlas_path);
    return atlas;
}

static bool populate_managed_shader(Shader shader, ManagedShader *managed) {
    if (!shader_is_custom(shader)) return false;
    managed->shader = shader;
    managed->resolution_location = GetShaderLocation(shader, "resolution");
    managed->time_location = GetShaderLocation(shader, "time");
    managed->speed_location = GetShaderLocation(shader, "speed");
    managed->fade_location = GetShaderLocation(shader, "fade");
    managed->fade_target_location = GetShaderLocation(shader, "fadeTarget");
    managed->glyph_atlas_location = GetShaderLocation(shader, "glyphAtlas");
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

static void set_shader_float(Shader shader, int location, float value) {
    if (location >= 0) SetShaderValue(shader, location, &value, SHADER_UNIFORM_FLOAT);
}

static void set_shader_vec2(Shader shader, int location, const float value[2]) {
    if (location >= 0) SetShaderValue(shader, location, value, SHADER_UNIFORM_VEC2);
}

static void set_shader_texture(Shader shader, int location, Texture2D texture) {
    if (location >= 0 && texture.id != 0U) SetShaderValueTexture(shader, location, texture);
}

static int open_shader_watch(const char *shader_path) {
    char directory[PATH_MAX];
    int descriptor;

    if (!path_directory(directory, sizeof(directory), shader_path)) {
        fprintf(stderr, "warning: live shader reload unavailable: invalid shader path %s\n",
            shader_path ? shader_path : "(null)");
        return -1;
    }

    descriptor = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
    if (descriptor < 0) {
        fprintf(stderr, "warning: live shader reload unavailable: %s\n", strerror(errno));
        return -1;
    }
    if (inotify_add_watch(descriptor, directory, IN_CLOSE_WRITE | IN_MOVED_TO | IN_CREATE) < 0) {
        fprintf(stderr, "warning: cannot watch shader directory %s: %s\n",
            directory, strerror(errno));
        close(descriptor);
        return -1;
    }
    fprintf(stderr, "shader watch: %s\n", directory);
    return descriptor;
}

static bool shader_file_changed(int descriptor, const char *shader_name) {
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
            if (event->len > 0U && strcmp(event->name, shader_name) == 0)
                changed = true;
            offset += sizeof(*event) + (size_t)event->len;
        }
    }
}

static float randomized_shader_time(void) {
    unsigned long seed = (unsigned long)time(NULL);
    seed ^= (unsigned long)getpid() * 2654435761UL;
    return (float)(seed % 360000UL) / 100.0f;
}

static void set_embedded_hints(Display *d, Window w) {
    Atom type = XInternAtom(d, "_NET_WM_WINDOW_TYPE", False);
    Atom desktop = XInternAtom(d, "_NET_WM_WINDOW_TYPE_DESKTOP", False);
    Atom state = XInternAtom(d, "_NET_WM_STATE", False);
    Atom skip_taskbar = XInternAtom(d, "_NET_WM_STATE_SKIP_TASKBAR", False);
    Atom skip_pager = XInternAtom(d, "_NET_WM_STATE_SKIP_PAGER", False);
    Atom states[2] = {skip_taskbar, skip_pager};
    XSetWindowAttributes attrs;
    attrs.override_redirect = True;
    XChangeWindowAttributes(d, w, CWOverrideRedirect, &attrs);
    XChangeProperty(d, w, type, XA_ATOM, 32, PropModeReplace, (unsigned char *)&desktop, 1);
    XChangeProperty(d, w, state, XA_ATOM, 32, PropModeReplace, (unsigned char *)states, 2);
    XDeleteProperty(d, w, XInternAtom(d, "_NET_WM_PID", False));
    XFlush(d);
}

typedef struct RendererOptions {
    Window parent;
    char shader_path[PATH_MAX];
    char capture_path[PATH_MAX];
    int width;
    int height;
    float fixed_time;
    float benchmark_seconds;
    bool fixed_time_set;
    bool capture_mode;
    bool benchmark_mode;
    bool json_output;
} RendererOptions;

static void print_usage(const char *program) {
    printf("usage: %s [--wid XID] [--shader PATH] [--capture PNG] [options]\n"
           "       %s --benchmark SECONDS [options]\n\n"
           "options:\n"
           "  --shader PATH       render this fragment shader\n"
           "  --capture PNG       render one deterministic frame and exit\n"
           "  --benchmark SEC     benchmark steady-state rendering\n"
           "  --width N           capture/benchmark width (default: 320)\n"
           "  --height N          capture/benchmark height (default: 180)\n"
           "  --time SEC          fixed shader time (default: 0)\n"
           "  --no-random-phase   start normal wallpaper time at zero\n"
           "  --json              emit benchmark results as JSON\n"
           "  --wid XID           embed in an existing X11 window\n"
           "  --version           print the renderer version\n"
           "  --help              show this help\n", program, program);
}

static bool parse_float_argument(const char *text, float *value) {
    char *end = NULL;
    float parsed;
    if (!text || !*text) return false;
    errno = 0;
    parsed = strtof(text, &end);
    if (errno != 0 || end == text || *end != '\0' || !isfinite(parsed)) return false;
    *value = parsed;
    return true;
}

static bool parse_positive_int(const char *text, int *value) {
    char *end = NULL;
    long parsed;
    if (!text || !*text) return false;
    errno = 0;
    parsed = strtol(text, &end, 10);
    if (errno != 0 || end == text || *end != '\0' || parsed < 1 || parsed > INT_MAX) return false;
    *value = (int)parsed;
    return true;
}

static bool parse_window_id(const char *text, Window *value) {
    char *end = NULL;
    unsigned long parsed;
    if (!text || !*text) return false;
    errno = 0;
    parsed = strtoul(text, &end, 0);
    if (errno != 0 || end == text || *end != '\0' || parsed == 0UL) return false;
    *value = (Window)parsed;
    return true;
}

static int compare_doubles(const void *left, const void *right) {
    const double a = *(const double *)left;
    const double b = *(const double *)right;
    return (a > b) - (a < b);
}

static void json_escape(char *buffer, size_t capacity, const char *text) {
    size_t offset = 0U;
    if (!buffer || capacity == 0U) return;
    for (const unsigned char *cursor = (const unsigned char *)(text ? text : ""); *cursor && offset + 2U < capacity; cursor++) {
        if (*cursor == '\\' || *cursor == '"') {
            if (offset + 2U >= capacity) break;
            buffer[offset++] = '\\';
            buffer[offset++] = (char)*cursor;
        } else if (*cursor == '\n' || *cursor == '\r' || *cursor == '\t') {
            if (offset + 2U >= capacity) break;
            buffer[offset++] = '\\';
            buffer[offset++] = *cursor == '\n' ? 'n' : (*cursor == '\r' ? 'r' : 't');
        } else if (*cursor >= 0x20U) {
            buffer[offset++] = (char)*cursor;
        }
    }
    buffer[offset] = '\0';
}

static bool parse_options(int argc, char **argv, RendererOptions *options) {
    memset(options, 0, sizeof(*options));
    for (int i = 1; i < argc; i++) {
        const char *argument = argv[i];
        const char *value = i + 1 < argc ? argv[i + 1] : NULL;
        if (!strcmp(argument, "--version")) {
            printf("xfce-plasma-renderer %s\n", XFCE_PLASMA_VERSION);
            exit(0);
        } else if (!strcmp(argument, "--help")) {
            print_usage(argv[0]);
            exit(0);
        } else if (!strcmp(argument, "--no-random-phase")) {
            options->fixed_time = 0.0f;
            options->fixed_time_set = true;
        } else if (!strcmp(argument, "--json")) {
            options->json_output = true;
        } else if (!strcmp(argument, "--wid") || !strcmp(argument, "--shader") ||
                   !strcmp(argument, "--capture") || !strcmp(argument, "--width") ||
                   !strcmp(argument, "--height") || !strcmp(argument, "--time") ||
                   !strcmp(argument, "--benchmark")) {
            if (!value) {
                fprintf(stderr, "error: %s requires a value\n", argument);
                return false;
            }
            if (!strcmp(argument, "--wid")) {
                if (!parse_window_id(value, &options->parent)) {
                    fprintf(stderr, "error: invalid X11 window ID: %s\n", value);
                    return false;
                }
            } else if (!strcmp(argument, "--shader")) {
                if (!copy_path(options->shader_path, sizeof(options->shader_path), value)) {
                    fprintf(stderr, "error: shader path is too long\n");
                    return false;
                }
            } else if (!strcmp(argument, "--capture")) {
                if (!copy_path(options->capture_path, sizeof(options->capture_path), value)) {
                    fprintf(stderr, "error: capture path is too long\n");
                    return false;
                }
                options->capture_mode = true;
            } else if (!strcmp(argument, "--width")) {
                if (!parse_positive_int(value, &options->width)) {
                    fprintf(stderr, "error: invalid width: %s\n", value);
                    return false;
                }
            } else if (!strcmp(argument, "--height")) {
                if (!parse_positive_int(value, &options->height)) {
                    fprintf(stderr, "error: invalid height: %s\n", value);
                    return false;
                }
            } else if (!strcmp(argument, "--time")) {
                if (!parse_float_argument(value, &options->fixed_time)) {
                    fprintf(stderr, "error: invalid time: %s\n", value);
                    return false;
                }
                options->fixed_time_set = true;
            } else {
                if (!parse_float_argument(value, &options->benchmark_seconds) ||
                    options->benchmark_seconds <= 0.0f) {
                    fprintf(stderr, "error: invalid benchmark duration: %s\n", value);
                    return false;
                }
                options->benchmark_mode = true;
            }
            i++;
        } else {
            fprintf(stderr, "error: unknown argument: %s\n", argument);
            return false;
        }
    }
    if (options->capture_mode && options->benchmark_mode) {
        fprintf(stderr, "error: --capture and --benchmark cannot be combined\n");
        return false;
    }
    if ((options->capture_mode || options->benchmark_mode) && options->parent) {
        fprintf(stderr, "error: capture/benchmark cannot be combined with --wid\n");
        return false;
    }
    if (options->capture_mode && !options->capture_path[0]) {
        fprintf(stderr, "error: --capture requires a non-empty output path\n");
        return false;
    }
    if (options->capture_mode || options->benchmark_mode) {
        if (!options->width) options->width = 320;
        if (!options->height) options->height = 180;
    }
    return true;
}

int main(int argc, char **argv) {
    RendererOptions options;
    Window parent;
    char shader_path[PATH_MAX];
    const char *shader_name;
    float requested_time;
    int requested_width, requested_height;
    float benchmark_seconds;
    bool capture_mode, benchmark_mode, json_output;
    const char *capture_path;
    char json_shader_name[PATH_MAX * 2U];
    int exit_status = 0;

    if (!parse_options(argc, argv, &options)) {
        print_usage(argv[0]);
        return 2;
    }
    if (options.json_output) SetTraceLogCallback(trace_log_stderr);
    parent = options.parent;
    requested_time = options.fixed_time;
    requested_width = options.width;
    requested_height = options.height;
    benchmark_seconds = options.benchmark_seconds;
    capture_mode = options.capture_mode;
    benchmark_mode = options.benchmark_mode;
    json_output = options.json_output;
    capture_path = options.capture_path;
    if (options.shader_path[0]) {
        if (!copy_path(shader_path, sizeof(shader_path), options.shader_path)) {
            fprintf(stderr, "fatal: shader path is too long\n");
            return 2;
        }
    } else if (!resolve_shader_path(shader_path, sizeof(shader_path))) {
        fprintf(stderr, "fatal: could not resolve active shader path\n");
        return 1;
    }
    shader_name = path_basename(shader_path);
    json_escape(json_shader_name, sizeof(json_shader_name), shader_name);
    fprintf(stderr, "active shader: %s\n", shader_path);

    SetConfigFlags(FLAG_WINDOW_UNDECORATED | FLAG_VSYNC_HINT | FLAG_WINDOW_RESIZABLE |
        ((capture_mode || benchmark_mode) ? FLAG_WINDOW_HIDDEN : 0));

    Display *d = XOpenDisplay(NULL);
    if (d) XSetErrorHandler(ignore_x_error);
    int width = requested_width > 0 ? requested_width : 800;
    int height = requested_height > 0 ? requested_height : 450;
    if (d && !capture_mode && !benchmark_mode) {
        width = DisplayWidth(d, DefaultScreen(d));
        height = DisplayHeight(d, DefaultScreen(d));
    }

    InitWindow(width, height, "xfcePlasma Background");
    if (!IsWindowReady()) {
        fprintf(stderr, "fatal: renderer window/context could not be initialized\n");
        if (d) XCloseDisplay(d);
        return 1;
    }
    Texture2D glyph_atlas = load_glyph_atlas();

    if (d) {
        XWindowAttributes a;
        Window own = find_pid_wait(d, DefaultRootWindow(d),
            XInternAtom(d, "_NET_WM_PID", False), (unsigned long)getpid());

        if (parent && XGetWindowAttributes(d, parent, &a)) {
            if (own) {
                XReparentWindow(d, own, parent, 0, 0);
                set_embedded_hints(d, own);
                XResizeWindow(d, own, positive_dimension(a.width), positive_dimension(a.height));
                XMapWindow(d, own);
                XFlush(d);
            }
            width = a.width;
            height = a.height;
        } else {
            if (!capture_mode && !benchmark_mode) {
                SetWindowPosition(0, 0);
                SetWindowSize(width, height);
                if (own) set_desktop_hints(d, own);
            }
        }
    }

    signal(SIGUSR1, request_fade_out);
    signal(SIGTERM, request_termination);
    signal(SIGINT, request_termination);

    ManagedShader active_shader;
    if (!load_shader_file(shader_path, &active_shader)) {
        if (capture_mode || benchmark_mode) {
            fprintf(stderr, "fatal: requested shader failed to compile: %s\n", shader_path);
            if (glyph_atlas.id != 0U) UnloadTexture(glyph_atlas);
            CloseWindow();
            if (d) XCloseDisplay(d);
            return 1;
        }
        if (!load_fallback_shader(&active_shader)) {
            if (glyph_atlas.id != 0U) UnloadTexture(glyph_atlas);
            CloseWindow();
            if (d) XCloseDisplay(d);
            return 1;
        }
    }

    int shader_watch = capture_mode || benchmark_mode ? -1 : open_shader_watch(shader_path);
    int reload_state = 0;
    float reload_start = 0.0f;
    float fade_target = 0.0f;
    float fade_seconds = 2.40f;
    float start_time = (float)GetTime();
    float last_time = start_time;
    float shader_time = capture_mode || benchmark_mode || options.fixed_time_set ? requested_time : randomized_shader_time();
    fprintf(stderr, "shader phase: %.2f\n", (double)shader_time);
    float fade_out_start = -1.0f;
    int target_fps = read_target_fps();
    float render_scale = read_render_scale();
    RenderTexture2D render_target = {0};
    int target_width = 0;
    int target_height = 0;
    bool low_power = false;
    fprintf(stderr, "performance: fps=%d render-scale=%.2f\n", target_fps, (double)render_scale);
    if (capture_mode || benchmark_mode) SetTargetFPS(240);
    else SetTargetFPS(target_fps);
    struct timespec benchmark_start = {0}, frame_start, frame_end;
    double benchmark_sum = 0.0, benchmark_min = DBL_MAX, benchmark_max = 0.0;
    unsigned long benchmark_frames = 0, benchmark_warmup = 0;
    bool benchmark_started = false;
    double benchmark_elapsed = 0.0;
    double *benchmark_samples = NULL;
    size_t benchmark_sample_capacity = 0U;

    while (!terminate_requested) {
        if (!parent && IsKeyPressed(KEY_F)) ToggleFullscreen();
        if (IsKeyPressed(KEY_ESCAPE)) fade_out_requested = 1;
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
        bool scaled_rendering = render_scale < 0.999f || capture_mode || benchmark_mode;
        if (capture_mode || benchmark_mode) {
            wanted_width = screen_width = requested_width;
            wanted_height = screen_height = requested_height;
        }

        if (scaled_rendering &&
            (render_target.id == 0U || target_width != wanted_width || target_height != wanted_height)) {
            if (render_target.id != 0U) unload_color_render_target(render_target);
            render_target = load_color_render_target(wanted_width, wanted_height);
            if (render_target.id == 0U || render_target.texture.id == 0U) {
                fprintf(stderr, "warning: render-scale framebuffer unavailable; using native resolution\n");
                if (capture_mode || benchmark_mode) {
                    fprintf(stderr, "fatal: capture framebuffer unavailable\n");
                    exit_status = 1;
                    terminate_requested = 1;
                    break;
                }
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

        if (shader_watch >= 0 && shader_file_changed(shader_watch, shader_name) && reload_state == 0) {
            reload_state = 1;
            reload_start = real_time;
            fprintf(stderr, "shader change detected; validating candidate\n");
        }

        float reload_fade = 1.0f;
        if (reload_state == 1) {
            float progress = clamp01((real_time - reload_start) / RELOAD_FADE_SECONDS);
            reload_fade = 1.0f - smoothstep01(progress);
            if (progress >= 1.0f) {
                (void)replace_shader(&active_shader, shader_path);
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
        if (!capture_mode) shader_time += dt * speed;

        bool should_use_low_power =
            speed <= 0.0001f && reload_state == 0 &&
            !fade_out_requested && (real_time - start_time) >= fade_seconds;
        if (should_use_low_power != low_power) {
            low_power = should_use_low_power;
            SetTargetFPS(low_power && target_fps > 5 ? 5 : target_fps);
        }

        float current_time = real_time;
        if (fade_out_requested && fade_out_start < 0.0f) fade_out_start = current_time;
        float fade;
        if (fade_out_start >= 0.0f) {
            fade = 1.0f - smoothstep01((current_time - fade_out_start) / fade_seconds);
            if (fade <= 0.001f) break;
        } else {
            fade = smoothstep01((current_time - start_time) / fade_seconds);
        }
        fade *= reload_fade;
        if (capture_mode) fade = 1.0f;

        set_shader_vec2(active_shader.shader, active_shader.resolution_location, resolution);
        set_shader_float(active_shader.shader, active_shader.time_location, shader_time);
        set_shader_float(active_shader.shader, active_shader.speed_location, speed);
        set_shader_float(active_shader.shader, active_shader.fade_location, fade);
        set_shader_float(active_shader.shader, active_shader.fade_target_location, fade_target);
        set_shader_texture(active_shader.shader, active_shader.glyph_atlas_location, glyph_atlas);

        if (benchmark_mode) (void)clock_gettime(CLOCK_MONOTONIC, &frame_start);
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
            BeginDrawing();
            BeginShaderMode(active_shader.shader);
            DrawRectangle(0, 0, screen_width, screen_height, WHITE);
            EndShaderMode();
            EndDrawing();
        }

        if (capture_mode) {
            Image screenshot = LoadImageFromTexture(render_target.texture);
            bool saved = screenshot.data != NULL;
            if (saved) {
                ImageFlipVertical(&screenshot);
                saved = ExportImage(screenshot, capture_path);
            }
            if (screenshot.data != NULL) UnloadImage(screenshot);
            if (!saved) {
                fprintf(stderr, "capture failed: %s\n", capture_path);
                exit_status = 1;
                terminate_requested = 1;
            }
            break;
        }
        if (benchmark_mode) {
            (void)clock_gettime(CLOCK_MONOTONIC, &frame_end);
            double frame_ms = ((double)(frame_end.tv_sec - frame_start.tv_sec) * 1000.0) +
                ((double)(frame_end.tv_nsec - frame_start.tv_nsec) / 1000000.0);
            if (benchmark_warmup < 30UL) {
                benchmark_warmup++;
            } else {
                if (!benchmark_started) { benchmark_start = frame_end; benchmark_started = true; }
                benchmark_sum += frame_ms;
                if (frame_ms < benchmark_min) benchmark_min = frame_ms;
                if (frame_ms > benchmark_max) benchmark_max = frame_ms;
                if (benchmark_frames >= benchmark_sample_capacity) {
                    size_t new_capacity = benchmark_sample_capacity ? benchmark_sample_capacity * 2U : 256U;
                    double *new_samples = realloc(benchmark_samples, new_capacity * sizeof(*new_samples));
                    if (!new_samples) {
                        fprintf(stderr, "fatal: benchmark sample allocation failed\n");
                        terminate_requested = 1;
                        break;
                    }
                    benchmark_samples = new_samples;
                    benchmark_sample_capacity = new_capacity;
                }
                benchmark_samples[benchmark_frames] = frame_ms;
                benchmark_frames++;
                double elapsed = (double)(frame_end.tv_sec - benchmark_start.tv_sec) +
                    (double)(frame_end.tv_nsec - benchmark_start.tv_nsec) / 1000000000.0;
                benchmark_elapsed = elapsed;
                if (elapsed >= (double)benchmark_seconds) break;
            }
        }
    }

    if (benchmark_mode) {
        double average = benchmark_frames ? benchmark_sum / (double)benchmark_frames : 0.0;
        double median = 0.0, p95 = 0.0;
        double elapsed = benchmark_elapsed;
        double fps = average > 0.0 ? 1000.0 / average : 0.0;
        if (benchmark_frames) {
            qsort(benchmark_samples, benchmark_frames, sizeof(*benchmark_samples), compare_doubles);
            median = benchmark_samples[benchmark_frames / 2U];
            size_t p95_index = (size_t)ceil((double)benchmark_frames * 0.95) - 1U;
            if (p95_index >= benchmark_frames) p95_index = benchmark_frames - 1U;
            p95 = benchmark_samples[p95_index];
        }
        if (json_output) {
            printf("{\"shader\":\"%s\",\"backend\":\"raylib-opengl\",\"timing_source\":\"cpu_frame_wall_clock\",\"resolution\":\"%dx%d\",\"width\":%d,\"height\":%d,\"frames\":%lu,\"elapsed_seconds\":%.3f,\"average_frame_ms\":%.3f,\"median_frame_ms\":%.3f,\"p95_frame_ms\":%.3f,\"min_frame_ms\":%.3f,\"max_frame_ms\":%.3f,\"approx_fps\":%.2f}\n", json_shader_name, width, height, width, height, benchmark_frames, elapsed, average, median, p95, benchmark_min == DBL_MAX ? 0.0 : benchmark_min, benchmark_max, fps);
        } else {
            printf("shader=%s backend=raylib-opengl timing_source=cpu_frame_wall_clock resolution=%dx%d frames=%lu elapsed_seconds=%.3f average_frame_ms=%.3f median_frame_ms=%.3f p95_frame_ms=%.3f min_frame_ms=%.3f max_frame_ms=%.3f approx_fps=%.2f\n", shader_name, width, height, benchmark_frames, elapsed, average, median, p95, benchmark_min == DBL_MAX ? 0.0 : benchmark_min, benchmark_max, fps);
        }
    }
    free(benchmark_samples);

    if (shader_watch >= 0) close(shader_watch);
    if (render_target.id != 0U) unload_color_render_target(render_target);
    UnloadShader(active_shader.shader);
    if (glyph_atlas.id != 0U) UnloadTexture(glyph_atlas);
    CloseWindow();
    if (d) XCloseDisplay(d);
    return exit_status;
}
