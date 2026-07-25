#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform vec2 resolution;
uniform float time;
uniform float fade;
uniform float fadeTarget;

float hash(vec2 p){return fract(sin(dot(p,vec2(41.0,289.0)))*45758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y);}
float fbm(vec2 p){float v=0.0,a=0.5;for(int i=0;i<4;i++){v+=a*noise(p);p=mat2(1.7,-1.1,1.1,1.7)*p+0.19;a*=0.5;}return v;}
vec3 hsv(float h,float s,float v){vec3 p=abs(fract(h+vec3(0.,2./3.,1./3.))*6.-3.);return v*mix(vec3(1),clamp(p-1.,0.,1.),s);}

void main(){
    vec2 uv=(gl_FragCoord.xy-0.5*resolution)/resolution.y;
    float t=time*0.055;
    float flow=fbm(vec2(uv.x*0.85+t,uv.y*1.8-t*0.4));
    float ribbon=0.0;
    for(int i=0;i<5;i++){
        float fi=float(i);
        float y=sin(uv.x*(1.25+fi*0.22)+t*(1.1+fi*0.08)+flow*2.4+fi)*0.20+sin(t*0.7+fi)*0.08;
        ribbon+=0.040/(abs(uv.y-y)+0.030+fi*0.004);
    }
    ribbon=clamp(ribbon*0.20,0.0,1.0);
    vec3 base=mix(vec3(0.005,0.01,0.018),vec3(0.02,0.05,0.08),smoothstep(-0.45,0.5,uv.y));
    vec3 glow=hsv(0.44+0.22*sin(uv.x*0.5+t)+0.10*flow,0.72,1.0)*ribbon;
    vec3 stars=vec3(step(0.996,hash(floor((uv+vec2(t*0.02,0.0))*resolution.y*0.35))))*0.35;
    vec3 col=base+glow+stars;
    float f=clamp(fade,0.,1.);
    col=mix(vec3(fadeTarget),col,f);
    finalColor=vec4(clamp(col,0.,1.),1.);
}
