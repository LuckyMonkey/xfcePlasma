#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform vec2 resolution;
uniform float time;
uniform float fade;
uniform float fadeTarget;

float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453123);}
vec3 hsv(float h,float s,float v){vec3 p=abs(fract(h+vec3(0.,2./3.,1./3.))*6.-3.);return v*mix(vec3(1),clamp(p-1.,0.,1.),s);}
float edge(vec2 p, vec2 a, vec2 b){vec2 e=b-a;return e.x*(p.y-a.y)-e.y*(p.x-a.x);}
float poly4(vec2 p, vec2 a, vec2 b, vec2 c, vec2 d){
    float e0=edge(p,a,b), e1=edge(p,b,c), e2=edge(p,c,d), e3=edge(p,d,a);
    float inside=min(min(e0,e1),min(e2,e3));
    return smoothstep(-0.004,0.004,inside);
}
float lineDist(vec2 p, vec2 a, vec2 b){vec2 pa=p-a,ba=b-a;float h=clamp(dot(pa,ba)/dot(ba,ba),0.0,1.0);return length(pa-ba*h);}
vec2 iso(vec2 g){return vec2((g.x-g.y)*0.070,(g.x+g.y)*0.035)-vec2(0.0,0.70);}

bool roadTile(vec2 g){
    float avenue=abs(g.x-g.y-2.0);
    float street=abs(g.x+g.y-13.0);
    float path=abs(g.x-9.0+floor(g.y/4.0));
    return avenue<1.0 || street<1.0 || path<1.0 || abs(g.y-4.0)<0.5;
}

void drawTile(vec2 p, vec2 g, inout vec3 col){
    vec2 c=iso(g);
    vec2 a=c+vec2(0.0,0.035), b=c+vec2(0.070,0.0), cc=c+vec2(0.0,-0.035), d=c+vec2(-0.070,0.0);
    float tile=poly4(p,a,b,cc,d);
    if(tile<=0.0) return;
    bool road=roadTile(g);
    vec3 tcol=road?vec3(0.070,0.073,0.078):vec3(0.105,0.145,0.120);
    tcol+=vec3(hash(g))*0.018;
    float stripe=road?smoothstep(0.004,0.001,lineDist(p,a,cc))*0.45:0.0;
    tcol+=stripe*vec3(0.85,0.72,0.38);
    float curb=(1.0-smoothstep(0.000,0.004,min(min(lineDist(p,a,b),lineDist(p,b,cc)),min(lineDist(p,cc,d),lineDist(p,d,a)))))*0.18;
    tcol+=curb*vec3(0.16,0.17,0.16);
    col=mix(col,tcol,tile);
}

void drawBuilding(vec2 p, vec2 g, inout vec3 col){
    if(roadTile(g) || hash(g)<0.30) return;
    vec2 c=iso(g);
    float h=0.050+0.165*pow(hash(g+4.7),1.3);
    float inset=0.016+0.010*hash(g+9.0);
    vec2 topA=c+vec2(0.0,0.035-inset+h);
    vec2 topB=c+vec2(0.070-inset,0.0+h);
    vec2 topC=c+vec2(0.0,-0.035+inset+h);
    vec2 topD=c+vec2(-0.070+inset,0.0+h);
    vec2 botB=c+vec2(0.070-inset,0.0);
    vec2 botC=c+vec2(0.0,-0.035+inset);
    vec2 botD=c+vec2(-0.070+inset,0.0);

    float left=poly4(p,topD,topC,botC,botD);
    float right=poly4(p,topC,topB,botB,botC);
    float top=poly4(p,topA,topB,topC,topD);

    vec3 base=hsv(0.57+0.08*hash(g+2.0),0.25,0.45+0.16*hash(g+5.0));
    vec3 leftCol=base*vec3(0.58,0.68,0.82);
    vec3 rightCol=base*vec3(0.42,0.49,0.65);
    vec3 topCol=base+vec3(0.20,0.18,0.12);

    float rows=floor((p.y-c.y)/0.018);
    float cols=floor((p.x-c.x)/0.014);
    float win=step(0.78,hash(vec2(cols,rows)+g*6.0+floor(time*0.15)))*(left+right)*0.35;

    col=mix(col,leftCol,left);
    col=mix(col,rightCol,right);
    col=mix(col,topCol,top);
    col+=win*vec3(1.0,0.75,0.30);

    float outline=(1.0-smoothstep(0.000,0.003,min(min(lineDist(p,topA,topB),lineDist(p,topB,topC)),min(lineDist(p,topC,topD),lineDist(p,topD,topA)))))*0.25;
    col=mix(col,vec3(0.015),outline*(top+left+right));
}

void main(){
    vec2 p=(gl_FragCoord.xy-0.5*resolution)/resolution.y;
    vec3 sky=mix(vec3(0.10,0.13,0.18),vec3(0.22,0.31,0.42),smoothstep(-0.55,0.55,p.y));
    vec3 col=sky;

    for(int s=0;s<56;s++){
        int sum=s;
        for(int x=0;x<28;x++){
            int y=sum-x;
            if(y<0 || y>27) continue;
            vec2 g=vec2(float(x),float(y));
            vec2 c=iso(g);
            if(c.x<-1.2 || c.x>1.2 || c.y<-0.72 || c.y>0.42) continue;
            drawTile(p,g,col);
            drawBuilding(p,g,col);
        }
    }

    float haze=smoothstep(0.18,0.50,p.y);
    col=mix(col,sky,haze*0.35);
    col*=0.78+0.25*smoothstep(1.35,0.25,length(p));
    float f=clamp(fade,0.,1.);
    col=mix(vec3(fadeTarget),col,f);
    finalColor=vec4(clamp(col,0.,1.),1.);
}
