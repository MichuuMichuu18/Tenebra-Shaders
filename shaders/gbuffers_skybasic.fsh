#version 330 compatibility

uniform int renderStage;
uniform float viewHeight;
uniform float viewWidth;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 fogColor;
uniform vec3 skyColor;
uniform vec3 sunPosition;
uniform float rainStrength;
uniform sampler2D noisetex;
uniform float frameTimeCounter;
uniform sampler2D colortex7;
uniform float far;
in vec4 glcolor;

#include "/lib/util.glsl"

#define PREETHAM_SKY

#define FOG_DENSITY 0.4

#ifdef PREETHAM_SKY
#include "/lib/skyPreetham.glsl"
#else
#include "/lib/skyVanilla.glsl"
#endif

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
    if (renderStage == MC_RENDER_STAGE_STARS) {
        color = glcolor;
    } else {
        // get view direction
        vec3 pos = screenToView(vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), 1.0));

        // sky color
        #ifdef PREETHAM_SKY
        vec3 skyCol = calcSkyColorPreetham(pos);
        #else
        vec3 skyCol = calcSkyColor(normalize(pos));
        #endif
        
        color = vec4(skyCol, 1.0);

	// transform direction to world space
	vec3 cloudPos = normalize(mat3(gbufferModelViewInverse) * pos);
	
	if(cloudPos.y > 0.0) {
	    vec2 cloudUV = cloudPos.xz / cloudPos.y;
	    cloudUV.y *= 1.7; 
	    vec2 wind = vec2(0.03, 0.02) * frameTimeCounter;
	    cloudUV += wind;

	    // noise sampling
	    float shape   = texture(colortex7, cloudUV * 0.02).r;
	    float mid     = texture(colortex7, cloudUV * 0.175).g;
	    float detail  = texture(colortex7, cloudUV * 0.3).b;
	    float extra   = texture(colortex7, cloudUV * 0.5).r;

	    // combine density layers
	    float density = shape;
	    density -= mid * 0.35;      
	    density -= detail * 0.15;   
	    density += extra * 0.1;
	    density = smoothstep(0.2, 0.65, density);
	    density = pow(density, 1.3);

	    // compute approximate 2D normal
	    float dx = texture(colortex7, cloudUV * 0.02 + vec2(0.01,0.0)).r - shape;
	    float dy = texture(colortex7, cloudUV * 0.02 + vec2(0.0,0.01)).r - shape;
	    vec3 normal = normalize(vec3(-dx, 0.1, -dy)); // small vertical bias

	    // sunlight factor
	    vec3 sunDir = normalize(sunPosition);
	    sunDir *= mat3(gbufferModelView);
	    float light = saturate(dot(normal, sunDir)); // simple Lambertian
	    light = 0.5 + 0.5 * light; // soften lighting

	    // horizon / fog
	    float horizon = saturate(cloudPos.y);
	    float fogFactor = exp(-FOG_DENSITY / 4.0 / max(cloudPos.y, 0.001));
	    fogFactor = saturate(fogFactor);

	    // cloud color with lighting
	    vec3 cloudLight = vec3(1.0, 1.0, 1.0);
	    vec3 cloudDark  = vec3(0.85, 0.88, 0.92);
	    vec3 clouds = mix(cloudDark, cloudLight, density);

	    // apply sunlight
	    clouds = mix(clouds * 0.1, clouds, light); // sun brightens edges

	    // blend over sky
	    color.rgb = mix(color.rgb, clouds, saturate(density * fogFactor));
	}
    }
}

