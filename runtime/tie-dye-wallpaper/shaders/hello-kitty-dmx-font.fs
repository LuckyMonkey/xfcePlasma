#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform vec2 resolution;
uniform float time;
uniform float fade;
uniform float fadeTarget;
uniform sampler2D glyphAtlas;
const float glyphDebug = 0.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(91.7, 171.3))) * 43758.5453);
}

float trace(vec2 p, vec2 a, vec2 b, float order, float beat) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    float d = length(pa - ba * h);
    float scan = fract(beat * 12.0);
    float on = 0.24 + 0.76 * smoothstep(0.38, 0.0, abs(scan - order));
    return on * (exp(-d * 250.0) + 0.12 * exp(-d * 34.0));
}

float tracedCat(vec2 p, float beat) {
    float bounce = sin(beat * 6.2831);
    p.y -= 0.014 * bounce;
    float c = 0.0;
    c += trace(p, vec2(-0.09, 0.10), vec2(-0.12, 0.22), 0.00, beat);
    c += trace(p, vec2(-0.12, 0.22), vec2(-0.04, 0.17), 0.08, beat);
    c += trace(p, vec2(-0.09, 0.10), vec2(-0.07, 0.01), 0.16, beat);
    c += trace(p, vec2(-0.07, 0.01), vec2( 0.07, 0.01), 0.24, beat);
    c += trace(p, vec2( 0.07, 0.01), vec2( 0.09, 0.10), 0.32, beat);
    c += trace(p, vec2( 0.09, 0.10), vec2( 0.12, 0.22), 0.40, beat);
    c += trace(p, vec2( 0.12, 0.22), vec2( 0.04, 0.17), 0.48, beat);
    c += trace(p, vec2(-0.07, 0.14), vec2(-0.18, 0.19), 0.56, beat);
    c += trace(p, vec2(-0.18, 0.19), vec2(-0.22, 0.12), 0.64, beat);
    c += trace(p, vec2(-0.22, 0.12), vec2(-0.16, 0.08), 0.72, beat);
    c += trace(p, vec2(-0.16, 0.08), vec2(-0.07, 0.14), 0.80, beat);
    c += trace(p, vec2(-0.035, 0.10), vec2(-0.035, 0.08), 0.88, beat);
    c += trace(p, vec2( 0.035, 0.10), vec2( 0.035, 0.08), 0.90, beat);
    c += trace(p, vec2(-0.012, 0.06), vec2( 0.012, 0.06), 0.92, beat);
    c += trace(p, vec2(-0.025, 0.055), vec2(-0.13, 0.04), 0.94, beat);
    c += trace(p, vec2( 0.025, 0.055), vec2( 0.13, 0.04), 0.96, beat);
    c += trace(p, vec2(-0.07,  0.00), vec2(-0.12, -0.14), 0.10, beat);
    c += trace(p, vec2(-0.12, -0.14), vec2( 0.12, -0.14), 0.18, beat);
    c += trace(p, vec2( 0.12, -0.14), vec2( 0.07,  0.00), 0.26, beat);
    c += trace(p, vec2(-0.07, -0.01), vec2(-0.19, 0.07 + 0.04 * bounce), 0.34, beat);
    c += trace(p, vec2( 0.07, -0.01), vec2( 0.19, 0.07 + 0.04 * bounce), 0.42, beat);
    c += trace(p, vec2(-0.035, -0.14), vec2(-0.07, -0.23 + 0.03 * bounce), 0.50, beat);
    c += trace(p, vec2( 0.035, -0.14), vec2( 0.07, -0.23 - 0.03 * bounce), 0.58, beat);
    c += trace(p, vec2( 0.10, -0.09), vec2( 0.20, -0.13 + 0.03 * bounce), 0.66, beat);
    c += trace(p, vec2( 0.20, -0.13 + 0.03 * bounce), vec2(0.24, -0.07), 0.74, beat);
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
    vec2 uv = p / vec2(0.24) + 0.5;
    if (uv.x < 0.0 || uv.x >= 1.0 || uv.y < 0.0 || uv.y >= 1.0) return 0.0;
    vec2 grid = vec2(uv.x * 5.0, (1.0 - uv.y) * 7.0);
    int col = clamp(int(floor(grid.x)), 0, 4);
    int row = clamp(int(floor(grid.y)), 0, 6);
    float enabled = float((glyphRow(kind, row) >> (4 - col)) & 1);
    vec2 cell = fract(grid) - 0.5;
    float pixel = 1.0 - smoothstep(0.32, 0.48, max(abs(cell.x), abs(cell.y)));
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
    return mix(builtIn, max(builtIn * 0.18, atlasGlyph(p, kind)), atlasValid);
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * resolution) / max(resolution.y, 1.0);
    float t = time * 0.18;
    float beat = fract(t * 0.5);
    vec3 col = vec3(0.002, 0.001, 0.008);

    col += vec3(0.01, 0.001, 0.022) * (0.5 + 0.5 * sin(uv.y * 90.0));
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float phase = t * 2.2 + fi * 0.55;
        vec2 a = vec2(-0.72 + fi * 0.36, 0.02 + 0.025 * sin(phase));
        vec2 b = vec2(0.22 * sin(phase * 0.71 + fi), 0.72 + 0.10 * sin(phase + fi));
        vec2 pa = uv - a, ba = b - a;
        float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
        float d = length(pa - ba * h);
        float beam = exp(-d * 170.0) + 0.18 * exp(-d * 22.0);
        vec3 beamColor = mod(fi, 2.0) < 1.0 ? vec3(1.0,0.01,0.34) : vec3(0.35,0.01,1.0);
        col += beamColor * beam * (0.4 + 0.6 * sin(t * 7.0 + fi));
    }

    float scanY = 0.30 + 0.24 * sin(t * 2.7);
    col += vec3(1.0,0.01,0.42) * (exp(-abs(uv.y-scanY)*260.0) + 0.1*exp(-abs(uv.y-scanY)*28.0));

    if (glyphDebug > 0.5) {
        for (int i = 0; i < 6; i++) {
            float x = (float(i) - 2.5) * 0.30;
            col += glyph((uv - vec2(x, 0.30)) / 1.55, i) * vec3(1.0,0.10,0.65) * 4.0;
        }
    } else {
        for (int i = 0; i < 10; i++) {
            float fi = float(i);
            vec2 gp = vec2(mod(-1.1 + fi*0.43 - t*(0.12 + 0.02*mod(fi,3.0)), 2.2)-1.1,
                           0.38 + fract(fi*0.417)*0.28);
            int kind = clamp(int(floor(hash(vec2(fi,7.0))*6.0)), 0, 5);
            col += glyph((uv-gp)/0.72, kind) * vec3(1.0,0.01,0.45) * 3.4;
        }
    }

    if (uv.y < -0.08) {
        float d = max(0.018, -0.08 - uv.y);
        vec2 fp = vec2(uv.x/d*0.25, 1.0/d*0.3 + t*1.6);
        vec2 fc = floor(fp);
        float checker = mod(fc.x + fc.y, 2.0);
        float inverse = abs(checker - step(0.0, sin(t*3.5)));
        col = mix(col, mix(vec3(0.018,0.001,0.03), vec3(0.35,0.002,0.17), inverse), 0.97);
    }

    float aspect = resolution.x / max(resolution.y, 1.0);
    float span = aspect * 0.84;
    float scroll = mod(t*0.14,1.0)*span;
    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        float base = -aspect*0.42 + fi*aspect*0.168;
        float x = mod(base-scroll+span*0.5,span)-span*0.5;
        col += tracedCat((uv-vec2(x,-0.02))/0.42,beat) * vec3(1.0,0.005,0.48) * (0.8+0.2*sin(t*8.0));
    }

    float f = clamp(fade, 0.0, 1.0);
    col = mix(vec3(fadeTarget), col, f);
    finalColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
