#version 330 compatibility

/*

composite7.fsh

Tonemapping

*/

uniform sampler2D colortex0;

in vec2 texcoord;

#include "/lib/util.glsl"

#define TONEMAP_EXPOSURE 1.0 // [0.2 0.4 0.6 0.8 1.0 1.2 1.5]
#define TONEMAP_MAX_WHITE 12.0 // [2.0 4.0 6.0 8.0 12.0 16.0]

vec3 tonemapFilmic(vec3 x) {
	return x / (1.0 + x);
}

// ACES Filmic Tonemapping (Fit by Krzysztof Narkowicz)
vec3 tonemapACES(vec3 x) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

// Extended Reinhard Tonemapping
vec3 tonemapExtendedReinhard(vec3 x) {
    vec3 numerator = x * (1.0 + (x / (TONEMAP_MAX_WHITE * TONEMAP_MAX_WHITE)));
    return numerator / (1.0 + x);
}

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	color = texture(colortex0, texcoord);

	color.rgb = tonemapExtendedReinhard(color.rgb * TONEMAP_EXPOSURE);
}
