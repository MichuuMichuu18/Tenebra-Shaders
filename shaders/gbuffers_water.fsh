#version 330 compatibility

uniform sampler2D lightmap;
uniform sampler2D gtexture;

uniform int renderStage;
uniform float viewHeight;
uniform float viewWidth;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 fogColor;
uniform vec3 skyColor;
uniform vec3 sunPosition;
uniform float eyeAltitude;
uniform float rainStrength;
uniform sampler2D noisetex;
uniform float frameTimeCounter;
uniform sampler2D colortex7;
uniform float sunAngle;
uniform float far;

uniform float alphaTestRef = 0.1;

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec4 normal;

/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 lightmapData;
layout(location = 2) out vec4 encodedNormal;

#include "/lib/util.glsl"

#define PREETHAM_SKY
#define 2D_CLOUDS

#define FOG_DENSITY 0.3

#ifdef PREETHAM_SKY
#include "/lib/skyPreetham.glsl"
#include "/lib/lighting.glsl"
#else
#include "/lib/skyVanilla.glsl"
#endif

#ifdef 2D_CLOUDS
#include "/lib/clouds2D.glsl"
#endif

void main() {
	color = texture(gtexture, texcoord) * glcolor;
	//color *= texture(lightmap, lmcoord);
	
	if (color.a < alphaTestRef) {
		discard;
	}
	
	lightmapData = vec4(lmcoord, 0.0, 1.0);
	encodedNormal = vec4(normal.rgb * 0.5 + 0.5, 1.0);
	
	if(normal.a == 1.0) {
			color = vec4(0.1, 0.45, 0.6, 0.3);
			lightmapData.xy *= 0.5;
			lightmapData.z = 1.0;
	}
}
