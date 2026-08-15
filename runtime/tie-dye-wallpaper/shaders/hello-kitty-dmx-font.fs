#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform vec2 resolution;
uniform float time;
uniform float fade;
uniform float fadeTarget;
uniform sampler2D glyphAtlas;

const float PI = 3.14159265359;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(91.7, 171.3))) * 43758.5453);
}

float lineDistance(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    return length(pa - ba * clamp(dot(pa, ba) / max(dot(ba, ba), 0.00001), 0.0, 1.0));
}

float neonLine(vec2 p, vec2 a, vec2 b, float core, float halo) {
    float d = lineDistance(p, a, b);
    return exp(-d * core) + 0.22 * exp(-d * halo);
}

float ellipseRing(vec2 p, vec2 center, vec2 radius, float width) {
    vec2 q = (p - center) / radius;
    float d = abs(length(q) - 1.0);
    return exp(-d * width);
}

float circleGlow(vec2 p, vec2 center, float radius, float sharpness) {
    return exp(-abs(length(p - center) - radius) * sharpness);
}

float trace(vec2 p, vec2 a, vec2 b, float order, float beat) {
    float d = lineDistance(p, a, b);
    float scan = fract(beat * 11.0);
    float head = 0.28 + 0.72 * smoothstep(0.34, 0.0, abs(scan - order));
    return head * (exp(-d * 300.0) + 0.15 * exp(-d * 46.0));
}

float helloKitty(vec2 p, float beat) {
    float bounce = sin(beat * 2.0 * PI);
    float sway = sin(beat * 2.0 * PI + 1.2);
    p.x += 0.012 * sway;
    p.y -= 0.010 * bounce;

    float c = 0.0;

    // Head: deliberately wider and rounder so it reads as Hello Kitty first,
    // not a generic triangular cat. Ears are short and sit on the oval.
    c += ellipseRing(p, vec2(0.0, 0.105), vec2(0.145, 0.112), 110.0);
    c += trace(p, vec2(-0.112, 0.160), vec2(-0.090, 0.245), 0.02, beat);
    c += trace(p, vec2(-0.090, 0.245), vec2(-0.035, 0.202), 0.07, beat);
    c += trace(p, vec2( 0.112, 0.160), vec2( 0.090, 0.245), 0.12, beat);
    c += trace(p, vec2( 0.090, 0.245), vec2( 0.035, 0.202), 0.17, beat);

    // Bow: two rounded loops with a bright knot, anchored on the left ear.
    c += ellipseRing(p, vec2(-0.135, 0.176), vec2(0.050, 0.034), 95.0);
    c += ellipseRing(p, vec2(-0.064, 0.174), vec2(0.042, 0.030), 100.0);
    c += circleGlow(p, vec2(-0.101, 0.174), 0.016, 120.0);

    // Face: small vertical eyes, low nose, long whiskers.
    c += trace(p, vec2(-0.050, 0.115), vec2(-0.050, 0.087), 0.24, beat);
    c += trace(p, vec2( 0.050, 0.115), vec2( 0.050, 0.087), 0.28, beat);
    c += trace(p, vec2(-0.012, 0.068), vec2( 0.012, 0.068), 0.32, beat);
    c += trace(p, vec2(-0.046, 0.086), vec2(-0.155, 0.108), 0.36, beat);
    c += trace(p, vec2(-0.048, 0.068), vec2(-0.160, 0.064), 0.40, beat);
    c += trace(p, vec2(-0.044, 0.050), vec2(-0.150, 0.025), 0.44, beat);
    c += trace(p, vec2( 0.046, 0.086), vec2( 0.155, 0.108), 0.48, beat);
    c += trace(p, vec2( 0.048, 0.068), vec2( 0.160, 0.064), 0.52, beat);
    c += trace(p, vec2( 0.044, 0.050), vec2( 0.150, 0.025), 0.56, beat);

    // Simple dress/body with a narrower waist and wider hem.
    c += trace(p, vec2(-0.058, 0.005), vec2(-0.080,-0.060), 0.60, beat);
    c += trace(p, vec2(-0.080,-0.060), vec2(-0.125,-0.165), 0.64, beat);
    c += trace(p, vec2(-0.125,-0.165), vec2( 0.125,-0.165), 0.68, beat);
    c += trace(p, vec2( 0.125,-0.165), vec2( 0.080,-0.060), 0.72, beat);
    c += trace(p, vec2( 0.080,-0.060), vec2( 0.058, 0.005), 0.76, beat);

    // Arms and dancing legs. Keep them short enough that the head stays dominant.
    c += trace(p, vec2(-0.068,-0.035), vec2(-0.175, 0.025 + 0.030 * bounce), 0.80, beat);
    c += trace(p, vec2( 0.068,-0.035), vec2( 0.175, 0.025 - 0.025 * bounce), 0.84, beat);
    c += trace(p, vec2(-0.042,-0.165), vec2(-0.074,-0.235 + 0.020 * bounce), 0.88, beat);
    c += trace(p, vec2( 0.042,-0.165), vec2( 0.084,-0.225 - 0.020 * bounce), 0.92, beat);

    // Tiny side tail, visually subordinate to the bow/face.
    c += trace(p, vec2(0.108,-0.125), vec2(0.178,-0.145), 0.95, beat);
    c += trace(p, vec2(0.178,-0.145), vec2(0.202,-0.098), 0.98, beat);
    return c;
}

