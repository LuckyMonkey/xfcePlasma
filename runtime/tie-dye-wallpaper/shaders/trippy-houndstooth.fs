#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform vec2 resolution;
uniform float time;
uniform float fade;
uniform float fadeTarget;

float hash(float n){return fract(sin(n)*43758.5453123);}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453123);}
vec3 hsv(float h,float s,float v){vec3 p=abs(fract(h+vec3(0.,2./3.,1./3.))*6.-3.);return v*mix(vec3(1),clamp(p-1.,0.,1.),s);}
float sdBox(vec2 p, vec2 b){vec2 d=abs(p)-b;return length(max(d,0.0))+min(max(d.x,d.y),0.0);}
float fillBox(vec2 p, vec2 c, vec2 b){return 1.0-smoothstep(-0.015,0.018,sdBox(p-c,b));}
float tri(vec2 p, vec2 a, vec2 b, vec2 c){
    float e0=(b.x-a.x)*(p.y-a.y)-(b.y-a.y)*(p.x-a.x);
    float e1=(c.x-b.x)*(p.y-b.y)-(c.y-b.y)*(p.x-b.x);
    float e2=(a.x-c.x)*(p.y-c.y)-(a.y-c.y)*(p.x-c.x);
    float inside=min(min(e0,e1),e2);
    float outside=max(max(e0,e1),e2);
    float signedDist = abs(inside) < abs(outside) ? inside : -outside;
    return smoothstep(-0.018,0.018,signedDist);
}
float houndShape(vec2 q,float morph){
    q=fract(q)-0.5;
    float bite=0.07+0.07*morph;
    float bar=0.15+0.05*sin(morph*6.2831);
    float s=0.0;
    s=max(s,fillBox(q,vec2(-0.22,0.22),vec2(0.28,bar)));
    s=max(s,fillBox(q,vec2(0.22,-0.22),vec2(0.28,bar)));
    s=max(s,tri(q,vec2(-0.50,0.50),vec2(0.10+bite,0.50),vec2(-0.50,-0.10-bite)));
    s=max(s,tri(q,vec2(0.50,-0.50),vec2(-0.10-bite,-0.50),vec2(0.50,0.10+bite)));
    s=max(s,tri(q,vec2(-0.50,-0.04),vec2(-0.04,-0.50),vec2(-0.50,-0.50)));
    s=max(s,tri(q,vec2(0.50,0.04),vec2(0.04,0.50),vec2(0.50,0.50)));
    return clamp(s,0.0,1.0);
}
float randomActive(vec2 id, float tick){
    float target=floor(hash(vec2(floor(tick),71.3))*108.0);
    float idx=id.y*18.0+id.x;
    return 1.0-step(0.5,abs(idx-target));
}

void main(){
    vec2 uv=gl_FragCoord.xy/resolution.xy;
    vec2 centered=(gl_FragCoord.xy-0.5*resolution)/resolution.y;
    vec2 gridCount=vec2(18.0,6.0);
    vec2 p=vec2(uv.x*gridCount.x,(1.0-uv.y)*gridCount.y);
    vec2 id=floor(p);
    vec2 q=fract(p);
    float parity=mod(id.x+id.y,2.0);

    float tick=time*0.38;
    float phase=fract(tick);
    float active=randomActive(id,tick);
    float envelope=smoothstep(0.0,0.22,phase)*smoothstep(1.0,0.55,phase);
    float localFlow=smoothstep(-0.15,1.05,q.x+q.y+sin(time*0.7+id.x)*0.12-1.0+phase*1.6);
    float morph=active*envelope*localFlow;

    float baseMorph=0.35+0.20*sin(time*0.08+hash(id)*6.2831);
    float shape=houndShape(q,baseMorph+morph*0.65);
    shape=mix(shape,1.0-shape,parity);

    vec3 black=vec3(0.014,0.012,0.010);
    vec3 cream=vec3(0.96,0.93,0.82);
    vec3 col=mix(black,cream,shape);

    float hueSweep=fract(0.52+0.18*hash(id)+0.08*sin(time*0.045)+morph*0.35+localFlow*active*0.18);
    vec3 shifted=mix(hsv(hueSweep,0.58,0.78),hsv(hueSweep+0.48,0.50,0.92),shape);
    col=mix(col,shifted,morph*0.62);

    float neighborGlow=0.0;
    for(int y=-1;y<=1;y++){
        for(int x=-1;x<=1;x++){
            vec2 nid=id+vec2(x,y);
            if(nid.x>=0.0 && nid.x<gridCount.x && nid.y>=0.0 && nid.y<gridCount.y){
                neighborGlow=max(neighborGlow,randomActive(nid,tick)*envelope*(0.16/(1.0+length(vec2(x,y)))));
            }
        }
    }
    col=mix(col,hsv(hueSweep+0.18,0.45,0.86),neighborGlow);

    float cloth=0.015*sin(centered.x*130.0)+0.010*sin((centered.x+centered.y)*93.0);
    col+=cloth;
    col*=0.72+0.34*smoothstep(1.55,0.25,length(centered));

    float f=clamp(fade,0.,1.);
    col=mix(vec3(fadeTarget),col,f);
    finalColor=vec4(clamp(col,0.,1.),1.);
}
