#version 330 compatibility

uniform int renderStage;
uniform float viewHeight;
uniform float viewWidth;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform vec3 fogColor;
uniform vec3 skyColor;
uniform vec3 sunPosition;
uniform float rainStrength;
in vec4 glcolor;

#include "/lib/util.glsl"

#define PREETHAM_SKY

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
		vec3 pos = screenToView(vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), 1.0));
		#ifdef PREETHAM_SKY
		color = vec4(calcSkyColorPreetham(pos), 1.0);
		#else
		color = vec4(calcSkyColor(normalize(pos)), 1.0);
		#endif
	}
}