int glyphRow(int kind, int row) {
    if (kind == 0) { int rows[7] = int[7](14,17,23,21,23,16,15); return rows[row]; }
    if (kind == 1) { int rows[7] = int[7](10,31,10,10,31,10,10); return rows[row]; }
    if (kind == 2) { int rows[7] = int[7](14,20,30,5,15,5,30); return rows[row]; }
    if (kind == 3) { int rows[7] = int[7](12,18,20,8,21,18,13); return rows[row]; }
    if (kind == 4) { int rows[7] = int[7](4,21,14,31,14,21,4); return rows[row]; }
    int rows[7] = int[7](4,4,4,31,4,4,4); return rows[row];
}

float fallbackGlyph(vec2 p, int kind) {
    vec2 guv = p / vec2(0.24) + 0.5;
    if (guv.x < 0.0 || guv.x >= 1.0 || guv.y < 0.0 || guv.y >= 1.0) return 0.0;
    vec2 grid = vec2(guv.x * 5.0, (1.0 - guv.y) * 7.0);
    int col = clamp(int(floor(grid.x)), 0, 4);
    int row = clamp(int(floor(grid.y)), 0, 6);
    float enabled = float((glyphRow(kind, row) >> (4 - col)) & 1);
    vec2 cell = fract(grid) - 0.5;
    float pixel = 1.0 - smoothstep(0.30, 0.48, max(abs(cell.x), abs(cell.y)));
    return enabled * pixel;
}

float atlasGlyph(vec2 p, int kind) {
    float px = float(kind) * 80.0 + 8.0 + (p.x + 0.12) / 0.24 * 48.0;
    float py = 4.0 + (0.12 - p.y) / 0.24 * 48.0;
    float sampleValue = texture(glyphAtlas, vec2(px / 512.0, py / 64.0)).r;
    float bounds = step(abs(p.x), 0.18) * step(abs(p.y), 0.18);
    return bounds * smoothstep(0.05, 0.25, sampleValue);
}

float glyph(vec2 p, int kind) {
    float builtIn = fallbackGlyph(p, kind);
    float atlasBackground = texture(glyphAtlas, vec2(0.01, 0.01)).r;
    float atlasValid = 1.0 - smoothstep(0.08, 0.20, atlasBackground);
    return mix(builtIn, max(builtIn * 0.16, atlasGlyph(p, kind)), atlasValid);
}

vec3 palette(float phase) {
    vec3 magenta = vec3(1.00, 0.015, 0.44);
    vec3 cyan = vec3(0.05, 0.72, 1.00);
    vec3 violet = vec3(0.48, 0.06, 1.00);
    float a = 0.5 + 0.5 * sin(phase);
    float b = 0.5 + 0.5 * sin(phase + 2.1);
    return mix(mix(magenta, cyan, a), violet, 0.25 * b);
}

