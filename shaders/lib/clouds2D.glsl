#ifndef CLOUDS2D_GLSL
#define CLOUDS2D_GLSL

#include "/lib/lighting.glsl"

vec4 renderClouds(vec3 cloudPos) {
	if (cloudPos.y <= 0.0) return vec4(0.0); // avoid rendering clouds on the lower half of the sky
	
	float playerHeight = (eyeAltitude - 60.0) / (320.0 - 60.0);
	float cloudDistance = mix(1.25, 0.5, playerHeight*playerHeight);
	vec2 cloudUV = cloudPos.xz / cloudPos.y * cloudDistance;
	cloudUV.y *= 1.7;
	cloudUV += vec2(0.03, 0.02) * frameTimeCounter;

	float shape  = texture(colortex7, cloudUV * 0.02).r;
	float mid    = texture(colortex7, cloudUV * 0.175).g;
	float detail = texture(colortex7, cloudUV * 0.3).b;
	float extra  = texture(colortex7, cloudUV * 0.5).r;
	float noise1 = texture(noisetex, cloudUV * 0.05).r;
	float noise2 = texture(noisetex, cloudUV * 0.2).r;


	float density = shape;
	density -= mid * 0.35;
	density -= detail * 0.15;
	density += extra * 0.1;
	density += noise1*0.04;
	density += noise2*0.02;
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

	float dayFactor = getDayFactor();

	vec3 cloudLight = vec3(0.9) * mix(moonlightColor+0.2, calcSunColor(dayFactor)*0.7+0.3, dayFactor);
	vec3 cloudDark  = vec3(0.85, 0.88, 0.92) * (0.5+0.5*dayFactor);
	vec3 clouds = mix(cloudDark, cloudLight, density) * (1.0-0.5*rainStrength);

	clouds = mix(clouds * 0.4, clouds, light);

	return vec4(clouds, saturate(density * fogFactor));
}

#endif
