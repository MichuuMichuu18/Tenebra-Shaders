#ifndef SKYPREETHAM_GLSL
#define SKYPREETHAM_GLSL

vec3 sunDir = normalize(sunPosition);

float calcSunDisc(vec3 viewDir) {
	viewDir = normalize(viewDir);

	float d = dot(viewDir, sunDir);
	// Disc + soft halo
	float disc = smoothstep(0.9993, 1.0, d);
	float softdisc = smoothstep(0.9988, 1.0, d);
	float halo = smoothstep(0.996, 1.0, d);
	float halo2 = smoothstep(0.993, 1.0, d);
	float sun =
		(disc * 2.0 +
		softdisc * 0.05) * (1.0 - rainStrength) +
		halo * 0.01 +
		halo2 * 0.005;

	return sun;
}

vec3 calcFogColor(vec3 viewDir, vec3 sunDir) {
	vec3 up = normalize(gbufferModelView[1].xyz);
	float viewUp = saturate(dot(viewDir, up));
	float sunHeight = dot(sunDir, up);

	vec3 dayFog = vec3(0.6, 0.85, 1.0)*0.8;
	// Sunset/sunrise factor
	float sunLow = smoothstep(0.0, 0.25, 0.25 - sunHeight);
	vec3 sunsetFog = vec3(1.0, 0.35, 0.2);

	// Horizon blend
	float horizonBlend = pow(1.0 - viewUp, 2.0);
	vec3 fog = mix(dayFog, sunsetFog, sunLow * horizonBlend);

	// Neutralize purple transition in fog color space by boosting green/yellow
	//float fogTransition = sunLow * horizonBlend;
	//float fogPurpleFix = smoothstep(0.2, 0.7, fogTransition) * smoothstep(1.0, 0.7, fogTransition);
	//fog += vec3(0.12, 0.22, -0.15) * fogPurpleFix * (1.0 - rainStrength);

	// Night contribution
	float night = smoothstep(0.0, -0.25, sunHeight);
	vec3 nightFog = vec3(0.052, 0.091, 0.117);
	fog = mix(fog, nightFog, night);

	return fog;
}

vec3 calcSkyColorPreetham(vec3 viewDir) {
	viewDir = normalize(viewDir);

	vec3 up = normalize(gbufferModelView[1].xyz);
	float viewUp = saturate(dot(viewDir, up));
	float sunUp  = dot(sunDir, up);
	float sunView = dot(viewDir, sunDir);

	// Base colors
	vec3 zenithColor  = skyColor * vec3(0.5, 0.6, 0.6);
	vec3 horizonColor = calcFogColor(viewDir, sunDir);
	// Vertical gradient
	float horizonFactor = pow(1.0 - viewUp, 2.0);
	vec3 sky = mix(zenithColor, horizonColor, horizonFactor);

	// Eliminate vertical purple mixing bands where blue sky meets sunset orange
	//float sunLow = smoothstep(0.0, 0.25, 0.25 - sunUp);
	//float skyPurpleFix = smoothstep(0.1, 0.6, horizonFactor) * smoothstep(0.9, 0.6, horizonFactor);
	//sky += vec3(0.08, 0.15, -0.18) * skyPurpleFix * sunLow * (1.0 - rainStrength);

	// Sun scattering lobe
	float sunScatter = 
	    exp(-8.0 * acos(clamp(sunView, -1.0, 1.0))) *
	    smoothstep(-0.05, 0.2, sunUp);
	vec3 sunScatterColor = vec3(1.0, 0.55, 0.25);
	sky += sunScatterColor * sunScatter * 0.25;
	// Sunset tint near horizon
	float sunset = smoothstep(0.0, 0.25, sunUp) * (1.0 - viewUp);
	vec3 sunsetColor = vec3(1.0, 0.45, 0.18);
	sky += sunsetColor * sunset * 0.2;

	// Night sky
	float night = smoothstep(0.0, -0.25, sunUp);
	vec3 nightZenith  = vec3(0.05, 0.07,  0.09);
	vec3 nightHorizon = vec3(0.01, 0.045, 0.06);
	vec3 nightSky = mix(nightHorizon, nightZenith, pow(viewUp, 0.85));
	sky = mix(sky, nightSky * 2.0, night);
	// Rain desaturation
	sky = mix(sky, vec3(dot(sky, vec3(0.299, 0.587, 0.114))), rainStrength * 0.6);

	// Absolute floor
	sky = max(sky, vec3(0.05));

	return sky*2.2;
}

#endif
