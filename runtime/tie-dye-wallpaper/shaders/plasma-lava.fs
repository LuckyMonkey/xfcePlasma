#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform vec2 resolution;
uniform float time;
uniform float fade;
uniform float fadeTarget;

float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y);}
float fbm(vec2 p){float v=0.0,a=.55;for(int i=0;i<4;i++){v+=a*noise(p);p=mat2(1.45,-1.25,1.25,1.45)*p+0.21;a*=.48;}return v;}
float ellipse(vec2 p,vec2 r){return 1.-smoothstep(1.,1.015,dot(p/r,p/r));}
float flame(vec2 p,float x,float scale,float phase){
    p.x-=x+.035*sin(time*.32+phase);
    p.y-=.10+.025*sin(time*.4+phase);
    p.x*=1.0+.18*p.y;
    float body=ellipse(p,vec2(.12*scale,.34*scale));
    float tip=ellipse(p-vec2(.045,.22*scale),vec2(.055*scale,.17*scale));
    return max(body,tip);
}

void main(){
    vec2 uv=(gl_FragCoord.xy-.5*resolution)/resolution.y;
    float t=time*.045;
    float n=fbm(uv*3.1+vec2(t*.16,-t*.08));
    vec3 col=vec3(.018,.012,.014)+n*vec3(.035,.012,.008);
    // Hearth masonry and a bed of coals establish a clear yule-log scene.
    float hearth=smoothstep(.02,-.01,abs(uv.y-.18)-.34);
    col=mix(col,vec3(.10,.035,.028)+n*.035,hearth*.32);
    float coal=ellipse(uv-vec2(0.,-.38),vec2(.72,.13));
    col=mix(col,vec3(.16,.025,.012),coal);
    for(int i=0;i<3;i++){
        float fi=float(i);
        vec2 lp=uv-vec2(-.34+fi*.34,-.24+fi*.025);
        lp.x+=lp.y*(fi-.8)*.45;
        float log=ellipse(lp,vec2(.38,.105));
        float end=ellipse(lp-vec2(.32,0.),vec2(.11,.105));
        float grain=sin(lp.x*34.+noise(lp*9.)*3.+t*.25)*.5+.5;
        col=mix(col,vec3(.20,.045,.025)+grain*vec3(.16,.035,.012),log);
        col=mix(col,vec3(.34,.09,.035),end*.7);
    }
    float fireGlow=exp(-max(uv.y+.05,0.)*3.2)*(.12+.18*n);
    col+=fireGlow*vec3(1.,.12,.015);
    float outer=0.;
    outer=max(outer,flame(uv,-.25,.9,1.));
    outer=max(outer,flame(uv,.00,1.18,2.4));
    outer=max(outer,flame(uv,.25,.78,4.1));
    outer*=smoothstep(-.42,.02,uv.y)*smoothstep(.62,.48,uv.y);
    float inner=0.;
    inner=max(inner,flame(uv-.02*vec2(sin(t*2.),0.),-.02,.68,3.));
    inner*=smoothstep(-.30,.06,uv.y)*smoothstep(.45,.22,uv.y);
    col=mix(col,vec3(1.,.16,.018),outer);
    col=mix(col,vec3(1.,.78,.20),inner);
    col+=pow(outer,4.)*vec3(1.,.32,.03);
    float f=clamp(fade,0.,1.);
    col=mix(vec3(fadeTarget),col,f);
    finalColor=vec4(clamp(col,0.,1.),1.);
}
