#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D depthtex1;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

in vec2 texcoord;

#define MOTIONBLUR

/*
const int colortex0Format = RGB16;
*/

#include "/lib/util.glsl"

vec3 uncharted2_tonemap_partial(vec3 x)
{
	float A = 0.15f;
	float B = 0.50f;
	float C = 0.10f;
	float D = 0.20f;
	float E = 0.02f;
	float F = 0.30f;
	return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

vec3 uncharted2_filmic(vec3 v)
{
	float exposure_bias = 8.0f; // original value was 2.0
	vec3 curr = uncharted2_tonemap_partial(v * exposure_bias);

	vec3 W = vec3(11.2f);
	vec3 white_scale = vec3(1.0f) / uncharted2_tonemap_partial(W);
	return curr * white_scale;
}

vec3 tonemapLottes(vec3 x) {
	const float a = 1.6;
	const float d = 0.977;
	const float hdrMax = 8.0;
	const float midIn = 0.18;
	const float midOut = 0.267;

	float b = (-pow(midIn, a) + pow(hdrMax, a) * midOut) /
			  ((pow(hdrMax, a) - pow(midIn, a)) * midOut);
	float c = (pow(hdrMax, a) * pow(midIn, a) - pow(hdrMax, a) * midOut * pow(midIn, a)) /
			  ((pow(hdrMax, a) - pow(midIn, a)) * midOut);

	return pow(x, vec3(a)) / (pow(x, vec3(a)) + vec3(b)) + c;
}

vec3 tonemapACES(vec3 x) {
	const float a = 2.51;
	const float b = 0.03;
	const float c = 2.43;
	const float d = 0.59;
	const float e = 0.14;

	return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

vec3 tonemapSoft(vec3 x) {
	x = max(vec3(0.0), x);
	return x * (1.0 + x / 2.0) / (1.0 + x);
}

vec3 tonemapFilmic(vec3 x) {
	return x / (1.0 + x);
}

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	color = texture(colortex0, texcoord);
	
	#ifdef MOTIONBLUR
	float depth = texture(depthtex1, texcoord).r; // use depth without translucent blocks
	
	// calculate current fragment position in view space
	vec4 currentPosition = vec4(texcoord * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
	vec4 worldPosition = gbufferProjectionInverse * currentPosition;
	worldPosition = gbufferModelViewInverse * worldPosition;
	worldPosition /= worldPosition.w;
	worldPosition.xyz += cameraPosition;

	// calculate previous fragment position in clip space
	vec4 previousPosition = vec4(worldPosition.xyz - previousCameraPosition, 1.0);
	previousPosition = gbufferPreviousModelView * previousPosition;
	previousPosition = gbufferPreviousProjection * previousPosition;
	previousPosition /= previousPosition.w;

	// Compute screen-space velocity
	vec2 velocity = (currentPosition.xy - previousPosition.xy);

	// hand Mask: 0.56 is the typical Minecraft hand depth threshold. 
	// we multiply velocity by a factor to reduce intensity on the hand.
	float handMask = (depth < 0.56) ? 0.1 : 1.0; 
	// apply strength and hand mask
	velocity *= 0.5 * handMask;
	velocity = clamp(velocity, vec2(-0.05), vec2(0.05)); // clamp velocity to avoid glitches on fast turns

	// only run if there is significant motion to save performance
	if (length(velocity) > 0.0001) {
		float dithering = interleavedGradientNoise(gl_FragCoord.xy);
		
		vec3 blurColor = color.rgb; 
		int samples = 1; 
		int maxSamples = 8;

		// move the division and scaling out of the loop
		float invMaxSamples = 1.0 / float(maxSamples);
		vec2 velocityStep = velocity * invMaxSamples;
		
		// This is the starting position adjusted by dithering
		vec2 startOffset = texcoord + velocityStep * (dithering - 0.5);

		for (int i = 1; i < maxSamples; ++i) {
			// Now it's just a multiply-add (MAD), which GPUs are extremely fast at
			vec2 sampleCoords = startOffset + (velocityStep * float(i));

			// Bounds check
			if (all(greaterThan(sampleCoords, vec2(0.0))) && all(lessThan(sampleCoords, vec2(1.0)))) {
				blurColor += texture(colortex0, sampleCoords).rgb;
				samples++;
			}
		}
		color.rgb = blurColor / float(samples);
	}

	#endif
	
	// convert colors to logarithmic scale cuz we ended our work and we want to display in sRGB (gamma correction)
	//color.rgb = pow(color.rgb, vec3(1.0 / 2.2));
	color.rgb = tonemapFilmic(color.rgb*5.0);
}
