#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform vec2 resolution;
uniform float time;
uniform float fade;
uniform float fadeTarget;

float hash(vec2 p){return fract(sin(dot(p,vec2(97.13,313.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y);}
float fbm(vec2 p){float v=0.0,a=0.5;for(int i=0;i<4;i++){v+=a*noise(p);p=mat2(1.55,-1.05,1.05,1.55)*p+0.23;a*=0.5;}return v;}
vec3 hsv(float h,float s,float v){vec3 p=abs(fract(h+vec3(0.,2./3.,1./3.))*6.-3.);return v*mix(vec3(1),clamp(p-1.,0.,1.),s);}

void main(){
    vec2 uv=(gl_FragCoord.xy-0.5*resolution)/resolution.y;
    float t=time*0.065;
    float spin=0.12*sin(time*0.035);
    mat2 rot=mat2(cos(spin),-sin(spin),sin(spin),cos(spin));
    vec2 p=rot*uv;
    p+=0.12*vec2(sin(p.y*3.0+t),cos(p.x*2.7-t));

    // Keep the dot language consistently fine; animate density subtly rather than
    // jumping between two unrelated object scales.
    float grid=58.0+5.0*sin(time*0.045);
    vec2 cell=floor(p*grid);
    vec2 local=fract(p*grid)-0.5;
    float field=fbm(cell*0.08+vec2(t*0.45,-t*0.31));
    float wave=sin(length(p)*9.0-time*0.8)+sin((p.x+p.y)*5.0+t)+sin(p.x*8.0-field*4.0);
    float radius=0.09+0.36*smoothstep(-2.0,2.2,wave+field*2.0);
    radius*=0.72+0.35*sin(cell.x*0.37+cell.y*0.21+time*0.22);
    float dot=1.0-smoothstep(radius,radius+0.055,length(local));

    float ring=abs(sin(length(uv)*10.0-time*0.95));
    vec3 bg=hsv(0.62+0.07*sin(time*0.05)+0.06*uv.y,0.55,0.08+0.12*ring);
    vec3 inkA=hsv(0.88+0.18*field+time*0.010,0.82,1.0);
    vec3 inkB=hsv(0.47+0.25*sin(wave+time*0.055),0.78,0.95);
    vec3 ink=mix(inkA,inkB,smoothstep(-0.4,0.9,sin(cell.x*0.13-cell.y*0.19+time*0.35)));
    vec3 col=mix(bg,ink,dot);
    col+=0.08*hsv(0.16+field,0.7,1.0)*smoothstep(0.78,1.0,dot)*sin(time+field*6.2831);

    float f=clamp(fade,0.,1.);
    col=mix(vec3(fadeTarget),col,f);
    finalColor=vec4(clamp(col,0.,1.),1.);
}
