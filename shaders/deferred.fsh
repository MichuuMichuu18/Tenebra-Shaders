#version 330 compatibility

/*

deferred.fsh -> composite but before rendering anything translucent

in this program we calculate lighting which will be visible behind stained glass and water

*/

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

uniform float sunAngle;

uniform float far;

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

const vec3 blocklightColor = vec3(1.0, 0.55, 0.1);
const vec3 skylightColor = vec3(0.25, 0.3, 0.4);
const vec3 skylightNightColor = vec3(0.02, 0.05, 0.12);
const vec3 sunlightColor = vec3(1.0, 0.95, 0.9)*1.3;
const vec3 moonlightColor = vec3(0.075, 0.075, 0.18);
const vec3 ambientColor = vec3(0.01, 0.02, 0.05);

const float sunPathRotation = -35.0;

#define DAY_CURVE 0.3

#include "/lib/distort.glsl"
#include "/lib/util.glsl"
#include "/lib/shadow.glsl"

float getDayFactor() {
	float angle = sunAngle * 2.0 * 3.14159265;

	// day factor: 1 at daytime, 0 at night
	return clamp(pow(max(0.0, sin(angle)), DAY_CURVE), 0.0, 1.0);
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
	//color.rgb = feetPlayerPos;
	vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
	vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);
	
	float dayFactor = getDayFactor();
	vec3 blocklight = lightmap.r * blocklightColor;
	vec3 skylight = lightmap.g * mix(skylightNightColor, skylightColor, dayFactor);
	vec3 ambient = ambientColor;
	
	vec3 shadow = getPCSSShadow(shadowClipPos);
	vec3 sunlight = clamp(dot(worldLightVector, normal), 0.0, 1.0) * lightmap.g * shadow; // clamp dot product to not get negative sunlight (its impossible irl duh unless we discover black holes in minecraft)
	vec3 light = blocklight + skylight + ambient + mix(moonlightColor, sunlightColor, dayFactor) * sunlight;	

	color.rgb *= light;
}
