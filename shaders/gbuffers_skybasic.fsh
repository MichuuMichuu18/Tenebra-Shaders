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
uniform float eyeAltitude;
uniform float rainStrength;
uniform sampler2D noisetex;
uniform float frameTimeCounter;
uniform sampler2D colortex7;
uniform float sunAngle;
uniform float far;
in vec4 glcolor;

#include "/lib/util.glsl"

#define PREETHAM_SKY
#define 2D_CLOUDS

#define FOG_DENSITY 0.3

#ifdef PREETHAM_SKY
#include "/lib/skyPreetham.glsl"
#include "/lib/lighting.glsl"
#else
#include "/lib/skyVanilla.glsl"
#endif

#ifdef 2D_CLOUDS
#include "/lib/clouds2D.glsl"
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
        float dayFactor = getDayFactor();
        vec3 sunColor = calcSunColor(dayFactor);
        vec3 sun = calcSunDisc(pos)*sunColor;
        color = vec4(skyCol+sun, 1.0);
        #else
        color = vec4(calcSkyColor(pos), 1.0);
        #endif
	
	#ifdef 2D_CLOUDS
	// Transform direction to world space
	vec3 cloudPos = normalize(mat3(gbufferModelViewInverse) * pos);
	vec4 clouds = renderClouds(cloudPos);
	color.rgb = mix(color.rgb, clouds.rgb, clouds.a);
	#endif
    }
}

