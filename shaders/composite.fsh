#version 330 compatibility

/*

composite.fsh

calculate lighting and reflections visible on stained glass and water

*/

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex7;
uniform sampler2D gaux4;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D noisetex;

uniform vec3 shadowLightPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 cameraPosition;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float sunAngle;
uniform vec3 skyColor;
uniform vec3 fogColor;
uniform float eyeAltitude;
uniform float frameTimeCounter;
uniform vec3 sunPosition;
uniform float far;
uniform float near;

in vec2 texcoord;
in float dayFactor;
in vec3 sunColor;
in vec2 windOffset;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

#include "/lib/distort.glsl"
#include "/lib/util.glsl"
#include "/lib/shadow.glsl"
#include "/lib/lighting.glsl"
#include "/lib/ssr.glsl"

#define WATER_REFLECTIONS
#define WATER_REFRACTIONS
#define PREETHAM_SKY
#define CLOUDS_2D
#define FOG_DENSITY 0.2 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]

#ifdef PREETHAM_SKY
#include "/lib/skyPreetham.glsl"
#else
#include "/lib/skyVanilla.glsl"
#endif

#ifdef CLOUDS_2D
#include "/lib/clouds2D.glsl"
#endif=

void main() {
	float depthFull   = texture(depthtex0, texcoord).r;
	float depthOpaque = texture(depthtex1, texcoord).r;

	bool isTranslucent = depthFull < depthOpaque;
	
	if(isTranslucent) {
		if (depthFull == 1.0) return;
		
		mat3 gMVI = mat3(gbufferModelViewInverse);
		vec2 lightmap = texture(colortex1, texcoord).rg;
		vec3 encodedNormal = texture(colortex2, texcoord).rgb;
		vec3 normal = normalize((encodedNormal - 0.5) * 2.0);
		vec3 lightVector = normalize(shadowLightPosition);
		vec3 worldLightVector = gMVI * lightVector;
		
		// reconstruct view space position
		vec3 NDCPos = vec3(texcoord.xy, depthFull) * 2.0 - 1.0;
		vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);
		vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
		vec3 worldPos = feetPlayerPos + cameraPosition;
		
		// water animations
		vec2 waterWaves = 0.3 * (
			  texture(colortex7, worldPos.xz * 0.08 + frameTimeCounter * 0.05).rg * 0.6 +
			  texture(colortex7, worldPos.xz * 0.2  + frameTimeCounter * 0.1 ).rg  * 0.4 +
			  (texture(colortex7, worldPos.xz * 0.02 + windOffset).rg - 0.5) * 0.15
			  - 0.5);
		
		#ifdef WATER_REFRACTIONS
		// refraction logic (depends on data from water gbuffer)
		if(texture(colortex1, texcoord).b > 0.4) {
			color = texture(colortex0, texcoord + waterWaves * 0.05);
			viewPos.xz += waterWaves;
		} else {
			color = texture(colortex0, texcoord);
			color.rgb = pow(color.rgb, vec3(2.2));
		}
		#else
		color = texture(colortex0, texcoord);
		color.rgb = pow(color.rgb, vec3(2.2));
		#endif
		
		// lighting
		vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
		vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);
		
		vec3 blocklight = lightmap.r * lightmap.r * blocklightColor * (1.0 - 0.7 * dayFactor);
		vec3 skylight = lightmap.g * mix(skylightNightColor, skylightColor, dayFactor);
		vec3 shadow = getPCSSShadow(shadowClipPos);
		vec3 sunlight = clamp(dot(worldLightVector, normal), 0.0, 1.0) * lightmap.g * shadow * (1.0 - 0.8 * rainStrength);

		vec3 light = blocklight + skylight + ambientColor + mix(moonlightColor, sunColor, dayFactor) * sunlight;	
		color.rgb *= light;

		#ifdef WATER_REFLECTIONS
		vec3 viewDir = normalize(viewPos);
		vec3 waterNormalView = normalize(mat3(gbufferModelView) * normal);
		vec3 reflectionDir = reflect(viewDir, waterNormalView);
		
		// Schlick's fresnel
		float fresnel = 0.02 + 0.98 * pow(1.0 - max(dot(-viewDir, waterNormalView), 0.0), 2.0);
		
		vec3 reflectionColor = vec3(0.0);
		vec3 skyReflection = vec3(0.0);
		float ssrWeight = 0.0;

		// if fresnel is extremely low, SSR won't be visible anyway. skip it!
		if (fresnel > 0.01) {
			float noise = interleavedGradientNoise(gl_FragCoord.xy);
				
			vec3 hit = rayTrace(viewPos, reflectionDir, noise);

			if(hit.z > 0.5) {
				reflectionColor = texture(colortex0, hit.xy).rgb;
				// fade out at edges to prevent "popping"
				vec2 edgeFade = smoothstep(vec2(0.0), vec2(0.15), hit.xy) * smoothstep(vec2(1.0), vec2(0.85), hit.xy);
				ssrWeight = edgeFade.x * edgeFade.y;
			} else {
				#ifdef PREETHAM_SKY
				skyReflection = calcSkyColorPreetham(reflectionDir) + (calcSunDisc(reflectionDir) * sunColor);
				#else
				skyReflection = calcSkyColor(reflect(viewDir, waterNormalView)) * 1.5;
				#endif

				#ifdef CLOUDS_2D
				vec3 cloudPos = normalize(gMVI * reflectionDir);
				vec4 clouds = renderClouds(cloudPos, false);
				skyReflection = mix(skyReflection, clouds.rgb, clouds.a);
				#endif
			}
		}

		color.rgb = mix(color.rgb, mix(pow(skyReflection, vec3(2.2)), reflectionColor, ssrWeight), fresnel);
		#endif

	} else {
		color = texture(colortex0, texcoord);
	}
}

