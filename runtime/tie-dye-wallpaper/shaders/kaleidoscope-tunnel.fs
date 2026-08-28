#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform vec2 resolution;
uniform float time;
uniform float fade;
uniform float fadeTarget;

const float PI=3.141592653589793;
const float TAU=6.283185307179586;
vec3 hsv(float h,float s,float v){vec3 p=abs(fract(h+vec3(0.,2./3.,1./3.))*6.-3.);return v*mix(vec3(1),clamp(p-1.,0.,1.),s);}

void main(){
    vec2 uv=(gl_FragCoord.xy-0.5*resolution)/resolution.y;
    float r=max(length(uv),0.001);
    float rotation=time*0.055;

    // Fold a fixed integer number of sectors. Centering the modulo before the
    // absolute mirror keeps both sides identical at every sector boundary.
    const float folds=10.0;
    float halfSector=PI/folds;
    float angle=atan(uv.y,uv.x)+rotation;
    float mirrored=abs(mod(angle+halfSector,2.0*halfSector)-halfSector);
    vec2 wedge=vec2(cos(mirrored),sin(mirrored))*r;

    // Every term is even across the mirrored axis, so circles and ribbons meet
    // continuously instead of producing the old horizontal bifocal seam.
    float tunnel=log(r)*7.4-time*0.58;
    float circles=cos(length(wedge-vec2(0.22,0.10))*54.0-time*0.85);
    float ribbons=cos(wedge.x*38.0+2.6*sin(tunnel))*cos(wedge.y*43.0);
    float radial=sin(tunnel*2.0)+0.72*cos(tunnel*3.0+mirrored*folds);
    float field=0.48*circles+0.72*ribbons+0.58*radial;
    float light=smoothstep(-0.45,0.82,field);
    float filigree=pow(1.0-abs(sin(field*2.5)),7.0);

    vec3 col=hsv(0.57+0.14*field+0.055*time,0.80,0.17+0.83*light);
    col+=filigree*hsv(0.88+0.04*sin(time*0.12),0.55,0.72)*0.34;
    col*=1.0-smoothstep(0.92,1.72,r)*0.62;
    col+=0.11/(r*8.0+1.0)*hsv(0.84+time*0.025,0.68,1.0);

    float f=clamp(fade,0.,1.);
    col=mix(vec3(fadeTarget),col,f);
    finalColor=vec4(clamp(col,0.,1.),1.);
}
