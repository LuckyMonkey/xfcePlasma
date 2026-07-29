#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform vec2 resolution;
uniform float time;
uniform float fade;
uniform float fadeTarget;

float hash(float n){return fract(sin(n)*43758.5453123);}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453123);}
float noise(vec2 p){
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y);
}
float fbm(vec2 p){float v=0.0,a=0.5;for(int i=0;i<5;i++){v+=a*noise(p);p=p*2.03+17.1;a*=0.5;}return v;}

float triangle(vec2 q,float width,float height,float aa){
    float halfWidth=width*max(0.0,1.0-q.y/height);
    float d=max(abs(q.x)-halfWidth,max(-q.y,q.y-height));
    return 1.0-smoothstep(-aa,aa,d);
}

float treeShape(vec2 q,float size,float seed,float aa){
    float trunk=(1.0-smoothstep(-aa,aa,max(abs(q.x)-size*0.055,max(-q.y,q.y-size*0.62))))*0.9;
    float crown=0.0;
    crown=max(crown,triangle(q-vec2(0.0,size*0.10),size*0.38,size*0.62,aa));
    crown=max(crown,triangle(q-vec2(0.0,size*0.34),size*0.31,size*0.54,aa));
    crown=max(crown,triangle(q-vec2(0.0,size*0.57),size*0.22,size*0.42,aa));
    float wind=0.012*sin(time*0.32+seed*6.2831)*smoothstep(0.25,0.95,q.y/max(size,0.001));
    crown=max(crown,triangle(q-vec2(wind,size*0.72),size*0.12,size*0.25,aa));
    return max(trunk,crown);
}

float forestLayer(vec2 p,float baseline,float spacing,float size,float scroll,float seed){
    float x=p.x+time*scroll;
    float id=floor(x/spacing);
    float localX=mod(x,spacing)-0.5*spacing;
    float random=hash(id+seed);
    vec2 q=vec2(localX,p.y-baseline);
    float aa=1.4/resolution.y;
    return treeShape(q,size*(0.78+0.38*random),random+seed,aa);
}

float mountainHeight(float x,float scale,float seed,float drift){
    float broad=fbm(vec2((x+time*drift)*scale,seed));
    float sharp=abs(noise(vec2((x+time*drift)*scale*2.7,seed+4.1))-0.5);
    return broad*0.31+sharp*0.12;
}

void main(){
    vec2 p=(gl_FragCoord.xy-0.5*resolution)/resolution.y;
    float y=p.y+0.5;

    vec3 skyLow=vec3(0.19,0.012,0.025);
    vec3 skyHigh=vec3(0.035,0.008,0.020);
    vec3 col=mix(skyLow,skyHigh,smoothstep(0.05,1.0,y));
    float redGlow=exp(-7.0*abs(y-0.52))*0.30;
    col+=redGlow*vec3(0.34,0.035,0.045);

    float moon=1.0-smoothstep(0.115,0.125,length(p-vec2(0.29,0.25)));
    float moonHaze=exp(-18.0*length(p-vec2(0.29,0.25)));
    col=mix(col,vec3(0.69,0.20,0.18),moon*0.55);
    col+=moonHaze*vec3(0.23,0.035,0.045);

    float farMountain=smoothstep(0.008,-0.008,p.y-(-0.03+mountainHeight(p.x,0.65,2.0,0.0015)));
    col=mix(col,vec3(0.105,0.020,0.037),farMountain);
    float midMountain=smoothstep(0.008,-0.008,p.y-(-0.18+mountainHeight(p.x,1.10,8.0,0.0030)));
    col=mix(col,vec3(0.052,0.014,0.027),midMountain);

    float distant=forestLayer(p,-0.22,0.115,0.24,0.004,13.0);
    col=mix(col,vec3(0.075,0.018,0.027),distant*0.86);
    float middle=forestLayer(p,-0.34,0.155,0.36,0.009,31.0);
    col=mix(col,vec3(0.025,0.010,0.017),middle*0.94);
    float nearTrees=forestLayer(p,-0.53,0.235,0.58,0.017,73.0);
    col=mix(col,vec3(0.006,0.005,0.009),nearTrees);

    float fogNoise=fbm(vec2(p.x*1.7-time*0.018,p.y*3.1+11.0));
    float fogBand=exp(-34.0*abs(p.y+0.14+0.035*sin(p.x*2.4-time*0.07)));
    float fogBand2=exp(-42.0*abs(p.y+0.31+0.025*sin(p.x*3.2+time*0.05)));
    vec3 fogColor=vec3(0.31,0.075,0.080);
    col=mix(col,fogColor,(fogBand*0.22+fogBand2*0.16)*(0.45+0.55*fogNoise));

    float vignette=smoothstep(1.25,0.22,length(p*vec2(0.78,1.0)));
    col*=0.66+0.42*vignette;
    float f=clamp(fade,0.,1.);
    col=mix(vec3(fadeTarget),col,f);
    finalColor=vec4(clamp(col,0.,1.),1.);
}
