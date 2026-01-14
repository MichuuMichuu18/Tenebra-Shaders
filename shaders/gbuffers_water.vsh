#version 330 compatibility

in vec2 mc_Entity;

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec4 normal;

uniform mat4 gbufferModelViewInverse;

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmcoord = lmcoord / (30.0 / 32.0) - (1.0 / 32.0);
	glcolor = gl_Color;
	normal.rgb = gl_NormalMatrix * gl_Normal; // this gives us the normal in view space
	normal.rgb = mat3(gbufferModelViewInverse) * normal.rgb; // this converts the normal to world/player space
	
	float block = 0.0;
	if(mc_Entity.x == 8.0 || mc_Entity.x == 9.0) block = 1.0;
    if(mc_Entity.x == 79.0) block = 0.5;
    if (mc_Entity.x == 10002) block = 0.1;
    normal.a = block;
}
