#version 330 compatibility

/*

composite5.fsh

Applying motion blur

*/

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
#define MOTIONBLUR_MAX_SAMPLES 8

#include "/lib/util.glsl"

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	color = texture(colortex0, texcoord);
	
	#ifdef MOTIONBLUR
	float depth = texture(depthtex1, texcoord).r; // use depth without translucent blocks
	
	vec3 viewPos = screenToView(vec3(texcoord, depth));
	vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;

	vec3 worldOffset = cameraPosition - previousCameraPosition;
	vec3 prevFeetPlayerPos = feetPlayerPos + worldOffset;

	mat4 prevViewProj = gbufferPreviousProjection * gbufferPreviousModelView;
	vec3 prevNDC = projectAndDivide(prevViewProj, prevFeetPlayerPos);

	vec2 currentNDC = texcoord * 2.0 - 1.0;
	vec2 velocity = (currentNDC - prevNDC.xy);

	// only run if there is significant motion to save performance
	if (length(velocity) > 0.0001) {
		// hand Mask: 0.56 is the typical Minecraft hand depth threshold. 
		// we multiply velocity by a factor to reduce intensity on the hand.
		float handMask = (depth < 0.56) ? 0.1 : 1.0; 
		// apply strength and hand mask
		velocity *= 0.5 * handMask;
		velocity = clamp(velocity, vec2(-0.05), vec2(0.05)); // clamp velocity to avoid glitches on fast turns
		
		float dithering = interleavedGradientNoise(gl_FragCoord.xy);
		
		vec3 blurColor = color.rgb; 
		int samples = 1; 

		// move the division and scaling out of the loop
		float invMaxSamples = 1.0 / float(MOTIONBLUR_MAX_SAMPLES);
		vec2 velocityStep = velocity * invMaxSamples;
		
		// starting position adjusted by dithering
		vec2 startOffset = texcoord + velocityStep * (dithering - 0.5);

		for (int i = 1; i < MOTIONBLUR_MAX_SAMPLES; ++i) {
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
