#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform vec2 resolution;
uniform float time;
uniform float fade;
uniform float fadeTarget;
uniform sampler2D glyphAtlas;

float hash(vec2 p){return fract(sin(dot(p,vec2(91.7,171.3)))*43758.5453);}
float trace(vec2 p,vec2 a,vec2 b,float order,float beat){
    vec2 pa=p-a,ba=b-a;float h=clamp(dot(pa,ba)/dot(ba,ba),0.,1.);float d=length(pa-ba*h);
    float scan=fract(beat*12.);float on=.24+.76*smoothstep(.38,0.,abs(scan-order));
    return on*(exp(-d*250.)+.12*exp(-d*34.));
}
float tracedCat(vec2 p,float beat){
    float b=sin(beat*6.2831);p.y-=.014*b;float c=0.;
    // head and ears
    c+=trace(p,vec2(-.09,.10),vec2(-.12,.22),.00,beat);c+=trace(p,vec2(-.12,.22),vec2(-.04,.17),.08,beat);
    c+=trace(p,vec2(-.09,.10),vec2(-.07,.01),.16,beat);c+=trace(p,vec2(-.07,.01),vec2(.07,.01),.24,beat);
    c+=trace(p,vec2(.07,.01),vec2(.09,.10),.32,beat);c+=trace(p,vec2(.09,.10),vec2(.12,.22),.40,beat);
    c+=trace(p,vec2(.12,.22),vec2(.04,.17),.48,beat);
    // bow on left ear
    c+=trace(p,vec2(-.07,.14),vec2(-.18,.19),.56,beat);c+=trace(p,vec2(-.18,.19),vec2(-.22,.12),.64,beat);
    c+=trace(p,vec2(-.22,.12),vec2(-.16,.08),.72,beat);c+=trace(p,vec2(-.16,.08),vec2(-.07,.14),.80,beat);
    // face and whiskers
    c+=trace(p,vec2(-.035,.10),vec2(-.035,.08),.88,beat);c+=trace(p,vec2(.035,.10),vec2(.035,.08),.90,beat);
    c+=trace(p,vec2(-.012,.06),vec2(.012,.06),.92,beat);c+=trace(p,vec2(-.025,.055),vec2(-.13,.04),.94,beat);
    c+=trace(p,vec2(.025,.055),vec2(.13,.04),.96,beat);
    // dress body, raised arms, legs, curling tail
    c+=trace(p,vec2(-.07,.00),vec2(-.12,-.14),.10,beat);c+=trace(p,vec2(-.12,-.14),vec2(.12,-.14),.18,beat);
    c+=trace(p,vec2(.12,-.14),vec2(.07,.00),.26,beat);c+=trace(p,vec2(-.07,-.01),vec2(-.19,.07+.04*b),.34,beat);
    c+=trace(p,vec2(.07,-.01),vec2(.19,.07+.04*b),.42,beat);c+=trace(p,vec2(-.035,-.14),vec2(-.07,-.23+.03*b),.50,beat);
    c+=trace(p,vec2(.035,-.14),vec2(.07,-.23-.03*b),.58,beat);c+=trace(p,vec2(.10,-.09),vec2(.20,-.13+.03*b),.66,beat);
    c+=trace(p,vec2(.20,-.13+.03*b),vec2(.24,-.07),.74,beat);
    return c;
}
float glyph(vec2 p,float kind){float index=floor(kind+.5);float px=index*80.+8.+(p.x+.12)/.24*48.;float py=4.+(.12-p.y)/.24*48.;float sample=texture(glyphAtlas,vec2(px/512.,py/64.)).r;return step(abs(p.x),.18)*step(abs(p.y),.18)*smoothstep(.05,.25,sample);}

void main(){
    vec2 uv=(gl_FragCoord.xy-.5*resolution)/resolution.y;float t=time*.18;float beat=fract(t*.5);vec3 col=vec3(.002,.001,.008);
    col+=vec3(.01,.001,.022)*(.5+.5*sin(uv.y*90.));
    for(int i=0;i<5;i++){float fi=float(i);float phase=t*2.2+fi*.55;vec2 a=vec2(-.72+fi*.36,.02+.025*sin(phase));vec2 b=vec2(.22*sin(phase*.71+fi),.72+.10*sin(phase+fi));vec2 pa=uv-a,ba=b-a;float h=clamp(dot(pa,ba)/dot(ba,ba),0.,1.);float d=length(pa-ba*h);float beam=exp(-d*170.)+.18*exp(-d*22.);col+=(mod(fi,2.)<1.?vec3(1.,.01,.34):vec3(.35,.01,1.))*beam*(.4+.6*sin(t*7.+fi));}
    float scanY=.30+.24*sin(t*2.7);col+=vec3(1.,.01,.42)*(exp(-abs(uv.y-scanY)*260.)+.1*exp(-abs(uv.y-scanY)*28.));
    // sparse laser wall glyphs
    for(int i=0;i<10;i++){float fi=float(i);vec2 gp=vec2(mod(-1.1+fi*.43-t*(.12+.02*mod(fi,3.)),2.2)-1.1,.38+fract(fi*.417)*.28);vec2 local=(uv-gp)/.95;float g=floor(hash(vec2(fi,7.))*4.);col+=glyph(local,g)*vec3(1.,.01,.45)*3.0;}
    // alternating inverse checkerboard, fixed black/pink values
    if(uv.y<-.08){float d=max(.018,-.08-uv.y);vec2 fp=vec2(uv.x/d*.25,1./d*.3+t*1.6);vec2 fc=floor(fp);float ck=mod(fc.x+fc.y,2.);float inverse=abs(ck-step(0.,sin(t*3.5)));col=mix(col,mix(vec3(.018,.001,.03),vec3(.35,.002,.17),inverse),.97);}
    float aspect=resolution.x/resolution.y;float span=aspect*.84;float scroll=mod(t*.14,1.)*span;
    for(int i=0;i<6;i++){float fi=float(i);float base=-aspect*.42+fi*aspect*.168;float x=mod(base-scroll+span*.5,span)-span*.5;float qcat=tracedCat((uv-vec2(x,-.02))/.42,beat);col+=qcat*vec3(1.,.005,.48)*(.8+.2*sin(t*8.));}
    float f=clamp(fade,0.,1.);col=mix(vec3(fadeTarget),col,f);finalColor=vec4(clamp(col,0.,1.),1.);
}
