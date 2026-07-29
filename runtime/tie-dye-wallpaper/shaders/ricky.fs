#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform vec2 resolution;
uniform float time;
uniform float fade;
uniform float fadeTarget;

// Geometry derived from Kevin L. Durette's CC BY 4.0 tessellating SVG:
// https://commons.wikimedia.org/wiki/File:Houndstooth_SVG.svg
const vec2 HOUND[11] = vec2[](
    vec2(0.0,0.0), vec2(2.0,0.0), vec2(4.0,2.0),
    vec2(3.0,2.0), vec2(2.0,1.0), vec2(2.0,2.0),
    vec2(1.0,2.0), vec2(2.0,3.0), vec2(2.0,4.0),
    vec2(0.0,2.0), vec2(0.0,0.0)
);

float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453123);}
vec3 hsv(float h,float s,float v){vec3 p=abs(fract(h+vec3(0.,2./3.,1./3.))*6.-3.);return v*mix(vec3(1),clamp(p-1.,0.,1.),s);}

float segmentDistance(vec2 p, vec2 a, vec2 b){
    vec2 pa=p-a, ba=b-a;
    float h=clamp(dot(pa,ba)/max(dot(ba,ba),0.0001),0.0,1.0);
    return length(pa-ba*h);
}

float polygonMask(vec2 p, float aa){
    bool inside=false;
    float edgeDistance=1000.0;
    for(int i=0,j=10;i<11;j=i++){
        vec2 a=HOUND[i], b=HOUND[j];
        edgeDistance=min(edgeDistance,segmentDistance(p,a,b));
        bool crosses=(a.y>p.y)!=(b.y>p.y);
        if(crosses){
            float crossing=a.x+(p.y-a.y)*(b.x-a.x)/(b.y-a.y);
            if(p.x<crossing) inside=!inside;
        }
    }
    float signedDistance=inside?-edgeDistance:edgeDistance;
    return 1.0-smoothstep(-aa,aa,signedDistance);
}

float houndstooth(vec2 tilePoint){
    vec2 p=mod(tilePoint,4.0);
    float aa=max(fwidth(tilePoint.x),fwidth(tilePoint.y))*0.85;
    float shape=0.0;
    for(int y=-1;y<=1;y++){
        for(int x=-1;x<=1;x++){
            shape=max(shape,polygonMask(p+4.0*vec2(x,y),aa));
        }
    }
    return shape;
}

void main(){
    vec2 centered=(gl_FragCoord.xy-0.5*resolution)/resolution.y;
    vec2 tilePoint=vec2(centered.x,-centered.y)*15.0;
    vec2 cell=floor(tilePoint/4.0);
    float tooth=houndstooth(tilePoint);

    vec3 ink=vec3(0.012,0.010,0.014);
    vec3 cloth=vec3(0.95,0.91,0.82);
    vec3 col=mix(cloth,ink,tooth);

    float wave=0.5+0.5*sin(time*0.42+cell.x*0.71-cell.y*0.53);
    float pulse=smoothstep(0.72,1.0,wave)*smoothstep(0.18,0.85,hash(cell));
    vec3 accent=hsv(0.91+0.12*sin(time*0.08+hash(cell)*6.2831),0.62,0.82);
    col=mix(col,mix(accent,accent*0.28,tooth),pulse*0.38);

    float weave=0.018*sin(centered.x*190.0)+0.012*sin((centered.x+centered.y)*126.0);
    col+=weave;
    col*=0.74+0.30*smoothstep(1.65,0.22,length(centered));

    float f=clamp(fade,0.,1.);
    col=mix(vec3(fadeTarget),col,f);
    finalColor=vec4(clamp(col,0.,1.),1.);
}
