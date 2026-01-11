#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D depthtex0;

uniform mat4 gbufferProjectionInverse;

// player's render distance, in blocks
uniform float far;

uniform vec3 fogColor;

uniform int isEyeInWater;
uniform float rainStrength;

in vec2 texcoord;

#include "/lib/util.glsl"

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

#define FOG_DENSITY 5.0

void main() {
	color = texture(colortex0, texcoord);

	float depth = texture(depthtex0, texcoord).r;
	if(depth == 1.0){
		return;
	}

	vec3 NDCPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
	vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);

	float dist = length(viewPos) / far;
	float fogDensity = FOG_DENSITY;
	if(isEyeInWater == 1) {
		fogDensity /= 5.0;
	} else {
		fogDensity /= rainStrength*2.0+1.0;
	}
	float fogFactor = exp(-fogDensity * (1.0 - dist));

	color.rgb = mix(color.rgb, pow(fogColor, vec3(2.2)), clamp(fogFactor, 0.0, 1.0));
}
