#version 330
in vec2 fragTexCoord; out vec4 finalColor;
uniform vec2 resolution; uniform float time; uniform float fade; uniform float fadeTarget;
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5);}
float n(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1)),f.x),f.y);}
float fb(vec2 p){float v=0.,a=.5;for(int i=0;i<4;i++){v+=a*n(p);p=p*2.02+13.;a*=.5;}return v;}
float seg(vec2 p,vec2 a,vec2 b,float w){vec2 q=p-a,d=b-a;return 1.-smoothstep(w,w+.006,length(q-d*clamp(dot(q,d)/max(dot(d,d),.0001),0.,1.)));}
float tri(vec2 q,float y,float width,float height){float v=clamp((q.y-y)/height,0.,1.);float side=abs(q.x)-width*(1.-v);float band=max(side,max(y-q.y,q.y-(y+height)));return 1.-smoothstep(-.006,.006,band);}
float pine(vec2 q,float s,float seed,float sway){q.x-=sway;float trunk=seg(q,vec2(0.,-.04*s),vec2(.012*s,.23*s),.018*s);float crown=0.;crown=max(crown,tri(q,.10*s,.25*s,.25*s));crown=max(crown,tri(q,.23*s,.20*s,.27*s));crown=max(crown,tri(q,.38*s,.15*s,.24*s));crown=max(crown,tri(q,.51*s,.09*s,.19*s));return max(trunk,crown*(.86+.14*n(q*18.+seed)));}
float layer(vec2 p,float base,float spacing,float size,float drift,float seed){float x=p.x+time*drift,id=floor(x/spacing),lx=mod(x,spacing)-spacing*.5;float r=h(vec2(id,seed));return pine(vec2(lx,p.y-base),size*(.72+.48*r),id+seed,.012*sin(time*.20+id*1.7+seed));}
float disc(vec2 p,vec2 c,float r){return 1.-smoothstep(r,r+.006,length(p-c));}
void main(){
 vec2 p=(gl_FragCoord.xy-.5*resolution)/resolution.y;
 float skyMix=smoothstep(-.55,.58,p.y);vec3 col=mix(vec3(.30,.028,.050),vec3(.055,.010,.030),skyMix);
 col+=vec3(.18,.018,.018)*exp(-abs(p.y+.02)*5.5);
 vec2 moonP=vec2(.46,.30);float moon=disc(p,moonP,.115);float illumination=.5+.5*sin(time*.032);
 float terminator=moonP.x+(1.-illumination*2.)*.115;float lit=smoothstep(terminator-.008,terminator+.008,p.x);
 float crater=disc(p,moonP+vec2(-.040,-.025),.018)*.45+disc(p,moonP+vec2(.035,.030),.014)*.34+disc(p,moonP+vec2(.012,-.055),.010)*.28;
 col=mix(col,vec3(.74,.28,.20),moon*lit);col-=crater*moon*lit*vec3(.25,.10,.08);
 float farRidge=-.08+.18*fb(vec2(p.x*.65+time*.001,4.));float midRidge=-.22+.20*fb(vec2(p.x*.95+time*.003,8.));float nearRidge=-.37+.23*fb(vec2(p.x*1.35+time*.008,15.));
 float farMask=1.-smoothstep(-.012,.012,p.y-farRidge),midMask=1.-smoothstep(-.012,.012,p.y-midRidge),nearMask=1.-smoothstep(-.012,.012,p.y-nearRidge);
 col=mix(col,vec3(.19,.030,.055),farMask);col=mix(col,vec3(.135,.022,.045),midMask);col=mix(col,vec3(.095,.018,.035),nearMask);
 float back=layer(p,-.20,.095,.31,.004,11.),middle=layer(p,-.34,.125,.46,.009,29.),front=layer(p,-.50,.17,.64,.016,61.);
 col=mix(col,vec3(.34,.070,.085),back*.72);col=mix(col,vec3(.24,.045,.060),middle*.86);col=mix(col,vec3(.16,.030,.045),front*.96);
 float mist=fb(vec2(p.x*1.6-time*.014,p.y*3.+21.));float mistBand=exp(-abs(p.y+.19+.035*sin(p.x*2.5-time*.04))*24.)+.65*exp(-abs(p.y+.35+.025*sin(p.x*3.4-time*.03))*31.);
 col=mix(col,vec3(.42,.095,.105),mistBand*(.16+.20*mist));col*=.90+.10*smoothstep(1.3,.25,length(p*vec2(.78,.95)));
 float f=clamp(fade,0.,1.);finalColor=vec4(mix(vec3(fadeTarget),clamp(col,0.,1.),f),1.);
}