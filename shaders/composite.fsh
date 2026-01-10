#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D noisetex;

// the position of the sun or the moon depending on daytime
uniform vec3 shadowLightPosition;
// used when converting view space to world space
uniform mat4 gbufferModelViewInverse;

// uniform needed for converting shadow pass' pixel space to shadow space
uniform mat4 gbufferProjectionInverse;
// uniform mat4 gbufferModelViewInverse; this one is already defined
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform float viewWidth;
uniform float viewHeight;

uniform int worldTime;

uniform float far;

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

const vec3 blocklightColor = vec3(1.0, 0.5, 0.08);
const vec3 skylightColor = vec3(0.1, 0.2, 0.4);
const vec3 sunlightColor = vec3(1.0, 0.95, 0.9);//vec3(1.0, 0.9, 0.8);
const vec3 moonlightColor = vec3(0.05);
const vec3 ambientColor = vec3(0.02);

const float sunPathRotation = -35.0;

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

/*

// defines the total radius in which we sample (in pixels)
#define SHADOW_RADIUS 1
// controls how many samples we take for every pixel we sample
#define SHADOW_RANGE 4

vec3 getSoftShadow(vec4 shadowClipPos){
  vec3 shadowAccum = vec3(0.0); // sum of all shadow samples
  const int samples = SHADOW_RANGE * SHADOW_RANGE * 4; // we are taking 2 * SHADOW_RANGE * 2 * SHADOW_RANGE samples
  
  float noise = getNoise(texcoord).r;

  float theta = noise * radians(360.0); // random angle using noise value
  float cosTheta = cos(theta);
  float sinTheta = sin(theta);

  mat2 rotation = mat2(cosTheta, -sinTheta, sinTheta, cosTheta); // matrix to rotate the offset around the original position by the angle

  for(int x = -SHADOW_RANGE; x < SHADOW_RANGE; x++){
    for(int y = -SHADOW_RANGE; y < SHADOW_RANGE; y++){
      vec2 offset = vec2(x, y) * SHADOW_RADIUS / float(SHADOW_RANGE);
      offset = rotation * offset; // rotate the sampling kernel using the rotation matrix we constructed
      offset /= shadowMapResolution; // offset in the rotated direction by the specified amount. We divide by the resolution so our offset is in terms of pixels
      vec4 offsetShadowClipPos = shadowClipPos + vec4(offset, 0.0, 0.0); // add offset
      offsetShadowClipPos.z -= 0.002; // apply bias
      offsetShadowClipPos.xyz = distortShadowClipPos(offsetShadowClipPos.xyz); // apply distortion
      vec3 shadowNDCPos = offsetShadowClipPos.xyz / offsetShadowClipPos.w; // convert to NDC space
      vec3 shadowScreenPos = shadowNDCPos * 0.5 + 0.5; // convert to screen space
      shadowAccum += getShadow(shadowScreenPos); // take shadow sample
    }
  }

  return shadowAccum / float(samples); // divide sum by count, getting average shadow
}*/

// Golden angle in radians
const float GOLDEN_ANGLE = 2.39996323; // pi * (3 - sqrt(5))

// Vogel disk sampling
vec2 vogelDiskSample(int i, int n, float rand) {
    float r = sqrt((float(i) + rand) / float(n));
    float theta = float(i) * GOLDEN_ANGLE;
	theta += rand;
    return r * vec2(cos(theta), sin(theta));
}


/*
vec3 getSoftShadow(vec4 shadowClipPos) {
    vec3 shadowAccum = vec3(0.0);
    
    // Screen-space noise seed (stable per-pixel)
    float noise = interleavedGradientNoise(gl_FragCoord.xy);
    float rotation = noise * 6.2831853;

    for (int i = 0; i < SHADOW_SAMPLES; i++) {
        vec2 diskOffset = vogelDiskSample(i, SHADOW_SAMPLES, rotation);

        // Scale by radius and convert to texel space
        vec2 offset = diskOffset * SHADOW_RADIUS;
        //offset *= penumbraSize;
        offset /= shadowMapResolution;

        vec4 offsetShadowClipPos = shadowClipPos + vec4(offset, 0.0, 0.0);
        offsetShadowClipPos.z -= 0.001; // bias

        offsetShadowClipPos.xyz =
            distortShadowClipPos(offsetShadowClipPos.xyz);

        vec3 shadowNDCPos =
            offsetShadowClipPos.xyz / offsetShadowClipPos.w;

        vec3 shadowScreenPos =
            shadowNDCPos * 0.5 + 0.5;

        shadowAccum += getShadow(shadowScreenPos);
    }

    return shadowAccum / float(samples);
}*/


