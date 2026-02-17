#version 330 compatibility

out vec4 glcolor;
out float dayFactor;
out vec3 sunColor;

uniform float sunAngle;

#include "/lib/lighting.glsl"

void main() {
	gl_Position = ftransform();
	glcolor = gl_Color;
	
	dayFactor = getDayFactor();
	sunColor = calcSunColor(dayFactor);
}
