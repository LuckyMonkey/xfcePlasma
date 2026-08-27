#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform vec2 resolution;
uniform float time;
uniform float fade;
uniform float fadeTarget;

float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){float v=0.,a=.5;for(int i=0;i<5;i++){v+=a*noise(p);p=p*2.02+13.7;a*=.5;}return v;}
float circle(vec2 p,float r){return 1.-smoothstep(r,r+.012,length(p));}
float roundedBox(vec2 p,vec2 b,float r){vec2 q=abs(p)-b+r;return 1.-smoothstep(0.,.012,length(max(q,0.))+min(max(q.x,q.y),0.)-r);}
float drip(vec2 p,float x,float top,float bottom,float w){float shaft=roundedBox(p-vec2(x,(top+bottom)*.5),vec2(w,(top-bottom)*.5),w*.7);float bead=circle(p-vec2(x,bottom),w*1.15);return max(shaft,bead);}
float cone(vec2 p){float y=p.y;float half=clamp((y+.02)*.42,.0,.22);return step(-.01,y)*step(y,.72)*step(abs(p.x),half);}

void main(){
    vec2 uv=gl_FragCoord.xy/resolution;
    vec2 p=(gl_FragCoord.xy-.5*resolution)/resolution.y;
    float t=time*.035;
    vec3 col=vec3(.027,.025,.029);
    float concrete=fbm(uv*3.4+vec2(t*.12,-t*.04));
    float stains=fbm(uv*8.0-vec2(t*.16,t*.07));
    col+=concrete*vec3(.095,.062,.055)+stains*vec3(.045,.022,.035);
    col+=smoothstep(.72,.9,fbm(uv*2.0+4.))*vec3(.055,.012,.035);

    float seam=abs(fract((p.x+.12*p.y)*3.2)-.5);
    float crack=1.-smoothstep(.0,.018,abs(noise(uv*25.+t)-.5)-.37);
    col+=smoothstep(.48,.5,crack)*vec3(.12,.025,.035);
    col-=smoothstep(.0,.012,seam)*vec3(.025,.019,.018);

    float scan=.5+.5*sin((uv.y*resolution.y+t*18.)*.75);
    col*=.965+.035*scan;

    vec3 scoopA=vec3(.96,.12,.37), scoopB=vec3(1.,.48,.12), scoopC=vec3(.33,.92,.53);
    float glow=0.;
    for(int i=0;i<3;i++){
        float fi=float(i);
        float x=-.48+fi*.48;
        float wobble=.025*sin(t*2.0+fi*2.7);
        float scale=1.-.08*fi;
        vec2 q=(p-vec2(x+wobble,.05))/scale;
        float scoop=circle(q-vec2(0.,.29),.245);
        float scoop2=circle(q-vec2(-.15,.22),.17);
        float scoop3=circle(q-vec2(.15,.21),.16);
        float mask=max(scoop,max(scoop2,scoop3));
        float coneMask=cone(q-vec2(0.,-.42));
        vec3 ink=i==0?scoopA:(i==1?scoopB:scoopC);
        col=mix(col,ink,mask*.9);
        col=mix(col,vec3(.52,.16,.07),coneMask*.92);
        float waffle=step(.58,fract((q.x+q.y)*15.));
        col=mix(col,vec3(.82,.3,.09),coneMask*waffle*.18);
        float d1=drip(q,-.13,.2,-.08,.035),d2=drip(q,.08,.17,-.02,.025);
        col=mix(col,ink,max(d1,d2)*.88);
        glow+=mask*.18+d1*.12+d2*.12;
    }
    float cream=0.;
    cream+=circle(p-vec2(.0,.39),.06)+circle(p-vec2(.48,.29),.045);
    col=mix(col,vec3(1.,.82,.68),cream*.8);

    float reflection=exp(-abs(p.y+.45+.06*sin(p.x*4.-t))*42.)*(.5+.5*noise(uv*12.+t));
    col+=reflection*vec3(.55,.06,.18);
    float sodium=exp(-abs(p.y+.7+.12*sin(p.x*2.+t*.6))*26.);
    col+=sodium*vec3(.35,.12,.025);

    for(int i=0;i<18;i++){
        float fi=float(i);vec2 cell=floor(uv*vec2(90.,52.)+fi);
        float speck=step(.94,hash(cell+fi*7.1))*(.25+.75*noise(cell*.15));
        col+=speck*vec3(.18,.07,.08);
    }
    float vignette=smoothstep(1.35,.3,length(p*vec2(.72,.94)));
    col*=.67+.33*vignette;
    col+=glow*vec3(.12,.025,.06);
    float f=clamp(fade,0.,1.);
    finalColor=vec4(mix(vec3(fadeTarget),clamp(col,0.,1.),f),1.);
}
