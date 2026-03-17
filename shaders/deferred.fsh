#version 330 compatibility

/*

deferred.fsh

Lighting and reflections

*/

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D noisetex;

uniform vec3 shadowLightPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection; // Added for raytracing
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform float viewWidth;
uniform float viewHeight;
uniform float sunAngle;
uniform float rainStrength;
uniform float frameTimeCounter; // Added for noise jittering

uniform float far;
uniform float near;

in vec2 texcoord;
in float dayFactor;
in vec3 sunColor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

#include "/lib/distort.glsl"
#include "/lib/util.glsl"
#include "/lib/shadow.glsl"
#include "/lib/lighting.glsl"

void main() {
    color = texture(colortex0, texcoord);
    color.rgb = pow(color.rgb, vec3(2.2)); 

    float depth = texture(depthtex0, texcoord).r;
    if (depth == 1.0) return; 
    
    vec2 lightmap = texture(colortex1, texcoord).rg;
    vec3 encodedNormal = texture(colortex2, texcoord).rgb;
    vec3 normal = normalize((encodedNormal - 0.5) * 2.0);
    vec3 lightVector = normalize(shadowLightPosition);
    vec3 worldLightVector = mat3(gbufferModelViewInverse) * lightVector; 
    
    vec3 NDCPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
    vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);
    vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;

    vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
    vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);
    
    vec3 blocklight = lightmap.r * lightmap.r * blocklightColor * (1.0-0.9*dayFactor);
    vec3 skylight = lightmap.g * mix(skylightNightColor, skylightColor, dayFactor);
    
    vec3 shadow = getPCSSShadow(shadowClipPos);
    vec3 sunlight = clamp(dot(worldLightVector, normal), 0.0, 1.0) * lightmap.g * shadow * (1.0-0.8*rainStrength);
    
    // Add indirectLight to the final sum
    vec3 light = blocklight + skylight + ambientColor + mix(moonlightColor, sunColor, dayFactor) * sunlight;    

    color.rgb *= light;
}
