#version 330 compatibility

/*

deferred1.fsh/composite1.fsh

Fog blending + GI bilateral filter

*/

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex6;
uniform sampler2D depthtex0;

uniform mat4 gbufferProjectionInverse;

uniform float far;
uniform vec3 fogColor;
uniform vec3 skyColor;
uniform float rainStrength;
uniform int isEyeInWater;

uniform vec3 sunPosition;
uniform mat4 gbufferModelView;

in vec2 texcoord;

#include "/lib/util.glsl"

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

#define PREETHAM_SKY

#ifdef PREETHAM_SKY
#include "/lib/skyPreetham.glsl"
#endif

#define FOG
#define FOG_DENSITY 0.2

#define GI
#define GI_SCALE 0.5 // matches what's in shaders.properties

#define SSAO

#if defined(GI) || defined(SSAO)

vec3 filterGI(vec2 uv) {
	float centerDepth = texture(depthtex0, uv).r;
	vec3 centerNormal = normalize((texture(colortex2, uv).rgb - 0.5) * 2.0);
	vec2 texel = 1.0 / vec2(textureSize(colortex6, 0));

	vec3 result = vec3(0.0);
	float totalWeight = 0.0;

	for(int x = -2; x <= 2; x++) {
		for(int y = -2; y <= 2; y++) {

			vec2 offset = vec2(x, y) * texel;
			vec2 sampleUV = uv*GI_SCALE + offset;

			vec3 sampleGI = texture(colortex6, sampleUV).rgb;
			float sampleDepth = texture(depthtex0, sampleUV/GI_SCALE).r;

			vec3 sampleNormal = normalize((texture(colortex2, sampleUV/GI_SCALE).rgb - 0.5) * 2.0);

			float depthDiff = abs(centerDepth - sampleDepth);
			float depthWeight = exp(-depthDiff * 80.0);

			float normalWeight = pow(max(dot(centerNormal, sampleNormal), 0.0), 1.0);
			float weight = depthWeight * normalWeight;

			result += sampleGI * weight;
			totalWeight += weight;
		}
	}

	return result / max(totalWeight, 0.0001);
}

#endif

void main() {

	color = texture(colortex0, texcoord);


	float depth = texture(depthtex0, texcoord).r;
	if(depth == 1.0) {
		return;
	}

#if defined(GI) || defined(SSAO)
	// Apply filtered GI instead of raw
	vec3 gi = filterGI(texcoord);
	color.rgb *= gi;
	#endif
	
	#ifdef FOG
		vec3 NDCPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
		vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);

		float dist = length(viewPos) / far;
		float fogDensity = FOG_DENSITY;
		if(isEyeInWater == 1) {
			fogDensity *= 5.0;
		} else {
			fogDensity *= rainStrength*4.0+1.0;
		}
		float fogFactor = 1.0 - exp(-fogDensity * dist);
		
		#ifdef PREETHAM_SKY
		vec3 finalFogColor = pow(calcSkyColorPreetham(normalize(viewPos)), vec3(2.2));
		#else
		vec3 finalFogColor = fogColor;
		#endif

		color.rgb = mix(color.rgb, finalFogColor, clamp(fogFactor, 0.0, 1.0));
	#endif
}
