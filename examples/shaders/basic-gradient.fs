#version 330

in vec2 fragTexCoord;

uniform float time;
uniform vec2 resolution;
uniform float speed;
uniform float fade;

out vec4 finalColor;

void main(void)
{
    float aspect = resolution.x/max(resolution.y, 1.0);
    vec2 uv = fragTexCoord;
    uv.x = (uv.x - 0.5)*aspect + 0.5;

    float glow = 0.08*sin(time*0.5);
    vec3 night = vec3(0.03, 0.06, 0.14);
    vec3 dawn = vec3(0.20, 0.46, 0.68);
    vec3 color = mix(night, dawn, clamp(uv.y + glow, 0.0, 1.0));
    color += 0.035*cos(6.28318*uv.x + time*0.2);

    finalColor = vec4(color*fade, 1.0);
}
