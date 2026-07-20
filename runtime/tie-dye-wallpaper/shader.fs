#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform vec2 resolution;
uniform float time;

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
    float t=time*.065;
    float n=fbm(uv*1.35+vec2(t,-t*.7));
    vec2 w=uv+.22*vec2(sin(uv.y*2.3+t+n*2.),cos(uv.x*2.1-t+n*2.));
    float p=sin(w.x*4.7+t*1.7)+sin(w.y*5.3-t*1.3)+sin((w.x+w.y)*3.8+t)+sin(length(w)*7.2-t*1.5);
    float hue=fract(.54+.12*p+.28*n+t*.28);
    vec3 ink=hsv(hue,.82,1.);
    float density=.48+.18*sin(p*.65+n*2.);
    vec3 col=1.-density*(1.-ink);
    finalColor=vec4(clamp(col,0.,1.),1.);
}
