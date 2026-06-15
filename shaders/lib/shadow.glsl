#ifndef SHADOW_GLSL
#define SHADOW_GLSL

#include "/lib/shadowSettings.glsl"
#include "/lib/distort.glsl"
#include "/lib/util.glsl"

float getDynamicBias(float distance, float penumbra) {
    // we scale the bias by distance and penumbra size. 
    // farther samples need more bias to prevent acne.
    float b = 0.0005 * (distance + 1.0);
    return b + (penumbra * 0.001); 
}

vec3 getShadow(vec3 uvz, float bias) {
    // apply bias only at the point of comparison to keep math clean
    float compareDepth = uvz.z - bias;

    float shadow0 = texture(shadowtex0, uvz.xy).r;
    float shadow1 = texture(shadowtex1, uvz.xy).r;

    // is it behind the transparent layer?
    float isLit = step(compareDepth, shadow0);
    // is it behind the opaque layer?
    float isBlocked = step(shadow1, compareDepth);

    vec4 col = texture(shadowcolor0, uvz.xy);
    vec3 tintedShadow = col.rgb * (1.0 - col.a);
    
    return mix(mix(tintedShadow, vec3(0.0), isBlocked), vec3(1.0), isLit);
}

float findBlockerDepth(vec3 uvz, int maxSamples, float noise) {
    float avg = 0.0;
    int count = 0;
    float texel = 1.0 / float(shadowMapResolution);

    for(int i = 0; i < maxSamples; i++) {
        vec2 offset = vogelDiskSample(i, maxSamples, noise) * BLOCKER_RADIUS * texel;
        float d = texture(shadowtex0, uvz.xy + offset).r;
        
        // use a tiny epsilon here to avoid self-blocking during the search
        if(d < uvz.z - 0.0001) {
            avg += d;
            count++;
        }
    }

    return (count == 0) ? -1.0 : avg / float(count);
}

vec3 getPCSSShadow(vec4 clipPos) {
    float noise = interleavedGradientNoise(gl_FragCoord.xy);
    float depth = texture(depthtex0, texcoord.xy).r;
    vec3 NDC = vec3(texcoord.xy, depth) * 2.0 - 1.0;
    vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDC);
    float distance = length(viewPos) / far;
    vec3 distortedPos = distortShadowClipPos(clipPos.xyz);
    vec3 uvz = distortedPos * 0.5 + 0.5;
    
    #ifdef SHADOW_PCSS_FILTERING
    int blockerSamples = int(mix(8.0, float(BLOCKER_SAMPLES), clamp(distance / MAX_DISTANCE, 0.0, 1.0)));
    float blockerDepth = findBlockerDepth(uvz, blockerSamples, noise);
    
    if(blockerDepth < 0.0) return vec3(1.0); // fully lit

    float penumbra = max(uvz.z - blockerDepth, 0.0) / blockerDepth;
    float filterRadius = clamp(penumbra * LIGHT_RADIUS, 1.0, 32.0);
    
    int baseSamples = SHADOW_SAMPLES;
    int pcfSamples = int(mix(float(baseSamples), 16.0, clamp(distance / MAX_DISTANCE, 0.0, 1.0)));

    vec3 shadow = vec3(0.0);
    float weightTotal = 0.0;
    float dynamicBias = getDynamicBias(distance, penumbra);

    for(int i = 0; i < pcfSamples; i++) {
        vec2 diskSample = vogelDiskSample(i, pcfSamples, noise);
        vec2 offset = diskSample * filterRadius / float(shadowMapResolution);
        
        float w = exp(dot(diskSample, diskSample) * -2.0);

        shadow += getShadow(vec3(clamp(uvz.xy + offset, 0.0, 1.0), uvz.z), dynamicBias) * w;
        weightTotal += w;
    }

    return shadow / weightTotal;

    #else
    return getShadow(uvz, 0.001 * (distance + 1.0));
    #endif
}

#endif
