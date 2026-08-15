#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform vec2 resolution;
uniform float time;
uniform float fade;
uniform float fadeTarget;
uniform sampler2D glyphAtlas;

const float PI = 3.14159265359;

float hash(vec2 p){return fract(sin(dot(p,vec2(91.7,171.3)))*43758.5453);}
float lineDistance(vec2 p,vec2 a,vec2 b){vec2 pa=p-a,ba=b-a;return length(pa-ba*clamp(dot(pa,ba)/max(dot(ba,ba),1e-5),0.0,1.0));}
float neonLine(vec2 p,vec2 a,vec2 b,float core,float halo){float d=lineDistance(p,a,b);return exp(-d*core)+0.22*exp(-d*halo);}

float laserStroke(vec2 p,vec2 a,vec2 b,float order,float scan){
    vec2 pa=p-a,ba=b-a;float den=max(dot(ba,ba),1e-5);float h=clamp(dot(pa,ba)/den,0.0,1.0);float d=length(pa-ba*h);
    float seg=fract(h*9.0+order*3.1);float gate=smoothstep(0.05,0.13,seg)*(1.0-smoothstep(0.72,0.90,seg));
    float head=exp(-abs(fract(scan-order)-h)*25.0);
    return (exp(-d*330.0)+0.13*exp(-d*50.0))*(0.25+0.75*gate+1.1*head);
}
float segmentedEllipse(vec2 p,vec2 c,vec2 r,float order,float scan){
    vec2 q=(p-c)/r;float rr=length(q);float ring=exp(-abs(rr-1.0)*110.0);float a=atan(q.y,q.x)/(2.0*PI)+0.5;
    float seg=fract(a*13.0+order*3.4);float gate=smoothstep(0.05,0.12,seg)*(1.0-smoothstep(0.72,0.90,seg));
    float head=exp(-abs(fract(scan-order)-a)*23.0);return ring*(0.24+0.76*gate+1.0*head);
}
float segmentedCircle(vec2 p,vec2 c,float r,float order,float scan){return segmentedEllipse(p,c,vec2(r),order,scan);}

