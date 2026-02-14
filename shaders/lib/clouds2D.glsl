#ifndef CLOUDS2D_GLSL
#define CLOUDS2D_GLSL

#include "/lib/lighting.glsl"

vec4 renderClouds(vec3 cloudPos, bool highQuality) {
	if (cloudPos.y <= 0.0) return vec4(0.0); // avoid rendering clouds on the lower half of the sky
	
	float playerHeight = (eyeAltitude - 60.0) / (320.0 - 60.0);
	float cloudDistance = mix(1.25, 0.5, playerHeight*playerHeight);
	vec2 cloudUV = cloudPos.xz / cloudPos.y * cloudDistance;
	cloudUV.y *= 1.7;
	cloudUV += vec2(0.03, 0.02) * frameTimeCounter;

	float shape  = texture(colortex7, cloudUV * 0.02).r;
	float mid    = texture(colortex7, cloudUV * 0.175).g;
	float detail = texture(colortex7, cloudUV * 0.3).b;
	float extra  = texture(colortex7, cloudUV * 0.6).r;

	float density = shape;
	density -= mid * 0.35;
	density -= detail * 0.15;
	density += extra * 0.1;
	
	if(highQuality){ // toggleable noise, barely visible on e.g. water reflections
		float noise1 = texture(noisetex, cloudUV * 0.05).r;
		float noise2 = texture(noisetex, cloudUV * 0.2).g;
		
		density += noise1*0.035;
		density += noise2*0.015;
	}
	
	density = smoothstep(0.2-rainStrength*0.2, 0.65+rainStrength*0.3, density); // cloud coverage
	//density /= (1.0+rainStrength);
	density = pow(density, 1.3-rainStrength*0.75); // its not neccesary, but impacts clouds' actual density

	// Compute approximate 2D normal
	float dx = texture(colortex7, cloudUV * 0.02 + vec2(0.01, 0.0)).r - shape;
	float dy = texture(colortex7, cloudUV * 0.02 + vec2(0.0, 0.01)).r - shape;
	vec3 normal = normalize(vec3(-dx, 0.3, -dy));

	// Sun point light in cloud space
	vec3 sunView = normalize(mat3(gbufferModelViewInverse) * sunPosition);
	vec2 sunUV = sunView.xz / max(sunView.y * 0.5, 0.01);
	sunUV.y *= 1.7;
	sunUV += vec2(0.03, 0.02) * frameTimeCounter;

	vec2 lightVec2D = sunUV - cloudUV;
	float dist = length(lightVec2D);
	vec3 lightDir = normalize(vec3(lightVec2D.x, 0.6, lightVec2D.y));

	float lightSoftness = 0.6; // tweakable
	float NdotL = saturate(dot(normal, lightDir) + lightSoftness);
	float attenuation = exp(-dist * 0.001);
	float light = NdotL * attenuation;

	float fogFactor = exp(-FOG_DENSITY / 4.0 / max(cloudPos.y, 0.001));
	fogFactor = saturate(fogFactor);

	// Cloud material (albedo)
	vec3 cloudAlbedoLight = vec3(0.85);
	vec3 cloudAlbedoDark  = vec3(0.65);
	
	float sunTerm = light;              // directional sunlight
	vec3 skyTerm = mix(skylightNightColor*3.0, skylightColor, dayFactor);

	vec3 sunLight = mix(moonlightColor*6.0, sunColor, dayFactor) * sunTerm;
	vec3 totalLight = (sunLight + skyTerm) / 5.0;

	vec3 clouds =
	    mix(cloudAlbedoDark, cloudAlbedoLight, density)
	    * totalLight
	    * (1.0 - 0.5 * rainStrength);

	return vec4(clouds, saturate(density * fogFactor));
}

#endif
