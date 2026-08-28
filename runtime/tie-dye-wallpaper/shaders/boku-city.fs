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
float fbm(vec2 p){float v=0.,a=.5;for(int i=0;i<4;i++){v+=a*noise(p);p=p*2.05+13.7;a*=.5;}return v;}
float boxMask(vec2 p,vec2 halfSize,float aa){vec2 d=abs(p)-halfSize;return 1.0-smoothstep(-aa,aa,max(d.x,d.y));}

vec2 buildingLayer(vec2 p,float baseline,float spacing,float maxHeight,float scroll,float seed){
    float x=p.x+time*scroll;
    float id=floor(x/spacing);
    float localX=mod(x,spacing)-0.5*spacing;
    float rnd=hash(id+seed);
    float width=spacing*(0.32+0.13*hash(id+seed+7.0));
    float height=maxHeight*(0.36+0.64*rnd);
    float centerY=baseline+0.5*height;
    float aa=1.4/resolution.y;
    float body=boxMask(vec2(localX,p.y-centerY),vec2(width,height*0.5),aa);
    float crown=0.0;
    if(hash(id+seed+2.0)>0.70){
        crown=boxMask(vec2(localX,p.y-(baseline+height+0.035)),vec2(width*0.46,0.035),aa);
    }
    if(hash(id+seed+9.0)>0.83){
        crown=max(crown,boxMask(vec2(localX,p.y-(baseline+height+0.075)),vec2(0.006,0.075),aa));
    }
    float windowX=step(0.70,fract((localX/spacing+0.5)*9.0));
    float windowY=step(0.62,fract((p.y-baseline)*38.0));
    float lit=step(0.52,hash(vec2(id,floor((p.y-baseline)*28.0))+seed))*windowX*windowY*body;
    return vec2(max(body,crown),lit);
}

float bridge(vec2 p){
    float deck=boxMask(p-vec2(0.0,-0.36),vec2(1.6,0.018),1.5/resolution.y);
    float arch=abs(length(vec2(p.x*0.72,(p.y+0.49)*1.45))-0.39);
    float arches=(1.0-smoothstep(0.018,0.026,arch))*step(abs(p.x),0.58);
    float towers=max(boxMask(p-vec2(-0.62,-0.28),vec2(0.026,0.17),1.5/resolution.y),boxMask(p-vec2(0.62,-0.28),vec2(0.026,0.17),1.5/resolution.y));
    return max(deck,max(arches,towers));
}

void main(){
    vec2 p=(gl_FragCoord.xy-0.5*resolution)/resolution.y;
    float y=p.y+0.5;
    vec3 col=mix(vec3(0.38,0.035,0.12),vec3(0.035,0.008,0.055),smoothstep(0.0,1.0,y));

    vec2 moonCenter=vec2(0.42,0.25);
    float moon=1.0-smoothstep(0.105,0.116,length(p-moonCenter));
    float moonCut=1.0-smoothstep(0.090,0.103,length(p-(moonCenter+vec2(0.045,0.025))));
    moon*=1.0-moonCut;
    col=mix(col,vec3(1.00,0.48,0.18),moon*0.82);

    vec2 starCell=floor((p+vec2(2.0,0.7))*vec2(48.0,31.0));
    vec2 starPoint=(fract((p+vec2(2.0,0.7))*vec2(48.0,31.0))-0.5);
    float star=(1.0-smoothstep(0.035,0.075,length(starPoint)))*step(0.92,hash(starCell));
    col+=star*vec3(1.00,0.48,0.62)*(0.55+0.45*sin(time+hash(starCell)*6.2831));

    float farRidge=-0.13+0.22*fbm(vec2((p.x+time*0.0015)*0.75,4.0));
    float farMask=smoothstep(0.008,-0.008,p.y-farRidge);
    col=mix(col,vec3(0.16,0.025,0.08),farMask);
    float nearRidge=-0.24+0.18*fbm(vec2((p.x+time*0.003)*1.25,12.0));
    float nearMask=smoothstep(0.008,-0.008,p.y-nearRidge);
    col=mix(col,vec3(0.075,0.012,0.04),nearMask);

    vec2 farCity=buildingLayer(p,-0.36,0.082,0.30,0.007,11.0);
    col=mix(col,vec3(0.27,0.035,0.12),farCity.x);
    col+=farCity.y*vec3(1.00,0.36,0.20)*0.38;
    vec2 midCity=buildingLayer(p,-0.46,0.115,0.43,0.014,37.0);
    col=mix(col,vec3(0.13,0.018,0.08),midCity.x);
    col+=midCity.y*vec3(1.00,0.52,0.18)*0.58;
    vec2 nearCity=buildingLayer(p,-0.56,0.165,0.58,0.024,83.0);
    col=mix(col,vec3(0.035,0.006,0.025),nearCity.x);
    col+=nearCity.y*vec3(1.00,0.34,0.12)*0.72;

    float bridgeMask=bridge(p);
    col=mix(col,vec3(0.040,0.006,0.025),bridgeMask);
    float water=step(p.y,-0.375);
    float reflection=(0.5+0.5*sin(p.x*42.0+time*0.22))*exp(-8.0*abs(p.y+0.44));
    col=mix(col,col*0.40+vec3(0.080,0.008,0.035),water*0.76);
    col+=water*reflection*vec3(0.34,0.030,0.080);

    float haze=exp(-28.0*abs(p.y+0.24))*0.18;
    col=mix(col,vec3(0.58,0.12,0.10),haze);
    col*=0.72+0.32*smoothstep(1.5,0.25,length(p));
    float f=clamp(fade,0.,1.);
    col=mix(vec3(fadeTarget),col,f);
    finalColor=vec4(clamp(col,0.,1.),1.);
}