const int shadowMapResolution = 2048;

#define SHADOW_SAMPLES 16   // 16 = cheap, 32 = good, 64 = very soft
//#define SHADOW_RADIUS 1.5 // tune per light

const int BLOCKER_SAMPLES = 16;
const float BLOCKER_RADIUS = 16.0; // in shadow map texels

#define LIGHT_RADIUS 192.0
#define MAX_DISTANCE 128.0 // probably needs tweaking

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

float getDayFactor(float time) {
    const float sunrise = 23215.0;
    const float sunset  = 12785.0;
    const float twilight = 1000.0; // adjust softness

    float day = 0.0;

    // Daytime region (wraps around)
    if (time >= sunrise || time < sunset) {
        day = 1.0;

        // Sunrise fade-in
        if (time >= sunrise) {
            day = smoothstep(sunrise, sunrise + twilight, time);
        }

        // Sunset fade-out (wrapped part)
        if (time < twilight) {
            day = smoothstep(twilight, 0.0, time);
        }
    }

    return clamp(day, 0.0, 1.0);
}


void main() {
	color = texture(colortex0, texcoord);
	color.rgb = pow(color.rgb, vec3(2.2)); // convert colors to linear scale cuz we work with lighting

	float depth = texture(depthtex0, texcoord).r;
	if (depth == 1.0) {
		return; // skip lighting calculation if the current rendered pixel is far away according to depth (its the sky)
	}
	
	vec2 lightmap = texture(colortex1, texcoord).rg; // we only need the r and g components
	vec3 encodedNormal = texture(colortex2, texcoord).rgb;
	vec3 normal = normalize((encodedNormal - 0.5) * 2.0); // we normalize to make sure it is of unit length, normal of ours is in world space
	vec3 lightVector = normalize(shadowLightPosition); // normalizing position (values -1.0-1.0 -> 0.0-1.0)
	vec3 worldLightVector = mat3(gbufferModelViewInverse) * lightVector; 
	
	// lots of magic, but anyway - lets render shadow for sunlight
	vec3 NDCPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
	vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);
	vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
	vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
	vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);

	/*

	--- moved to getSoftShadow(); ---
	shadowClipPos.z -= 0.001; // shadow bias - reduces shadow acne (a shadow casted by surfaces onto themselves thanks to lack of precision, looks glitchy af)
	shadowClipPos.xyz = distortShadowClipPos(shadowClipPos.xyz); // apply distortion from shadow.vsh
	vec3 shadowNDCPos = shadowClipPos.xyz / shadowClipPos.w;
	vec3 shadowScreenPos = shadowNDCPos * 0.5 + 0.5; // finally we get space converted shadow position
	---------------------------------

	//float shadow = step(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r); // step(a,b) -> return 1.0 if b>a

	*/
	
	vec3 blocklight = lightmap.r * blocklightColor;
	vec3 skylight = lightmap.g * skylightColor;
	vec3 ambient = ambientColor;
	
	vec3 shadow = getPCSSShadow(shadowClipPos);
	vec3 sunlight = clamp(dot(worldLightVector, normal), 0.0, 1.0) * lightmap.g * shadow; // clamp dot product to not get negative sunlight (its impossible irl duh unless we discover black holes in minecraft)

	float dayFactor = getDayFactor(worldTime);
	vec3 light = blocklight + skylight + ambient + mix(moonlightColor, sunlightColor, dayFactor) * sunlight;	

	color.rgb *= light;
	color.rgb *= 1.2; //REMOVE IF DOING ANY REAL WORK
	
	// b-crap here
	//color.rgb = texture(shadowtex0, texcoord).rgb;
	//color.rgb = vec3(lightmap, 0.0); //yes, lightmap sky is bright even in the night, cuz no matter what time of day it is, there's still e.g. 100% light of the night/day outside or anywhere else
	//float grayscale = dot(color.rgb, vec3(1.0/3.0));
	//color.rgb = vec3(grayscale);
}
