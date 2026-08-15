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

float trace(vec2 p, vec2 a, vec2 b, float order, float beat) {
    float d = lineDistance(p, a, b);
    float scan = fract(beat * 11.0);
    float head = 0.22 + 0.78 * smoothstep(0.34, 0.0, abs(scan - order));
    return head * (exp(-d * 275.0) + 0.16 * exp(-d * 42.0));
}

float tracedCat(vec2 p, float beat) {
    float bounce = sin(beat * 2.0 * PI);
    float sway = 0.018 * sin(beat * 2.0 * PI + 1.2);
    p.x += sway;
    p.y -= 0.014 * bounce;

    float c = 0.0;
    // Head and ears.
    c += trace(p, vec2(-0.09, 0.10), vec2(-0.12, 0.22), 0.00, beat);
    c += trace(p, vec2(-0.12, 0.22), vec2(-0.04, 0.17), 0.07, beat);
    c += trace(p, vec2(-0.09, 0.10), vec2(-0.07, 0.01), 0.14, beat);
    c += trace(p, vec2(-0.07, 0.01), vec2( 0.07, 0.01), 0.21, beat);
    c += trace(p, vec2( 0.07, 0.01), vec2( 0.09, 0.10), 0.28, beat);
    c += trace(p, vec2( 0.09, 0.10), vec2( 0.12, 0.22), 0.35, beat);
    c += trace(p, vec2( 0.12, 0.22), vec2( 0.04, 0.17), 0.42, beat);

    // Bow.
    c += trace(p, vec2(-0.07, 0.14), vec2(-0.18, 0.19), 0.49, beat);
    c += trace(p, vec2(-0.18, 0.19), vec2(-0.22, 0.12), 0.56, beat);
    c += trace(p, vec2(-0.22, 0.12), vec2(-0.16, 0.08), 0.63, beat);
    c += trace(p, vec2(-0.16, 0.08), vec2(-0.07, 0.14), 0.70, beat);

    // Face and whiskers.
    c += trace(p, vec2(-0.035, 0.10), vec2(-0.035, 0.08), 0.77, beat);
    c += trace(p, vec2( 0.035, 0.10), vec2( 0.035, 0.08), 0.81, beat);
    c += trace(p, vec2(-0.012, 0.06), vec2( 0.012, 0.06), 0.85, beat);
    c += trace(p, vec2(-0.025, 0.055), vec2(-0.13, 0.04), 0.89, beat);
    c += trace(p, vec2( 0.025, 0.055), vec2( 0.13, 0.04), 0.93, beat);

    // Dress, arms, legs, tail.
    c += trace(p, vec2(-0.07,  0.00), vec2(-0.12, -0.14), 0.08, beat);
    c += trace(p, vec2(-0.12, -0.14), vec2( 0.12, -0.14), 0.16, beat);
    c += trace(p, vec2( 0.12, -0.14), vec2( 0.07,  0.00), 0.24, beat);
    c += trace(p, vec2(-0.07, -0.01), vec2(-0.19, 0.07 + 0.04 * bounce), 0.32, beat);
    c += trace(p, vec2( 0.07, -0.01), vec2( 0.19, 0.07 + 0.04 * bounce), 0.40, beat);
    c += trace(p, vec2(-0.035, -0.14), vec2(-0.07, -0.23 + 0.03 * bounce), 0.48, beat);
    c += trace(p, vec2( 0.035, -0.14), vec2( 0.07, -0.23 - 0.03 * bounce), 0.56, beat);
    c += trace(p, vec2( 0.10, -0.09), vec2( 0.20, -0.13 + 0.03 * bounce), 0.64, beat);
    c += trace(p, vec2( 0.20, -0.13 + 0.03 * bounce), vec2(0.24, -0.07), 0.72, beat);
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

    // Deep club-space backdrop with a subtle center-stage glow.
    vec3 col = vec3(0.0015, 0.0008, 0.007);
    float centerGlow = exp(-dot(uv * vec2(0.78, 1.15), uv * vec2(0.78, 1.15)) * 2.7);
    col += centerGlow * vec3(0.050, 0.006, 0.090);

    float horizonY = -0.055;
    float horizon = exp(-abs(uv.y - horizonY) * 34.0);
    col += horizon * vec3(0.20, 0.006, 0.26);
    col += exp(-abs(uv.y - horizonY) * 120.0) * vec3(0.46, 0.02, 0.45);

    // Faint vertical atmospheric bands keep the empty upper area alive.
    float haze = 0.5 + 0.5 * sin(uv.x * 19.0 + sin(uv.y * 7.0 + t) * 1.3);
    col += vec3(0.012, 0.002, 0.028) * haze * smoothstep(-0.08, 0.75, uv.y);

    // Crossing laser canopy: alternating cyan/magenta beams with a moving origin.
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

    // A scanning hot line over the back wall.
    float scanY = 0.30 + 0.22 * sin(t * 2.15);
    float scanCore = exp(-abs(uv.y - scanY) * 250.0);
    float scanHalo = exp(-abs(uv.y - scanY) * 30.0);
    col += vec3(1.0, 0.02, 0.48) * (scanCore + 0.08 * scanHalo);

    // Sparse drifting glyph wall. Each glyph gets a dim violet shadow and hot face.
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

    // Perspective dance floor. Dark near-black tiles with animated neon seams.
    if (uv.y < horizonY) {
        float depth = max(0.018, horizonY - uv.y);
        float perspective = 0.26 / depth;
        vec2 floorUV = vec2(uv.x * perspective, perspective + t * 0.72);
        vec2 cell = floor(floorUV);
        vec2 local = abs(fract(floorUV) - 0.5);
        float checker = mod(cell.x + cell.y, 2.0);
        vec3 tileA = vec3(0.006, 0.002, 0.016);
        vec3 tileB = vec3(0.040, 0.003, 0.050);
        vec3 floorColor = mix(tileA, tileB, checker);
        float seam = exp(-min(0.5 - local.x, 0.5 - local.y) * 46.0);
        float depthFade = smoothstep(0.0, 0.42, depth);
        vec3 seamColor = mix(vec3(0.72, 0.015, 0.48), vec3(0.06, 0.36, 0.90), 0.5 + 0.5 * sin(cell.y * 0.7 + t));
        floorColor += seam * seamColor * (0.30 + 0.40 * depthFade);
        col = mix(col, floorColor, 0.92);

        // Horizon reflection ties the floor to the laser wall.
        col += exp(-abs(uv.x) * 2.4) * exp(-depth * 7.5) * vec3(0.16, 0.006, 0.19);
    }

    // Dancing cat procession with depth-separated halo and white-hot laser core.
    float span = aspect * 0.92;
    float scroll = mod(t * 0.135, 1.0) * span;
    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        float base = -aspect * 0.46 + fi * aspect * 0.184;
        float x = mod(base - scroll + span * 0.5, span) - span * 0.5;
        vec2 catUV = (uv - vec2(x, -0.005)) / 0.40;
        float cat = tracedCat(catUV, beat + fi * 0.018);
        float catPulse = 0.88 + 0.12 * sin(t * 7.4 + fi);
        col += cat * vec3(0.30, 0.008, 0.42) * 1.25;
        col += cat * vec3(1.00, 0.055, 0.58) * 0.92 * catPulse;
        col += cat * cat * vec3(1.00, 0.58, 0.86) * 0.52;
    }

    // Gentle CRT/club texture and vignette, deliberately restrained.
    float scanTexture = 0.985 + 0.015 * sin(gl_FragCoord.y * PI);
    col *= scanTexture;
    float vignette = 1.0 - smoothstep(0.55, 1.18, length(uv / vec2(max(aspect, 1.0), 1.0)));
    col *= 0.76 + 0.24 * vignette;

    // Small rhythmic exposure lift instead of hard flashing.
    col *= 0.94 + 0.06 * smoothstep(0.72, 1.0, sin(t * 2.0 * PI) * 0.5 + 0.5);

    float f = clamp(fade, 0.0, 1.0);
    col = mix(vec3(fadeTarget), col, f);
    finalColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
