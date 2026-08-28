#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform vec2 resolution;
uniform float time;
uniform float fade;
uniform float fadeTarget;

float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){float v=0.,a=.5;for(int i=0;i<4;i++){v+=a*noise(p);p=p*2.03+11.7;a*=.5;}return v;}
float circle(vec2 p,float r){return 1.-smoothstep(r,r+.004,length(p));}
float box(vec2 p,vec2 b,float r){vec2 q=abs(p)-b+r;return 1.-smoothstep(0.,.004,length(max(q,0.))+min(max(q.x,q.y),0.)-r);}
float line(vec2 p,vec2 a,vec2 b,float w){vec2 pa=p-a,ba=b-a;float h=clamp(dot(pa,ba)/max(dot(ba,ba),.0001),0.,1.);return 1.-smoothstep(w,w+.004,length(pa-ba*h));}
float cone(vec2 q){float y=q.y;float half=clamp((y+.02)*.43,0.,.25);return smoothstep(-.012,.0,y)*smoothstep(.74,.70,y)*smoothstep(half+.006,half,abs(q.x));}
float scoop(vec2 q,float phase,float speed){
    q.x+=.065*sin(time*speed+phase);
    q.y+=.035*sin(time*speed*.73+phase*1.6);
    float m=circle(q-vec2(0.,.25),.255);
    m=max(m,circle(q-vec2(-.16,.18),.17));
    m=max(m,circle(q-vec2(.16,.18),.175));
    m=max(m,circle(q-vec2(0.,.11),.19));
    return m;
}
float hourglassDrip(vec2 p,float x,float top,float length,float width){
    float u=clamp((top-p.y)/max(length,.001),0.,1.);
    float neck=.30+.95*abs(2.*u-1.);
    float localWidth=width*neck;
    float inside=smoothstep(localWidth+.012,localWidth,abs(p.x-x));
    float vertical=smoothstep(top+.01,top,p.y)*smoothstep(top-length-.025,top-length,p.y);
    float pearl=circle(p-vec2(x,top-length),width*1.65);
    float satellite=circle(p-vec2(x+width*1.4,top-length*.72),width*.55);
    return max(inside*vertical, max(pearl,satellite*.7));
}