float frontKitty(vec2 p,float scan,float bounce){
    p.y-=0.010*bounce;float c=0.0;
    c+=segmentedEllipse(p,vec2(0.0,0.105),vec2(0.145,0.112),0.00,scan);
    c+=laserStroke(p,vec2(-0.112,0.160),vec2(-0.090,0.245),0.05,scan);c+=laserStroke(p,vec2(-0.090,0.245),vec2(-0.035,0.202),0.09,scan);
    c+=laserStroke(p,vec2( 0.112,0.160),vec2( 0.090,0.245),0.13,scan);c+=laserStroke(p,vec2( 0.090,0.245),vec2( 0.035,0.202),0.17,scan);
    c+=segmentedEllipse(p,vec2(-0.137,0.176),vec2(0.050,0.034),0.21,scan);c+=segmentedEllipse(p,vec2(-0.066,0.174),vec2(0.042,0.030),0.25,scan);c+=segmentedCircle(p,vec2(-0.102,0.174),0.016,0.29,scan);
    c+=laserStroke(p,vec2(-0.050,0.115),vec2(-0.050,0.087),0.33,scan);c+=laserStroke(p,vec2(0.050,0.115),vec2(0.050,0.087),0.36,scan);c+=laserStroke(p,vec2(-0.012,0.068),vec2(0.012,0.068),0.39,scan);
    c+=laserStroke(p,vec2(-0.046,0.086),vec2(-0.155,0.108),0.42,scan);c+=laserStroke(p,vec2(-0.048,0.068),vec2(-0.160,0.064),0.45,scan);c+=laserStroke(p,vec2(-0.044,0.050),vec2(-0.150,0.025),0.48,scan);
    c+=laserStroke(p,vec2(0.046,0.086),vec2(0.155,0.108),0.51,scan);c+=laserStroke(p,vec2(0.048,0.068),vec2(0.160,0.064),0.54,scan);c+=laserStroke(p,vec2(0.044,0.050),vec2(0.150,0.025),0.57,scan);
    c+=laserStroke(p,vec2(-0.058,0.005),vec2(-0.080,-0.060),0.61,scan);c+=laserStroke(p,vec2(-0.080,-0.060),vec2(-0.125,-0.165),0.65,scan);c+=laserStroke(p,vec2(-0.125,-0.165),vec2(0.125,-0.165),0.69,scan);c+=laserStroke(p,vec2(0.125,-0.165),vec2(0.080,-0.060),0.73,scan);c+=laserStroke(p,vec2(0.080,-0.060),vec2(0.058,0.005),0.77,scan);
    c+=laserStroke(p,vec2(-0.068,-0.035),vec2(-0.175,0.025+0.030*bounce),0.81,scan);c+=laserStroke(p,vec2(0.068,-0.035),vec2(0.175,0.025-0.025*bounce),0.85,scan);
    c+=laserStroke(p,vec2(-0.042,-0.165),vec2(-0.074,-0.235+0.020*bounce),0.89,scan);c+=laserStroke(p,vec2(0.042,-0.165),vec2(0.084,-0.225-0.020*bounce),0.93,scan);
    c+=laserStroke(p,vec2(0.108,-0.125),vec2(0.178,-0.145),0.96,scan);c+=laserStroke(p,vec2(0.178,-0.145),vec2(0.202,-0.098),0.99,scan);return c;
}
float backKitty(vec2 p,float scan,float bounce){
    p.y-=0.010*bounce;float c=0.0;
    c+=segmentedEllipse(p,vec2(0.0,0.105),vec2(0.145,0.112),0.00,scan);
    c+=laserStroke(p,vec2(-0.112,0.160),vec2(-0.090,0.245),0.08,scan);c+=laserStroke(p,vec2(-0.090,0.245),vec2(-0.035,0.202),0.12,scan);
    c+=laserStroke(p,vec2(0.112,0.160),vec2(0.090,0.245),0.16,scan);c+=laserStroke(p,vec2(0.090,0.245),vec2(0.035,0.202),0.20,scan);
    c+=segmentedEllipse(p,vec2(0.105,0.178),vec2(0.044,0.031),0.24,scan);c+=segmentedCircle(p,vec2(0.070,0.176),0.014,0.28,scan);
    c+=laserStroke(p,vec2(-0.058,0.005),vec2(-0.080,-0.060),0.38,scan);c+=laserStroke(p,vec2(-0.080,-0.060),vec2(-0.120,-0.165),0.44,scan);c+=laserStroke(p,vec2(-0.120,-0.165),vec2(0.120,-0.165),0.50,scan);c+=laserStroke(p,vec2(0.120,-0.165),vec2(0.080,-0.060),0.56,scan);c+=laserStroke(p,vec2(0.080,-0.060),vec2(0.058,0.005),0.62,scan);
    c+=laserStroke(p,vec2(-0.060,-0.050),vec2(0.060,-0.050),0.68,scan);c+=laserStroke(p,vec2(0.0,-0.050),vec2(0.0,-0.155),0.72,scan);
    c+=laserStroke(p,vec2(-0.040,-0.165),vec2(-0.060,-0.230),0.80,scan);c+=laserStroke(p,vec2(0.040,-0.165),vec2(0.060,-0.230),0.84,scan);
    c+=segmentedCircle(p,vec2(0.150,-0.125),0.030,0.90,scan);return c;
}
float profileKitty(vec2 p,float scan,float bounce,float side){
    p.x*=side;p.y-=0.010*bounce;float c=0.0;
    c+=segmentedEllipse(p,vec2(-0.015,0.105),vec2(0.118,0.112),0.00,scan);
    c+=laserStroke(p,vec2(-0.090,0.160),vec2(-0.070,0.245),0.06,scan);c+=laserStroke(p,vec2(-0.070,0.245),vec2(-0.025,0.204),0.10,scan);
    c+=laserStroke(p,vec2(0.070,0.175),vec2(0.095,0.230),0.14,scan);
    c+=segmentedEllipse(p,vec2(-0.105,0.176),vec2(0.038,0.030),0.18,scan);c+=segmentedCircle(p,vec2(-0.073,0.175),0.014,0.22,scan);
    c+=laserStroke(p,vec2(0.035,0.110),vec2(0.035,0.086),0.28,scan);c+=laserStroke(p,vec2(0.055,0.065),vec2(0.083,0.065),0.32,scan);
    c+=laserStroke(p,vec2(0.025,0.082),vec2(0.125,0.100),0.36,scan);c+=laserStroke(p,vec2(0.028,0.062),vec2(0.130,0.058),0.40,scan);c+=laserStroke(p,vec2(0.025,0.042),vec2(0.120,0.020),0.44,scan);
    c+=laserStroke(p,vec2(-0.040,0.005),vec2(-0.065,-0.060),0.50,scan);c+=laserStroke(p,vec2(-0.065,-0.060),vec2(-0.090,-0.165),0.56,scan);c+=laserStroke(p,vec2(-0.090,-0.165),vec2(0.075,-0.165),0.62,scan);c+=laserStroke(p,vec2(0.075,-0.165),vec2(0.060,-0.020),0.68,scan);
    c+=laserStroke(p,vec2(0.055,-0.040),vec2(0.145,0.010+0.025*bounce),0.74,scan);c+=laserStroke(p,vec2(-0.020,-0.165),vec2(-0.040,-0.230),0.82,scan);c+=laserStroke(p,vec2(0.040,-0.165),vec2(0.070,-0.225),0.86,scan);
    c+=laserStroke(p,vec2(-0.075,-0.120),vec2(-0.155,-0.145),0.92,scan);c+=laserStroke(p,vec2(-0.155,-0.145),vec2(-0.185,-0.100),0.96,scan);return c;
}
float kittyFrame(vec2 p,float frame,float scan,float bounce){
    if(frame<0.5)return frontKitty(p,scan,bounce);
    if(frame<1.5)return profileKitty(p,scan,bounce,1.0);
    if(frame<2.5)return backKitty(p,scan,bounce);
    return profileKitty(p,scan,bounce,-1.0);
}

