#version 330 compatibility

uniform sampler2D colortex0;

uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

#define FXAA
// FXAA pixel span, 8.0 - sharp but sometimes not smooth enough, 16.0 - smooth but sometimes not sharp enough
#define FXAA_SPAN_MAX	     12.0
#define FXAA_EDGE_THRESHOLD  0.031
#define FXAA_MIN_LUMA	     0.005

// you probably don't want to touch these
#define FXAA_REDUCE_MUL	 (1.0 / 8.0)
#define FXAA_REDUCE_MIN	 (1.0 / 128.0)

#include "/lib/util.glsl"

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	color = texture(colortex0, texcoord);
	
	#ifdef FXAA
	float lumaM  = luminance(color.rgb);

	// early skip if pixel too dark
	if(lumaM > FXAA_MIN_LUMA) {
		vec2 texel = vec2(1.0 / viewWidth, 1.0 / viewHeight);

		// fetch neighbors once
		vec3 rgbNW = texture(colortex0, texcoord + vec2(-texel.x,  texel.y)).rgb;
		vec3 rgbNE = texture(colortex0, texcoord + vec2( texel.x,  texel.y)).rgb;
		vec3 rgbSW = texture(colortex0, texcoord + vec2(-texel.x, -texel.y)).rgb;
		vec3 rgbSE = texture(colortex0, texcoord + vec2( texel.x, -texel.y)).rgb;

		float lumaNW = luminance(rgbNW);
		float lumaNE = luminance(rgbNE);
		float lumaSW = luminance(rgbSW);
		float lumaSE = luminance(rgbSE);

		// precompute min/max
		float lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
		float lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));
		float lumaRange = lumaMax - lumaMin;

		// skip FXAA if no strong edge
		if(lumaRange > FXAA_EDGE_THRESHOLD) {
			vec2 dir = vec2(-(lumaNW + lumaNE - lumaSW - lumaSE),
			                  lumaNW + lumaSW - lumaNE - lumaSE); // compute blur direction

			float lumaSum = lumaNW + lumaNE + lumaSW + lumaSE;
			float rcpDirMin = 1.0 / (min(abs(dir.x), abs(dir.y)) + max(lumaSum * (0.25 * FXAA_REDUCE_MUL), FXAA_REDUCE_MIN));
			dir = clamp(dir * rcpDirMin, -FXAA_SPAN_MAX, FXAA_SPAN_MAX) * texel;

			float fxaaStrength = mix(0.4, 0.6, saturate(lumaRange * 4.0));
			dir *= fxaaStrength;

			// fetch weighted samples for blur
			vec2 o1 = dir * -0.1666; // (1.0/3.0 - 0.5)
			vec2 o2 = dir * 0.1666; // (2.0/3.0 - 0.5)
			vec2 o3 = dir * -0.5;
			vec2 o4 = dir * 0.5;

			vec3 rgbA = 0.5 * (texture(colortex0, texcoord + o1).rgb + texture(colortex0, texcoord + o2).rgb);
			vec3 rgbB = rgbA * 0.5 + 0.25 * (texture(colortex0, texcoord + o3).rgb + texture(colortex0, texcoord + o4).rgb);

			// final luminance check
			float lumaB = 0.299*rgbB.r + 0.587*rgbB.g + 0.114*rgbB.b;
			color.rgb = (lumaB < lumaMin || lumaB > lumaMax) ? rgbA : rgbB;
		}
	}
	#endif
}