void main(){
    vec2 uv=gl_FragCoord.xy/resolution;
    vec2 p=(gl_FragCoord.xy-.5*resolution)/resolution.y;
    float t=time*.72;
    vec3 col=vec3(.018,.021,.021);

    float concrete=fbm(uv*3.0+vec2(t*.018,-t*.012));
    float stains=fbm(uv*8.0-vec2(t*.06,t*.025));
    col+=concrete*vec3(.14,.13,.115)+stains*vec3(.06,.026,.05);
    col=mix(col,vec3(.055,.07,.063),smoothstep(.68,.9,fbm(uv*1.8+3.)));

    float slab=box(p-vec2(0.,.06),vec2(.91,.59),.028);
    col=mix(col,vec3(.065,.075,.069)+concrete*.10,slab);
    float border=box(p-vec2(0.,.06),vec2(.91,.59),.028)-box(p-vec2(0.,.06),vec2(.875,.545),.018);
    col=mix(col,vec3(.006,.008,.007),border*.98);
    float redbar=box(p-vec2(0.,-.46),vec2(.87,.032),.006);
    col=mix(col,vec3(.72,.035,.21),redbar*.8);
    float greenbar=box(p-vec2(-.36,.61),vec2(.19,.018),.004);
    col=mix(col,vec3(.46,.95,.08),greenbar);

    for(int i=0;i<5;i++){
        float fi=float(i),x=-.78+fi*.39+.025*sin(t*.45+fi*1.8);
        float y=.48+.065*sin(t*.32+fi*1.6);
        float block=box(p-vec2(x,y),vec2(.11,.022),.004);
        col=mix(col,fi<2.?vec3(.8,.06,.27):vec3(.56,.94,.08),block*.78);
    }

    vec3 slime[3]=vec3[](vec3(.42,1.,.035),vec3(.74,1.,.025),vec3(.08,.86,.42));
    for(int i=0;i<3;i++){
        float fi=float(i),speed=.48+fi*.27,phase=fi*2.2;
        float x=-.45+fi*.45+.035*sin(t*speed+phase);
        float top=.30+.025*sin(t*speed*.8+phase);
        vec2 q=p-vec2(x,.03);
        float outer=scoop(q,phase,speed);
        float inner=scoop(q*1.045,phase,speed);
        vec3 ink=slime[i];
        col=mix(col,vec3(.003,.005,.004),outer*.98);
        col=mix(col,ink,inner*.98);
        float shadow=circle(q-vec2(.08,.18),.095)+circle(q-vec2(-.12,.12),.07);
        col=mix(col,ink*vec3(.48,.42,.55),shadow*.22);

        vec2 coneSpace=q-vec2(0.,.55);
        float coneMask=cone(coneSpace);
        col=mix(col,vec3(.105,.025,.075),coneMask*.92);
        float cross=line(coneSpace,vec2(-.15,.12),vec2(.15,.45),.005)+line(coneSpace,vec2(.15,.12),vec2(-.15,.45),.005);
        col=mix(col,vec3(.5,.08,.2),coneMask*cross*.5);

        float len1=.22+.16*(.5+.5*sin(t*speed+phase));
        float len2=.08+.18*(.5+.5*sin(t*speed*1.35+phase+1.4));
        float len3=.12+.10*(.5+.5*sin(t*speed*.72+phase+2.3));
        float d1=hourglassDrip(q,-.14,top-.02,len1,.022+.008*fi);
        float d2=hourglassDrip(q,.10,top-.08,len2,.017+.005*fi);
        float d3=hourglassDrip(q,.02,top-.12,len3,.012);
        col=mix(col,ink,max(max(d1,d2),d3)*.98);
        float wet= circle(q-vec2(-.10,.36),.04)+circle(q-vec2(.11,.26),.025);
        col+=wet*vec3(1.,1.,.7)*(.55+.35*sin(t*speed*1.7+phase));
        col+=d1*vec3(.12,.28,.03)+d2*vec3(.1,.2,.025)+d3*vec3(.08,.18,.02);
    }

    // Smooth overspray and paint ghosts: irregular, soft-edged rather than pixel noise.
    for(int i=0;i<12;i++){
        float fi=float(i),a=fi*.91;
        vec2 spray=vec2(-.74+fract(sin(fi*18.3)*91.7)*1.48,
            -.42+fract(sin(fi*37.1)*47.2)*.88);
        spray+=.025*vec2(sin(t*.55+a),cos(t*.41+a*1.7));
        float mist=circle(p-spray,.008+.012*fract(fi*.37));
        col+=mist*mix(vec3(.5,.9,.08),vec3(.85,.04,.28),fract(fi*.23))*.45;
    }
    float smear=box(p-vec2(0.,-.53),vec2(.55,.032),.018);
    col=mix(col,vec3(.58,.035,.2),smear*.35);
    float crawl=exp(-abs(p.y-(.39+.07*sin(p.x*3.+t)))*38.)*(.4+.6*noise(uv*11.+t*.2));
    col+=crawl*vec3(.3,.025,.2);
    float cyan=exp(-abs(p.y+.18+.045*sin(p.x*4.-t*1.1))*50.);
    col+=cyan*vec3(.015,.17,.2);
    float scan=.5+.5*sin(uv.y*resolution.y*.75+t*7.);
    col*=.97+.03*scan;
    float vignette=smoothstep(1.45,.3,length(p*vec2(.7,.95)));
    col*=.73+.27*vignette;
    float f=clamp(fade,0.,1.);
    finalColor=vec4(mix(vec3(fadeTarget),clamp(col,0.,1.),f),1.);
}
