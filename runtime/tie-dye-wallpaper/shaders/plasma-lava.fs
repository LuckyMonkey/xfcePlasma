#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform vec2 resolution;
uniform float time;
uniform float fade;
uniform float fadeTarget;

float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y);}
float fbm(vec2 p){float v=0.0,a=.55;for(int i=0;i<5;i++){v+=a*noise(p);p=mat2(1.45,-1.25,1.25,1.45)*p+0.21;a*=.48;}return v;}

void main(){
    vec2 uv=(gl_FragCoord.xy-.5*resolution)/resolution.y;
    float t=time*.045;
    vec2 q=uv;
    q.y+=t*.45;
    q.x+=sin(q.y*2.0+t)*0.25;
    float n=fbm(q*1.7+vec2(0.0,t));
    float veins=sin((uv.y+n*0.9-t)*9.0)+sin((uv.x+n*0.5+t)*5.0);
    float heat=smoothstep(-0.55,1.15,veins+n*1.6-length(uv)*0.45);
    vec3 rock=vec3(0.015,0.012,0.014)+vec3(n*0.08);
    vec3 ember=vec3(1.0,0.23,0.03);
    vec3 gold=vec3(1.0,0.72,0.18);
    vec3 col=mix(rock,mix(ember,gold,smoothstep(0.55,1.0,heat)),heat);
    col+=pow(max(heat,0.0),5.0)*vec3(0.9,0.25,0.04);
    float f=clamp(fade,0.,1.);
    col=mix(vec3(fadeTarget),col,f);
    finalColor=vec4(clamp(col,0.,1.),1.);
}
