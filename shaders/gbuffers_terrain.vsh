#version 330 compatibility

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec3 normal;

in vec2 mc_Entity;

uniform sampler2D colortex7;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform float rainStrength;

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmcoord = lmcoord / (30.0 / 32.0) - (1.0 / 32.0);
	glcolor = gl_Color;
	normal = gl_NormalMatrix * gl_Normal; // this gives us the normal in view space
	normal = mat3(gbufferModelViewInverse) * normal; // this converts the normal to world/player space
	
	if(mc_Entity.x == 10003){
		vec3 vertexPosView = (gl_ModelViewMatrix * gl_Vertex).xyz;
		vec3 vertexPosPlayer = mat3(gbufferModelViewInverse) * vertexPosView;
		vec3 worldPos = vertexPosPlayer + cameraPosition;
		
		vec2 windDir = normalize(vec2(1.0, 0.4));
		float windSpeed = 0.03;
		vec2 uv = worldPos.xz*0.2 + windDir * frameTimeCounter * windSpeed;
		vec3 noiseSample = texture(colortex7, uv).rgb;

		vec3 noiseValue = noiseSample - 0.5;
		float amplitude = 0.2 - 0.1*rainStrength;

		worldPos += noiseValue * amplitude;
	
		vertexPosPlayer = worldPos - cameraPosition;
		vertexPosView = mat3(gbufferModelView) * vertexPosPlayer;
		gl_Position = gl_ProjectionMatrix * vec4(vertexPosView, 1.0);
	}
}
