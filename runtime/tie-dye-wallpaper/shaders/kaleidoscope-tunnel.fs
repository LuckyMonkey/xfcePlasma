#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform vec2 resolution;
uniform float time;
uniform float fade;
uniform float fadeTarget;

vec3 hsv(float h,float s,float v){vec3 p=abs(fract(h+vec3(0.,2./3.,1./3.))*6.-3.);return v*mix(vec3(1),clamp(p-1.,0.,1.),s);}

void main(){
    vec2 uv=(gl_FragCoord.xy-.5*resolution)/resolution.y;
    float t=time*0.16;
    float a=atan(uv.y,uv.x);
    float r=length(uv)+0.001;
    float folds=8.0+2.0*sin(time*0.07);
    a=abs(mod(a+t,6.283185/folds)-3.141592/folds);
    vec2 p=vec2(cos(a),sin(a))/r;
    float bands=sin(p.x*0.75+t*5.0)+cos(p.y*0.95-time*3.0)+sin(log(r)*7.0-time*1.4);
    float edge=smoothstep(0.05,0.32,abs(sin(bands*2.2)));
    vec3 col=hsv(0.55+0.18*bands+0.05*time,0.82,0.2+0.8*edge);
    col*=1.0-smoothstep(0.95,1.65,r)*0.6;
    col+=0.12/(r*8.0+1.0)*hsv(0.85+time*0.03,0.7,1.0);
    float f=clamp(fade,0.,1.);
    col=mix(vec3(fadeTarget),col,f);
    finalColor=vec4(clamp(col,0.,1.),1.);
}
