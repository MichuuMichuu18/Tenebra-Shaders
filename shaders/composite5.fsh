#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D depthtex1;

uniform float viewWidth;
uniform float viewHeight;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

in vec2 texcoord;

#define MOTIONBLUR

#include "/lib/util.glsl"

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

	// compute screen-space velocity
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
		
		// starting position adjusted by dithering
		vec2 startOffset = texcoord + velocityStep * (dithering - 0.5);

		for (int i = 1; i < maxSamples; ++i) {
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
}
