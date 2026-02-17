#version 330 compatibility

/*

composite7.fsh

Tonemapping

*/

uniform sampler2D colortex0;

in vec2 texcoord;

vec3 tonemapFilmic(vec3 x) {
	return x / (1.0 + x);
}

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	color = texture(colortex0, texcoord);
	
	color.rgb = tonemapFilmic(color.rgb);
}
