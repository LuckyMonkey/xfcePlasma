#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform vec2 resolution;
uniform float time;
uniform float fade;
uniform sampler2D glyphAtlas;

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

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * resolution) / max(resolution.y, 1.0);
    vec3 col = vec3(0.002, 0.001, 0.008);
    float atlasBackground = texture(glyphAtlas, vec2(0.01, 0.01)).r;
    float atlasValid = 1.0 - smoothstep(0.08, 0.20, atlasBackground);

    for (int i = 0; i < 6; i++) {
        float x = (float(i) - 2.5) * 0.30;
        vec2 localTop = (uv - vec2(x, 0.18)) / 1.45;
        vec2 localBottom = (uv - vec2(x,-0.18)) / 1.45;
        col += fallbackGlyph(localTop, i) * vec3(1.0,0.08,0.60) * 3.5;
        col += mix(fallbackGlyph(localBottom, i), atlasGlyph(localBottom, i), atlasValid)
            * vec3(0.35,0.15,1.0) * 3.5;
    }

    float divider = exp(-abs(uv.y) * 250.0);
    col += divider * vec3(0.20,0.02,0.32);
    col += 0.02 * vec3(0.5 + 0.5*sin(time*0.7 + uv.x*9.0), 0.0, 0.2);
    finalColor = vec4(clamp(col * clamp(fade,0.0,1.0), 0.0, 1.0), 1.0);
}
