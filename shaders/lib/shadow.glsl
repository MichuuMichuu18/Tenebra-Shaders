#ifndef SHADOW_GLSL
#define SHADOW_GLSL

#include "/lib/shadowSettings.glsl"
#include "/lib/distort.glsl"
#include "/lib/util.glsl"

// optimized shadow sample
vec3 getShadow(vec3 uvz) {
    float shadow0 = texture(shadowtex0, uvz.xy).r;
    float shadow1 = texture(shadowtex1, uvz.xy).r;

    // is it behind the transparent layer?
    float isLit = step(uvz.z, shadow0);
    // is it behind the opaque layer?
    float isBlocked = step(shadow1, uvz.z);

    vec4 col = texture(shadowcolor0, uvz.xy);
    vec3 tintedShadow = col.rgb * (1.0 - col.a);
    
    return mix(mix(tintedShadow, vec3(0.0), isBlocked), vec3(1.0), isLit);
}

// find average blocker depth
float findBlockerDepth(vec3 uvz, int maxSamples, float noise){
	float avg = 0.0;
	int count = 0;
	float texel = 1.0 / float(shadowMapResolution);

	for(int i=0; i<maxSamples; i++){
		vec2 offset = vogelDiskSample(i, maxSamples, noise) * BLOCKER_RADIUS * texel;
		float d = texture(shadowtex0, uvz.xy + offset).r;
		if(d < uvz.z){
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
	float blockerDepth = findBlockerDepth(uvz, blockerSamples, noise);
	if(blockerDepth < 0.0) return vec3(1.0); // fully lit

	// penumbra
	float penumbra = (uvz.z - blockerDepth) / blockerDepth;
	float maxFilterRadius = 32.0; // clamp faraway penumbra
	float filterRadius = clamp(penumbra * LIGHT_RADIUS, 1.0, maxFilterRadius);

	// PCF samples: fewer for far geometry
	int baseSamples = SHADOW_SAMPLES;
	int pcfSamples = int(mix(float(baseSamples), 16.0, clamp(distance / MAX_DISTANCE, 0.0, 1.0)));

	// accumulate
	vec3 shadow = vec3(0.0);
	float weightTotal = 0.0;
	
	// pre-calculate weight coefficient
	// (actually just -2.0 might be better, because this ensures more samples = more detail)
	float weightCoeff = -2.0; // 2.0 * filterRadius * filterRadius;

	for(int i=0; i<pcfSamples; i++){
		vec2 offset = vogelDiskSample(i, pcfSamples, noise) * filterRadius / float(shadowMapResolution);
		float w = exp(dot(offset, offset)*weightCoeff);
		shadow += getShadow(vec3(clamp(uvz.xy + offset, 0.0, 1.0), uvz.z)) * w;
		weightTotal += w;
	}

	return shadow / weightTotal;
}

#endif