void main() {
    float safeHeight = max(resolution.y, 1.0);
    vec2 uv = (gl_FragCoord.xy - 0.5 * resolution) / safeHeight;
    float aspect = resolution.x / safeHeight;
    float t = time * 0.18;
    float beat = fract(t * 0.52);

    vec3 col = vec3(0.0015, 0.0008, 0.007);
    float centerGlow = exp(-dot(uv * vec2(0.78, 1.15), uv * vec2(0.78, 1.15)) * 2.7);
    col += centerGlow * vec3(0.050, 0.006, 0.090);

    float horizonY = -0.055;
    float horizon = exp(-abs(uv.y - horizonY) * 34.0);
    col += horizon * vec3(0.20, 0.006, 0.26);
    col += exp(-abs(uv.y - horizonY) * 120.0) * vec3(0.46, 0.02, 0.45);

    float haze = 0.5 + 0.5 * sin(uv.x * 19.0 + sin(uv.y * 7.0 + t) * 1.3);
    col += vec3(0.012, 0.002, 0.028) * haze * smoothstep(-0.08, 0.75, uv.y);

    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        float phase = t * (1.75 + 0.07 * fi) + fi * 0.83;
        vec2 origin = vec2(-aspect * 0.46 + fi * aspect * 0.184, horizonY + 0.015);
        vec2 target = vec2(0.36 * sin(phase * 0.73 + fi), 0.67 + 0.09 * sin(phase + fi));
        float beam = neonLine(uv, origin, target, 220.0, 31.0);
        vec3 beamColor = mod(fi, 2.0) < 1.0 ? vec3(1.0, 0.006, 0.40) : vec3(0.025, 0.58, 1.0);
        float shutter = 0.62 + 0.38 * sin(t * 6.4 + fi * 1.7);
        col += beamColor * beam * shutter * 0.78;
    }

    float scanY = 0.30 + 0.22 * sin(t * 2.15);
    float scanCore = exp(-abs(uv.y - scanY) * 250.0);
    float scanHalo = exp(-abs(uv.y - scanY) * 30.0);
    col += vec3(1.0, 0.02, 0.48) * (scanCore + 0.08 * scanHalo);

    for (int i = 0; i < 11; i++) {
        float fi = float(i);
        float lane = fract(fi * 0.417);
        vec2 gp = vec2(
            mod(-1.20 + fi * 0.43 - t * (0.105 + 0.018 * mod(fi, 3.0)), 2.40) - 1.20,
            0.34 + lane * 0.30
        );
        int kind = clamp(int(floor(hash(vec2(fi, 7.0)) * 6.0)), 0, 5);
        vec2 local = (uv - gp) / 0.62;
        float g = glyph(local, kind);
        float pulse = 0.78 + 0.22 * sin(t * 4.0 + fi * 1.3);
        col += g * vec3(0.22, 0.025, 0.55) * 1.4;
        col += g * palette(fi * 1.7 + t) * 2.25 * pulse;
    }

    // Bring back the original alternating checkerboard identity, but retain
    // the improved perspective/depth. The whole floor inverts on a slow beat.
    if (uv.y < horizonY) {
        float depth = max(0.018, horizonY - uv.y);
        float perspective = 0.26 / depth;
        vec2 floorUV = vec2(uv.x * perspective, perspective + t * 0.72);
        vec2 cell = floor(floorUV);
        vec2 local = abs(fract(floorUV) - 0.5);

        float checker = mod(cell.x + cell.y, 2.0);
        float inversion = step(0.0, sin(t * 3.5));
        float alternating = abs(checker - inversion);

        vec3 tileDark = vec3(0.004, 0.001, 0.012);
        vec3 tileHot  = vec3(0.22, 0.003, 0.105);
        vec3 floorColor = mix(tileDark, tileHot, alternating);

        float seam = exp(-min(0.5 - local.x, 0.5 - local.y) * 50.0);
        float depthFade = smoothstep(0.0, 0.40, depth);
        vec3 seamColor = mix(vec3(0.95, 0.015, 0.48), vec3(0.08, 0.34, 0.95), 0.5 + 0.5 * sin(cell.y * 0.72 + t));
        floorColor += seam * seamColor * (0.24 + 0.38 * depthFade);

        // Slightly preserve the alternating blocks toward the horizon instead
        // of washing them out into uniform grid lines.
        float floorMix = 0.94 - 0.12 * smoothstep(0.0, 0.25, depth);
        col = mix(col, floorColor, floorMix);
        col += exp(-abs(uv.x) * 2.4) * exp(-depth * 7.5) * vec3(0.15, 0.005, 0.18);
    }

    // Fewer, larger cats are much easier to read than six small wire figures.
    float span = aspect * 0.96;
    float scroll = mod(t * 0.125, 1.0) * span;
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float base = -aspect * 0.48 + fi * aspect * 0.24;
        float x = mod(base - scroll + span * 0.5, span) - span * 0.5;
        vec2 catUV = (uv - vec2(x, 0.005)) / 0.47;
        float cat = helloKitty(catUV, beat + fi * 0.021);

        // Violet bloom under a pink shell and almost-white center stroke.
        float halo = min(cat, 2.0);
        col += halo * vec3(0.24, 0.008, 0.50) * 0.56;
        col += cat * vec3(1.00, 0.018, 0.55) * 0.72;
        col += smoothstep(0.72, 1.75, cat) * vec3(1.0, 0.42, 0.88) * 0.36;
    }

    float vignette = smoothstep(1.15, 0.28, length(uv * vec2(0.72, 0.96)));
    col *= 0.72 + 0.28 * vignette;
    col *= 0.96 + 0.04 * sin(t * 3.2);

    float f = clamp(fade, 0.0, 1.0);
    col = mix(vec3(fadeTarget), col, f);
    finalColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
