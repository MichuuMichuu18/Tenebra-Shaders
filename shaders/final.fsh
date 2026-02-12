#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D colortex5;
uniform sampler2D depthtex1;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

#define SHARPENING
#define SHARPENING_STRENGTH 1.0

/*
const int colortex0Format = RGB16F;
const int colortex5Format = RGB16F;
*/

#include "/lib/util.glsl"

vec3 contrastAdaptiveSharpen(sampler2D tex, vec2 coords, float strength) {
    vec2 texel = 1.0 / vec2(viewWidth, viewHeight);
    
    vec3 a = texture(tex, coords + vec2(-texel.x, 0.0)).rgb;
    vec3 b = texture(tex, coords + vec2(0.0, -texel.y)).rgb;
    vec3 c = texture(tex, coords).rgb;
    vec3 d = texture(tex, coords + vec2(0.0,  texel.y)).rgb;
    vec3 e = texture(tex, coords + vec2( texel.x, 0.0)).rgb;

    // find min and max luminance in the neighborhood
    float minL = min(min(min(a.g, b.g), min(d.g, e.g)), c.g);
    float maxL = max(max(max(a.g, b.g), max(d.g, e.g)), c.g);

    // calculate weight, lower weight in high-contrast areas to prevent artifacts
    float weight = clamp(min(minL, 1.0 - maxL) / sqrt(maxL), 0.0, 1.0);
    float softStrength = strength * weight;

    // apply the sharpen
    return c + (c - (a + b + d + e) * 0.25) * softStrength;
}

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	color = texture(colortex0, texcoord);
	
	#ifdef SHARPENING
	color.rgb = contrastAdaptiveSharpen(colortex0, texcoord, 2.0 * SHARPENING_STRENGTH);
	#endif
}
