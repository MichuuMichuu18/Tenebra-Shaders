#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform mat4 gbufferProjectionInverse;

// player's render distance, in blocks
uniform float far;

uniform vec3 sunPosition;
uniform float rainStrength;
uniform mat4 gbufferModelView;

uniform vec3 fogColor;
uniform vec3 skyColor;

uniform int isEyeInWater;

in vec2 texcoord;

#include "/lib/util.glsl"
#include "/lib/skyPreetham.glsl"

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

#define FOG_DENSITY 0.2

#define PREETHAM_SKY

#ifdef PREETHAM_SKY
#include "/lib/skyPreetham.glsl"
#endif

void main() {
	color = texture(colortex0, texcoord);

	float depthFull   = texture(depthtex0, texcoord).r;
	float depthOpaque = texture(depthtex1, texcoord).r;

	bool isTranslucent = depthFull < depthOpaque;
	
	if(isTranslucent) {
		if(depthFull == 1.0){
			return;
		}

		vec3 NDCPos = vec3(texcoord.xy, depthFull) * 2.0 - 1.0;
		vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);

		float dist = length(viewPos) / far;
		float fogDensity = FOG_DENSITY;
		if(isEyeInWater == 1) {
			fogDensity *= 5.0;
		} else {
			fogDensity *= rainStrength*2.0+1.0;
		}
		float fogFactor = 1.0 - exp(-fogDensity * dist);
		
		#ifdef PREETHAM_SKY
		vec3 finalFogColor = pow(calcSkyColorPreetham(normalize(viewPos)), vec3(2.2));
		#else
		vec3 finalFogColor = fogColor;
		#endif

		color.rgb = mix(color.rgb, finalFogColor, clamp(fogFactor, 0.0, 1.0));
	}
}