int glyphRow(int kind,int row){if(kind==0){int r[7]=int[7](14,17,23,21,23,16,15);return r[row];}if(kind==1){int r[7]=int[7](10,31,10,10,31,10,10);return r[row];}if(kind==2){int r[7]=int[7](14,20,30,5,15,5,30);return r[row];}if(kind==3){int r[7]=int[7](12,18,20,8,21,18,13);return r[row];}if(kind==4){int r[7]=int[7](4,21,14,31,14,21,4);return r[row];}int r[7]=int[7](4,4,4,31,4,4,4);return r[row];}
float fallbackGlyph(vec2 p,int kind){vec2 u=p/vec2(0.24)+0.5;if(u.x<0.0||u.x>=1.0||u.y<0.0||u.y>=1.0)return 0.0;vec2 g=vec2(u.x*5.0,(1.0-u.y)*7.0);int c=clamp(int(floor(g.x)),0,4),r=clamp(int(floor(g.y)),0,6);float e=float((glyphRow(kind,r)>>(4-c))&1);vec2 cell=fract(g)-0.5;return e*(1.0-smoothstep(0.30,0.48,max(abs(cell.x),abs(cell.y))));}
float atlasGlyph(vec2 p,int kind){float px=float(kind)*80.0+8.0+(p.x+0.12)/0.24*48.0;float py=4.0+(0.12-p.y)/0.24*48.0;float s=texture(glyphAtlas,vec2(px/512.0,py/64.0)).r;return step(abs(p.x),0.18)*step(abs(p.y),0.18)*smoothstep(0.05,0.25,s);}
float glyph(vec2 p,int kind){float b=fallbackGlyph(p,kind);float atlasBackground=texture(glyphAtlas,vec2(0.01)).r;float valid=1.0-smoothstep(0.08,0.20,atlasBackground);return mix(b,max(b*0.16,atlasGlyph(p,kind)),valid);}

