#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform vec2 resolution;
uniform float time;
uniform float fade;
uniform float fadeTarget;

float hash(vec2 p){return fract(sin(dot(p,vec2(17.7,93.2)))*34931.13);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y);}
float fbm(vec2 p){float v=0.0,a=0.5;for(int i=0;i<4;i++){v+=a*noise(p);p=mat2(1.8,-0.7,0.7,1.8)*p+0.17;a*=0.5;}return v;}

void main(){
    vec2 uv=(gl_FragCoord.xy-.5*resolution)/resolution.y;
    float t=time*.04;
    float depth=smoothstep(-0.75,0.55,-uv.y);
    float swell=fbm(uv*1.2+vec2(t*.35,-t*.15));
    float caustic=0.0;
    for(int i=0;i<4;i++){
        float fi=float(i);
        caustic+=sin((uv.x+sin(uv.y*2.0+t+fi))*8.0+fi*1.7+t*(1.0+fi*.15)+swell*3.0);
    }
    caustic=smoothstep(2.15,3.35,caustic)*0.55;
    vec3 top=vec3(0.02,0.25,0.35);
    vec3 bottom=vec3(0.0,0.018,0.055);
    vec3 col=mix(top,bottom,depth);
    col+=vec3(0.08,0.7,0.95)*caustic*(1.0-depth*0.65);
    col+=vec3(0.0,0.05,0.12)*swell;
    float f=clamp(fade,0.,1.);
    col=mix(vec3(fadeTarget),col,f);
    finalColor=vec4(clamp(col,0.,1.),1.);
}
