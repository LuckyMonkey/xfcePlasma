#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform vec2 resolution;
uniform float time;
uniform float fade;
uniform float fadeTarget;

float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453123);}
float box(vec2 p, vec2 b){vec2 d=abs(p)-b;return 1.0-smoothstep(0.0,0.018,length(max(d,0.0))+min(max(d.x,d.y),0.0));}
float lineMask(vec2 p,float w){return 1.0-smoothstep(w,w+0.01,abs(p.x));}
float life(vec2 c,float tick){
    float center=step(0.50,hash(c+floor(tick)*vec2(17.0,31.0)));
    float n=0.0;
    for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++)if(x!=0||y!=0)n+=step(0.62,hash(c+vec2(x,y)+floor(tick)*vec2(13.0,19.0)));
    float born=1.0-step(0.5,abs(n-3.0));
    float live=center*(1.0-step(0.5,abs(n-2.0)));
    return max(born,live);
}
vec2 rot(vec2 p,float a){float c=cos(a),s=sin(a);return mat2(c,-s,s,c)*p;}
vec3 hsv(float h,float s,float v){vec3 p=abs(fract(h+vec3(0.,2./3.,1./3.))*6.-3.);return v*mix(vec3(1),clamp(p-1.,0.,1.),s);}

void main(){
    vec2 uv=(gl_FragCoord.xy-.5*resolution)/resolution.y;
    float t=time;
    float beat=floor(t*0.225);
    float phase=smoothstep(0.0,1.0,fract(t*0.225));
    vec2 warp=0.05*vec2(sin(uv.y*5.0+t*0.22),cos(uv.x*4.0-t*0.18));
    uv+=warp;

    vec2 face=rot(uv,0.10*sin(t*0.18));
    vec2 iso=vec2(face.x+face.y*0.38,face.y*0.86-face.x*0.10);
    float grid=42.0;
    vec2 g=floor(iso*grid);
    vec2 f=fract(iso*grid)-0.5;

    vec2 drift=vec2(floor(sin(g.y*0.31+beat)*1.5),floor(cos(g.x*0.27-beat)*1.5));
    vec2 shuffled=g+drift*step(0.54,hash(g+beat));
    float h=hash(shuffled+floor(beat*0.18));
    float h2=hash(shuffled*1.7+23.0+floor(beat*0.33));

    float qr=step(0.47,h);
    float maze=(step(0.5,fract((g.x+g.y+beat)*0.5))*lineMask(f,0.055)) + (step(0.5,fract((g.x-g.y+beat)*0.5))*lineMask(f.yx,0.055));
    maze=clamp(maze,0.0,1.0);
    float automata=life(g,t*1.1);
    float block=mix(qr,max(maze,automata),0.45+0.45*sin(t*0.23));

    float pop=mix(0.78,1.18,hash(g+beat*0.8));
    vec2 local=rot(f,(floor(h2*4.0)*1.570796)+phase*0.42*step(0.66,h));
    float tile=box(local,vec2(0.30*pop));
    float inner=box(local,vec2(0.18*pop));
    float mark=max(lineMask(local,0.035),lineMask(local.yx,0.035))*step(0.72,h2);
    float ink=tile*block;
    ink=max(ink,inner*step(0.84,h));
    ink=max(ink,mark*step(0.55,h));

    vec2 q=abs(fract((iso+vec2(0.018*sin(t),0.0))*grid/9.0)-0.5);
    float finder=box(q,vec2(0.43))-box(q,vec2(0.28))+box(q,vec2(0.13));
    float corner=max(step(length(iso-vec2(-0.55,0.26)),0.22),max(step(length(iso-vec2(0.46,0.30)),0.18),step(length(iso-vec2(-0.46,-0.34)),0.18)));
    ink=max(ink,finder*corner);

    float scan=0.5+0.5*sin((iso.x+iso.y)*10.0-t*0.75);
    vec3 paper=mix(vec3(0.015,0.018,0.022),vec3(0.055,0.075,0.085),scan*0.25+length(uv)*0.25);
    vec3 cyan=hsv(0.48+0.07*sin(t*0.08)+0.03*h2,0.72,0.95);
    vec3 mag=hsv(0.82+0.06*sin(t*0.11+h),0.68,0.85);
    vec3 inkCol=mix(cyan,mag,step(0.55,h2));
    vec3 col=mix(paper,inkCol,ink);
    col+=vec3(0.05,0.25,0.22)*automata*smoothstep(0.35,0.0,length(f));
    col+=0.10*vec3(0.8,1.0,0.9)*smoothstep(0.985,1.0,sin((iso.x-iso.y)*24.0+t*1.1));

    float vign=smoothstep(1.25,0.25,length(uv));
    col*=0.62+0.55*vign;
    float ff=clamp(fade,0.,1.);
    col=mix(vec3(fadeTarget),col,ff);
    finalColor=vec4(clamp(col,0.,1.),1.);
}
