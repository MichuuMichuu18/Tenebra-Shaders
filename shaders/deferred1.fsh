#version 330 compatibility

/*

deferred1.fsh

EXPERIMENTAL SSGI and SSAO implementation, idk if i'll leave it, looks nice tho

*/

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D noisetex;

uniform vec3 shadowLightPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform float viewWidth;
uniform float viewHeight;
uniform float sunAngle;
uniform float rainStrength;
uniform float frameTimeCounter;

uniform float far;
uniform float near;

in vec2 texcoord;
in float dayFactor;
in vec3 sunColor;

/* RENDERTARGETS: 6 */
layout(location = 0) out vec4 color;

#include "/lib/distort.glsl"
#include "/lib/util.glsl"
#include "/lib/shadow.glsl"
#include "/lib/lighting.glsl"

// custom SSR settings for SSGI to reduce performance impact
#define SSR_MAX_STEPS 40
#define SSR_STEP_SIZE 1.5
#define SSR_STEP_EXPANSION 0.1
#define SSR_SHARPENER_STEPS 0

#include "/lib/ssr.glsl"

// SSGI settings
#define SSGI
#define SSGI_SAMPLES 16
#define SSGI_RANGE 96.0 // damn thats a huge distance
#define SSGI_STRENGTH 1.5
#define SSGI_THICKNESS 2.0

// SSAO settings
#define SSAO
#define SSAO_SAMPLES 16
#define SSAO_RADIUS 0.5
#define SSAO_STRENGTH 1.0
#define SSAO_BIAS 0.015

// Helper to create a coordinate system from a normal
mat3 getTBN(vec3 normal) {
	vec3 tangent = normalize(cross(normal, vec3(0.0, 1.0, 0.0)));
	if (abs(normal.y) > 0.99) tangent = normalize(cross(normal, vec3(1.0, 0.0, 0.0)));
	vec3 bitangent = cross(normal, tangent);
	return mat3(tangent, bitangent, normal);
}

// Simple hemisphere sample (Cosine weighted)
vec3 getHemisphereSample(vec2 noise, int i) {
	float phi = 2.0 * 3.14159 * noise.x + float(i);
	float cosTheta = sqrt(noise.y);
	float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
	return vec3(sinTheta * cos(phi), sinTheta * sin(phi), cosTheta);
}

void main() {
	color = vec4(1.0);//texture(colortex0, texcoord);
	float depth = texture(depthtex0, texcoord).r;
	if (depth == 1.0) return; 

	vec3 normal = normalize(texture(colortex2, texcoord).rgb * 2.0 - 1.0);
	vec3 viewPos = screenToView(vec3(texcoord, depth));
	float dither = interleavedGradientNoise(gl_FragCoord.xy);
	mat3 tbn = getTBN(normal); 

	vec3 indirectLight = vec3(0.0);
	float occlusion = 0.0;

	int samples = 0;
	#if defined(SSGI) && defined(SSAO)
		samples = max(SSGI_SAMPLES, SSAO_SAMPLES);
	#elif defined(SSGI)
		samples = SSGI_SAMPLES;
	#elif defined(SSAO)
		samples = SSAO_SAMPLES;
	#endif

	for(int i = 0; i < samples; i++) {
		vec2 noise = vec2(fract(dither + float(i) * 0.15), fract(dither * 1.23 + float(i) * 0.31));
		vec3 sampleDirView = mat3(gbufferModelView) * tbn * getHemisphereSample(noise, i);

		vec3 hit = rayTrace(viewPos + normal * 0.1, sampleDirView, dither);

		if(hit.z > 0.5) {
			float hitSurfaceDepth = texture(depthtex0, hit.xy).r;
			vec3 hitSurfaceViewPos = screenToView(vec3(hit.xy, hitSurfaceDepth));
			float dist = distance(viewPos, hitSurfaceViewPos);

			float expectedZ = viewPos.z + sampleDirView.z * dist;
			if (abs(expectedZ - hitSurfaceViewPos.z) < SSGI_THICKNESS) {
				#ifdef SSGI
				if (i < SSGI_SAMPLES && dist < SSGI_RANGE) {
					float falloff = clamp(1.0 - (dist / SSGI_RANGE), 0.0, 1.0);
					indirectLight += normalize(texture(colortex0, hit.xy).rgb) * falloff * falloff;
				}
				#endif

				#ifdef SSAO
				if (i < SSAO_SAMPLES && dist < SSAO_RADIUS) {
					occlusion += smoothstep(0.0, 1.0, SSAO_RADIUS / dist);
				}
				#endif
			}
		}
	}

	#ifdef SSAO
	float ao = clamp(1.0 - (occlusion / float(SSAO_SAMPLES)) * SSAO_STRENGTH, 0.0, 1.0);
	color.rgb *= mix(1.0, ao, 0.8); // direct AO
	float aoIndirect = mix(1.0, ao, 0.4);
	#else
	float aoIndirect = 1.0;
	#endif

	#ifdef SSGI
	indirectLight = (indirectLight / float(SSGI_SAMPLES)) * SSGI_STRENGTH;
	color.rgb *= 1.0 + (min(indirectLight, vec3(5.0)) * aoIndirect);
	#endif
}