void main(){
    float H=max(resolution.y,1.0);vec2 uv=(gl_FragCoord.xy-0.5*resolution)/H;float aspect=resolution.x/H;float t=time*0.18;float bounce=sin(t*6.2831*0.52);float scan=fract(t*0.80);
    vec3 col=vec3(0.0015,0.0007,0.007);float horizonY=-0.055;
    float centerGlow=exp(-dot(uv*vec2(0.72,1.05),uv*vec2(0.72,1.05))*2.35);col+=centerGlow*vec3(0.055,0.006,0.095);
    col+=exp(-abs(uv.y-horizonY)*34.0)*vec3(0.20,0.006,0.26);col+=exp(-abs(uv.y-horizonY)*125.0)*vec3(0.55,0.025,0.53);

    // Criss-cross canopy like a stage laser rig.
    for(int i=0;i<8;i++){float fi=float(i);float phase=t*(1.45+0.045*fi)+fi*0.71;float side=mod(fi,2.0)<1.0?-1.0:1.0;vec2 a=vec2(side*aspect*(0.10+0.055*mod(fi,4.0)),horizonY+0.01);vec2 b=vec2(-side*(0.18+0.12*sin(phase)),0.72+0.08*sin(phase*1.31));float beam=neonLine(uv,a,b,220.0,30.0);vec3 bc=mod(fi,2.0)<1.0?vec3(1.0,0.006,0.42):vec3(0.02,0.58,1.0);col+=bc*beam*(0.48+0.32*sin(t*5.4+fi));}

    // Sparse glyph particles high in the scene.
    for(int i=0;i<14;i++){float fi=float(i);vec2 gp=vec2(mod(-1.25+fi*0.37-t*(0.08+0.015*mod(fi,3.0)),2.5)-1.25,0.28+fract(fi*0.417)*0.38);int kind=clamp(int(floor(hash(vec2(fi,7.0))*6.0)),0,5);float g=glyph((uv-gp)/0.52,kind);vec3 gc=mod(fi,2.0)<1.0?vec3(1.0,0.04,0.55):vec3(0.05,0.45,1.0);col+=g*gc*1.5;}

    if(uv.y<horizonY){float depth=max(0.018,horizonY-uv.y);float perspective=0.25/depth;vec2 fuv=vec2(uv.x*perspective,perspective+t*0.72);vec2 cell=floor(fuv);vec2 local=abs(fract(fuv)-0.5);float checker=mod(cell.x+cell.y,2.0);float inversion=step(0.0,sin(t*3.5));float alt=abs(checker-inversion);vec3 dark=vec3(0.003,0.001,0.010),hot=vec3(0.28,0.003,0.13);vec3 fc=mix(dark,hot,alt);float seam=exp(-min(0.5-local.x,0.5-local.y)*48.0);vec3 sc=mix(vec3(0.95,0.015,0.48),vec3(0.07,0.34,0.95),0.5+0.5*sin(cell.y*0.72+t));fc+=seam*sc*0.45;col=mix(col,fc,0.95);col+=exp(-abs(uv.x)*2.2)*exp(-depth*7.5)*vec3(0.18,0.006,0.22);}

    // Main hero figure + depth-scaled side figures. Rotation uses four discrete
    // views: front -> profile -> back -> reverse profile -> front.
    float spinBase=floor(mod(t*1.05,4.0));
    float hero=kittyFrame((uv-vec2(0.0,0.01))/0.58,spinBase,scan,bounce);
    col+=hero*vec3(0.22,0.008,0.48)*0.55;col+=hero*vec3(1.0,0.02,0.58)*0.82;col+=smoothstep(0.85,1.8,hero)*vec3(1.0,0.62,0.94)*0.34;

    for(int i=0;i<4;i++){float fi=float(i);float x=(fi<2.0?-1.0:1.0)*(0.52+0.26*mod(fi,2.0))*aspect;float scale=0.30+0.06*mod(fi,2.0);float frame=floor(mod(spinBase+fi,4.0));float k=kittyFrame((uv-vec2(x,-0.02))/scale,frame,fract(scan+fi*0.19),sin(t*3.4+fi));vec3 kc=mod(fi,2.0)<1.0?vec3(1.0,0.02,0.58):vec3(0.16,0.42,1.0);col+=k*kc*0.72;}

    float vignette=smoothstep(1.2,0.25,length(uv*vec2(0.72,0.95)));col*=0.72+0.28*vignette;col*=0.96+0.04*sin(t*3.2);
    float f=clamp(fade,0.0,1.0);col=mix(vec3(fadeTarget),col,f);finalColor=vec4(clamp(col,0.0,1.0),1.0);
}
