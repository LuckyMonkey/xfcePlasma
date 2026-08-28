#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform vec2 resolution;
uniform float time;
uniform float fade;
uniform float fadeTarget;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y);
}
float fbm(vec2 p) {
    float v=0.0, a=.5;
    for(int i=0;i<3;i++){ v+=a*noise(p); p=mat2(1.6,-1.2,1.2,1.6)*p+.13; a*=.5; }
    return v;
}
vec3 hsv(float h,float s,float v) {
    vec3 p=abs(fract(h+vec3(0.,2./3.,1./3.))*6.-3.);
    return v*mix(vec3(1),clamp(p-1.,0.,1.),s);
}
void main() {
    vec2 uv=(gl_FragCoord.xy-.5*resolution)/resolution.y;
    // Broad, screen-filling color fields: slow drift instead of a fine
    // grid of equally sized cells, leaving calm areas for desktop icons.
    float t=time*.055;
    float n=fbm(uv*.72+vec2(t*.18,-t*.11));
    vec2 w=uv+.28*vec2(sin(uv.y*1.45+t+n*1.4),cos(uv.x*1.25-t*.8+n));
    float field=sin(w.x*2.15+t*.75)+sin(w.y*1.7-t*.52);
    field+=.75*sin((w.x*.72-w.y*1.08)*2.1+t*.35+n*2.0);
    float hue=fract(.54+.075*field+.18*n+t*.035);
    vec3 ink=hsv(hue,.78,.96);
    float density=.42+.13*sin(field*.5+n*1.4);
    float f=clamp(fade,0.,1.);
    float fadedDensity=mix(1.,density,f);
    vec3 fadedInk=mix(vec3(fadeTarget),ink,f);
    vec3 col=1.-fadedDensity*(1.-fadedInk);
    finalColor=vec4(clamp(col,0.,1.),1.);
}
