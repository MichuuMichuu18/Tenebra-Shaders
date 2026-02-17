#version 330 compatibility

out vec2 texcoord;
out float dayFactor;
out vec3 sunColor;

uniform float sunAngle;

#include "/lib/lighting.glsl"

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	
	// moved these functions to vertex shader as those values dont need to be recomputed pixel by pixel
	dayFactor = getDayFactor();
	sunColor = calcSunColor(dayFactor);
}
