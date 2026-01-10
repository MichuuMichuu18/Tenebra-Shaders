#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform mat4 gbufferProjectionInverse;

// player's render distance, in blocks
uniform float far;

uniform vec3 fogColor;

in vec2 texcoord;

#include "/lib/util.glsl"

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

#define FOG_DENSITY 5.0

void main() {
	color = texture(colortex0, texcoord);

	float depthFull   = texture(depthtex0, texcoord).r;
	float depthOpaque = texture(depthtex1, texcoord).r;

	bool isTranslucent = depthFull < depthOpaque - 0.00001;
	
	if(isTranslucent) {
		//color.r = 0.0;
	}
}
