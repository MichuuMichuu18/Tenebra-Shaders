#ifndef SHADOW_GLSL
#define SHADOW_GLSL

#include "/lib/shadowSettings.glsl"
#include "/lib/distort.glsl"
#include "/lib/util.glsl"

// basic shadow sample
vec3 getShadow(vec3 uvz){
	float trans = step(uvz.z, texture(shadowtex0, uvz.xy).r);
	if(trans >= 1.0) return vec3(1.0);

	float opaque = step(uvz.z, texture(shadowtex1, uvz.xy).r);
	if(opaque <= 0.0) return vec3(0.0);

	vec4 col = texture(shadowcolor0, uvz.xy);
	return col.rgb * (1.0 - col.a);
}

// find average blocker depth
float findBlockerDepth(vec3 uvz, int maxSamples){
	float depth = uvz.z;
	float avg = 0.0;
	int count = 0;
	float texel = 1.0 / float(shadowMapResolution);

	for(int i=0; i<maxSamples; i++){
		vec2 offset = vogelDiskSample(i, maxSamples, interleavedGradientNoise(gl_FragCoord.xy)) * BLOCKER_RADIUS * texel;
		float d = texture(shadowtex0, uvz.xy + offset).r;
		if(d < depth){
			avg += d;
			count++;
		}
	}

	return (count == 0) ? -1.0 : avg / float(count);
}

vec3 getPCSSShadow(vec4 clipPos){
	float noise = interleavedGradientNoise(gl_FragCoord.xy);

	// transform to NDC / view space
	float depth = texture(depthtex0, texcoord).r;
	vec3 NDC = vec3(texcoord.xy, depth) * 2.0 - 1.0;
	vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDC);
	float distance = length(viewPos) / far;

	// shadow UVZ
	vec4 dClip = clipPos;
	dClip.z -= 0.00075*(distance+1.0);
	dClip.xyz = distortShadowClipPos(dClip.xyz);
	vec3 uvz = dClip.xyz / dClip.w * 0.5 + 0.5;

	// blocker search
	int blockerSamples = int(mix(8.0, BLOCKER_SAMPLES, clamp(distance / MAX_DISTANCE, 0.0, 1.0)));
	float blockerDepth = findBlockerDepth(uvz, blockerSamples);
	if(blockerDepth < 0.0) return vec3(1.0); // fully lit

	// penumbra
	float penumbra = (uvz.z - blockerDepth) / blockerDepth;
	float maxFilterRadius = 32.0; // clamp faraway penumbra
	float filterRadius = clamp(penumbra * LIGHT_RADIUS, 1.0, maxFilterRadius);

	// PCF samples: fewer for far geometry
	int baseSamples = SHADOW_SAMPLES;
	int pcfSamples = int(mix(9.0, float(baseSamples), clamp(distance / MAX_DISTANCE, 0.0, 1.0)));

	// accumulate
	vec3 shadow = vec3(0.0);
	float weightTotal = 0.0;
	float weightCoeff = 2.0 * filterRadius * filterRadius;

	for(int i=0; i<pcfSamples; i++){
		vec2 offset = vogelDiskSample(i, pcfSamples, noise) * filterRadius / float(shadowMapResolution);
		float w = exp(-dot(offset, offset)/weightCoeff);
		shadow += getShadow(vec3(clamp(uvz.xy + offset, 0.0, 1.0), uvz.z)) * w;
		weightTotal += w;
	}

	return shadow / weightTotal;
}

#endif

