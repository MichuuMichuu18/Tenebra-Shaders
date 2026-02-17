#version 330 compatibility

/*

composite4.fsh

Applying bloom

*/

uniform sampler2D colortex0;
uniform sampler2D colortex5;

uniform float viewWidth;
uniform float viewHeight;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

in vec2 texcoord;

/*
less sky glow
float threshold = 5.0;
float knee      = 1.0;

cinematic
float threshold = 2.5;
float knee      = 2.0;
*/

#define BLOOM
#define BLOOM_THRESHOLD 2.0 //[1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5]
#define BLOOM_KNEE 1.5 //[0.5 1.0 1.5 2.0 2.5 3.0]

#include "/lib/util.glsl"

float bloomMask(float lum, float threshold, float knee) {
    float x = max(lum - threshold + knee, 0.0);
    return min(x * x / (4.0 * knee + 0.0001), 1.0);
}

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	color = texture(colortex0, texcoord);
	
	#ifdef BLOOM
	vec3 bloom = texture(colortex5, texcoord*0.25).rgb;
	// soft energy compression
	//bloom = bloom / (bloom+0.5);
	
	float luma = luminance(bloom);

	float mask = bloomMask(luma, BLOOM_THRESHOLD, BLOOM_KNEE);

	float warm = dot(normalize(bloom), normalize(vec3(1.0, 0.9, 0.7)));
	color.rgb += bloom * mask;// * mix(0.5, 0.8, warm);
	#endif
}
