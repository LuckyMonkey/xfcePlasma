#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform vec2 resolution;
uniform float time;
uniform float fade;
uniform float fadeTarget;

float hash(float n){return fract(sin(n)*43758.5453123);}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453123);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y);}

void main(){
    vec2 uv=gl_FragCoord.xy/resolution.xy;
    float day=0.5+0.5*sin(time*0.018-1.2);
    float dusk=pow(1.0-abs(day*2.0-1.0),2.0);

    vec3 nightTop=vec3(0.015,0.025,0.07);
    vec3 nightHorizon=vec3(0.035,0.055,0.12);
    vec3 dayTop=vec3(0.22,0.58,0.98);
    vec3 dayHorizon=vec3(0.78,0.90,1.0);
    vec3 duskTop=vec3(0.34,0.16,0.38);
    vec3 duskHorizon=vec3(1.0,0.42,0.20);

    vec3 skyTop=mix(nightTop,dayTop,day);
    vec3 skyHorizon=mix(nightHorizon,dayHorizon,day);
    skyTop=mix(skyTop,duskTop,dusk*0.55);
    skyHorizon=mix(skyHorizon,duskHorizon,dusk*0.70);
    vec3 sky=mix(skyHorizon,skyTop,smoothstep(0.25,1.0,uv.y));

    float star=step(0.997,hash(floor(uv*vec2(260.0,120.0))))*(1.0-day);
    sky+=vec3(star)*(0.45+0.35*sin(time*0.7+hash(uv)*6.28));

    float base=0.245;
    float wave=0.0;
    wave+=0.030*sin(uv.x*10.0+time*0.75);
    wave+=0.018*sin(uv.x*19.0-time*0.48+1.4);
    wave+=0.012*sin(uv.x*37.0+time*0.28+noise(vec2(uv.x*3.0,time*0.06))*4.0);
    wave+=0.010*(noise(vec2(uv.x*14.0,time*0.22))-0.5);
    float waterLine=base+wave;

    vec3 waterBase=vec3(0.0,0.60,1.0); // #0099FF
    vec3 waterDeep=vec3(0.0,0.17,0.42);
    vec3 water=waterBase;
    float depth=smoothstep(waterLine,0.0,uv.y);
    water=mix(waterBase,waterDeep,depth*0.75);
    water+=0.12*sin((uv.x+uv.y)*45.0-time*1.8)*smoothstep(waterLine,0.0,uv.y);
    water+=0.08*noise(vec2(uv.x*42.0+time*0.35,uv.y*18.0-time*0.12));

    float foam=1.0-smoothstep(0.0,0.020,abs(uv.y-waterLine));
    foam+=0.35*(1.0-smoothstep(0.0,0.010,abs(uv.y-(waterLine+0.018*sin(uv.x*52.0-time*1.4)))));
    foam=clamp(foam,0.0,1.0);

    vec3 col=uv.y<waterLine?water:sky;
    col=mix(col,vec3(0.78,0.95,1.0),foam*0.55);

    float f=clamp(fade,0.,1.);
    col=mix(vec3(fadeTarget),col,f);
    finalColor=vec4(clamp(col,0.,1.),1.);
}
