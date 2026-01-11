#ifndef SHADOW_GLSL
#define SHADOW_GLSL

#include "/lib/shadowSettings.glsl"
#include "/lib/distort.glsl"
#include "/lib/util.glsl"

vec3 getShadow(vec3 shadowScreenPos){
  float transparentShadow = step(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r); // sample the shadow map containing everything

  /*
  note that a value of 1.0 means 100% of sunlight is getting through
  not that there is 100% shadowing
  */

  if(transparentShadow == 1.0){
    /*
    since this shadow map contains everything,
    there is no shadow at all, so we return full sunlight
    */
    return vec3(1.0);
  }

  float opaqueShadow = step(shadowScreenPos.z, texture(shadowtex1, shadowScreenPos.xy).r); // sample the shadow map containing only opaque stuff

  if(opaqueShadow == 0.0){
    // there is a shadow cast by something opaque, so we return no sunlight
    return vec3(0.0);
  }

  // contains the color and alpha (transparency) of the thing casting a shadow
  vec4 shadowColor = texture(shadowcolor0, shadowScreenPos.xy);


  /*
  we use 1 - the alpha to get how much light is let through
  and multiply that light by the color of the caster
  */
  return shadowColor.rgb * (1.0 - shadowColor.a);
}

float findBlockerDepth(vec3 shadowScreenPos, float distance, float noise) {
    float receiverDepth = shadowScreenPos.z;

    float avgBlockerDepth = 0.0;
    int blockerCount = 0;
    
    float texelSize = 1.0 / float(shadowMapResolution);
    
    // adaptive sample count based on distance (reusing distance from shadow function)
	int samples = int(mix(8.0, BLOCKER_SAMPLES, clamp(distance/MAX_DISTANCE, 0.0, 1.0)));

    for (int i = 0; i < samples; i++) {
        vec2 offset =
            vogelDiskSample(i, samples, noise) *
            BLOCKER_RADIUS * texelSize;

        float shadowDepth =
            texture(shadowtex0, shadowScreenPos.xy + offset).r;

        if (shadowDepth < receiverDepth) {
            avgBlockerDepth += shadowDepth;
            blockerCount++;
        }
    }

    if (blockerCount == 0)
        return -1.0; // no blockers

    return avgBlockerDepth / float(blockerCount);
}

vec3 getPCSSShadow(vec4 shadowClipPos) {
	float texelSize = 1.0 / float(shadowMapResolution);
	float noise = interleavedGradientNoise(gl_FragCoord.xy);
	
	float depth = texture(depthtex0, texcoord).r;
    vec3 NDCPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
	vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);

	float distance = length(viewPos) / far;
	
	// actual shadow rendering starts here
    
    vec3 shadowAccum = vec3(0.0);

    vec4 distortedClipPos = shadowClipPos;
    distortedClipPos.z -= 0.001;
    distortedClipPos.xyz = distortShadowClipPos(distortedClipPos.xyz);

    vec3 shadowNDC = distortedClipPos.xyz / distortedClipPos.w;
    vec3 shadowUVZ = shadowNDC * 0.5 + 0.5;

    float blockerDepth = findBlockerDepth(shadowUVZ, distance, noise);
    if (blockerDepth < 0.0) return vec3(1.0); // skip if fully lit

    float penumbra = (shadowUVZ.z - blockerDepth) / blockerDepth;
    float filterRadius = penumbra * LIGHT_RADIUS;

	// adaptive sample count based on penumbra
    int samples = SHADOW_SAMPLES;
	if (penumbra < LIGHT_RADIUS * 0.1) samples /= 4;   // small penumbra
	else if (penumbra < LIGHT_RADIUS * 0.25) samples /= 2;
	else samples = SHADOW_SAMPLES;
	
	float totalWeight = 0.0;
	// adaptive sample count based on distance
	int pcfSamples = int(mix(12.0, samples, clamp(distance / MAX_DISTANCE, 0.0, 1.0)));
    float weightCoeff = (2.0 * filterRadius*filterRadius);
    for (int i = 0; i < pcfSamples; i++) {
        vec2 offset = vogelDiskSample(i, pcfSamples, noise)
                      * filterRadius * texelSize;
             
    		// Gaussian-like weighthing
		float weight = exp(-dot(offset, offset) / weightCoeff);
        vec2 uv = clamp(shadowUVZ.xy + offset, 0.0, 1.0);
		shadowAccum += getShadow(vec3(uv, shadowUVZ.z)) * weight;
        totalWeight += weight;
    }

    return shadowAccum / totalWeight;
}

#endif
