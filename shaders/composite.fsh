#version 330 compatibility

/*

composite.fsh

in this program we calculate lighting which will be only visible on stained glass and water and reflections

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

// the position of the sun or the moon depending on daytime
uniform vec3 shadowLightPosition;
// used when converting view space to world space
uniform mat4 gbufferModelViewInverse;

// uniform needed for converting shadow pass' pixel space to shadow space
uniform mat4 gbufferProjectionInverse;
// uniform mat4 gbufferModelViewInverse; this one is already defined
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

in vec2 texcoord;
in float dayFactor;
in vec3 sunColor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

#include "/lib/distort.glsl"
#include "/lib/util.glsl"
#include "/lib/shadow.glsl"
#include "/lib/lighting.glsl"

#define WATER_REFLECTIONS
#define PREETHAM_SKY
#define CLOUDS_2D

#define FOG_DENSITY 0.3

#ifdef PREETHAM_SKY
#include "/lib/skyPreetham.glsl"
#include "/lib/lighting.glsl"
#else
#include "/lib/skyVanilla.glsl"
#endif

#ifdef CLOUDS_2D
#include "/lib/clouds2D.glsl"
#endif

void main() {
	float depthFull   = texture(depthtex0, texcoord).r;
	float depthOpaque = texture(depthtex1, texcoord).r;

	bool isTranslucent = depthFull < depthOpaque;
	
	if(isTranslucent) {
		if (depthFull == 1.0) {
			return; // skip lighting calculation if the current rendered pixel is far away according to depth (its the sky)
		}
		
		mat3 gMVI = mat3(gbufferModelViewInverse);
		
		vec2 lightmap = texture(colortex1, texcoord).rg; // we only need the r and g components
		vec3 encodedNormal = texture(colortex2, texcoord).rgb;
		vec3 normal = normalize((encodedNormal - 0.5) * 2.0); // we normalize to make sure it is of unit length, normal of ours is in world space
		vec3 lightVector = normalize(shadowLightPosition); // normalizing position (values -1.0-1.0 -> 0.0-1.0)
		vec3 worldLightVector = gMVI * lightVector;
		vec3 NDCPos = vec3(texcoord.xy, depthFull) * 2.0 - 1.0;
		vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);
		vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
		
		#ifdef WATER_REFLECTIONS
		float dist = length(viewPos) / far;
		vec3 viewDir = normalize(screenToView(
		    vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), 1.0)
		));

		// normal from gbuffer is usually in world space
		vec3 waterNormalView = normalize(
		    mat3(gbufferModelView) * normal
		);
		
		vec3 worldPos = feetPlayerPos+cameraPosition;
		
		vec2 windDir = normalize(vec2(1.0, 0.4));
		float windSpeed = 0.05;
		vec2 windOffset = windDir * frameTimeCounter * windSpeed;

		vec2 waterWaves = 0.3*(
		      texture(colortex7, worldPos.xz * 0.08 + frameTimeCounter * 0.05).rg * 0.6 +
		      texture(colortex7, worldPos.xz * 0.2  + frameTimeCounter * 0.1 ).rg  * 0.4 +
		      (texture(colortex7, worldPos.xz * 0.02 + windOffset).rg - 0.5) * 0.15
		      - 0.5);

		// refract reflections, shadows and everything visible underwater
		if(texture(colortex1, texcoord).b > 0.4) {
			color = texture(colortex0, texcoord + waterWaves*0.05);
			viewDir.xz += waterWaves*0.5;
			feetPlayerPos.xz += waterWaves;
		} else {
			color = texture(colortex0, texcoord);
			color.rgb = pow(color.rgb, vec3(2.2));
		}

		vec3 reflectionDir = reflect(viewDir, waterNormalView);
		
		//float fresnel = pow(1.0 - max(dot(viewDir, waterNormalView), 0.0), 5.0);
		// fresnel isnt really functional so i had to replace it with anything
		float fresnel = pow(1.0 - max(length(viewPos) / far, 0.0), 7.0);
		vec3 reflectionColor = vec3(0.0);

		 // sky color
		#ifdef PREETHAM_SKY
		vec3 skyCol = calcSkyColorPreetham(reflectionDir);
		vec3 sun = calcSunDisc(reflectionDir)*sunColor;
		reflectionColor = skyCol+sun;
		#else
		reflectionColor = calcSkyColor(reflectionDir)*1.5;
		#endif
		
		#ifdef CLOUDS_2D
		// Transform direction to world space
		vec3 cloudPos = normalize(gMVI * reflectionDir);
		vec4 clouds = renderClouds(cloudPos, false);
		reflectionColor = mix(reflectionColor.rgb, clouds.rgb, clouds.a);
		#endif
		
		#else 
		color = texture(colortex0, texcoord);
		color.rgb = pow(color.rgb, vec3(2.2));
		#endif
		
		vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
		vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);
		
		//float dayFactor = getDayFactor();
		vec3 blocklight = lightmap.r * lightmap.r * blocklightColor * (1.0-0.7*dayFactor);
		vec3 skylight = lightmap.g * mix(skylightNightColor, skylightColor, dayFactor);
		vec3 ambient = ambientColor;
		
		vec3 shadow = getPCSSShadow(shadowClipPos);
		vec3 sunlight = clamp(dot(worldLightVector, normal), 0.0, 1.0) * lightmap.g * shadow * (1.0-0.8*rainStrength); // clamp dot product to not get negative sunlight (its impossible irl duh unless we discover black holes in minecraft)

		vec3 light = blocklight + skylight + ambient + mix(moonlightColor, sunColor, dayFactor) * sunlight;	
		color.rgb *= light;
		//color.rgb *= light*0.5;
		//color.rgb *= 0.5+dayFactor; // increase brightness of objects visible through water and stained glass
		
		#ifdef WATER_REFLECTIONS
		color.rgb = mix(pow(reflectionColor, vec3(2.2)), color.rgb, clamp(fresnel, 0.3, 1.0));
		#endif
	} else {
		color = texture(colortex0, texcoord);
	}
}
