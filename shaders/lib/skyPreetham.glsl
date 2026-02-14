#ifndef SKYPREETHAM_GLSL
#define SKYPREETHAM_GLSL

float calcSunDisc(vec3 viewDir) {
    viewDir = normalize(viewDir);
    vec3 sunDir = normalize(sunPosition);

    float d = dot(viewDir, sunDir);

    // Disc + soft halo
    float disc = smoothstep(0.9993, 1.0, d);
    float softdisc = smoothstep(0.9988, 1.0, d);
    float halo = smoothstep(0.996 - rainStrength * 0.2, 1.0, d);
    float halo2 = smoothstep(0.993 - rainStrength * 0.2, 1.0, d);

    float sun =
	disc * 2.0 * (1.0 - rainStrength) +
	softdisc * 0.05 +
        halo * 0.01 +
        halo2 * 0.005;

    return sun;
}

vec3 calcFogColor(vec3 viewDir, vec3 sunDir) {
    vec3 up = normalize(gbufferModelView[1].xyz);
    float viewUp = saturate(dot(viewDir, up));
    float sunHeight = dot(sunDir, up); // raw, can be negative at night

    vec3 dayFog = vec3(0.6, 0.8, 1.0)*0.8;

    // Sunset/sunrise factor
    // Only when sun is low, i.e., sunHeight near horizon
    float sunLow = smoothstep(0.0, 0.25, 0.25 - sunHeight); // 0 when high, 1 near horizon
    vec3 sunsetFog = vec3(1.0, 0.35, 0.2); // warm tangerine

    // Horizon blend: stronger near horizon
    float horizonBlend = pow(1.0 - viewUp, 1.5);

    // Combine day + sunset depending on sunLow
    vec3 fog = mix(dayFog, sunsetFog, sunLow * horizonBlend);

    // Night contribution (slightly cyan)
    float night = smoothstep(0.0, -0.25, sunHeight);
    vec3 nightFog = vec3(0.052, 0.091, 0.117);
    fog = mix(fog, nightFog, night);

    return fog;
}

vec3 calcSkyColorPreetham(vec3 viewDir) {
    viewDir = normalize(viewDir);

    vec3 up = normalize(gbufferModelView[1].xyz);
    vec3 sunDir = normalize(sunPosition);

    float viewUp = saturate(dot(viewDir, up));
    float sunUp  = dot(sunDir, up);
    float sunView = dot(viewDir, sunDir);

    // Base colors
    vec3 zenithColor  = skyColor * 0.6;
    vec3 horizonColor = calcFogColor(viewDir, sunDir);

    // Vertical gradient
    float horizonFactor = pow(1.0 - viewUp, 1.5);
    vec3 sky = mix(zenithColor, horizonColor, horizonFactor);

    // Sun scattering lobe (NOT the disc)
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

    vec3 nightZenith  = vec3(0.05, 0.07, 0.09);
    vec3 nightHorizon = vec3(0.01, 0.045, 0.06);

    vec3 nightSky = mix(nightHorizon, nightZenith, pow(viewUp, 0.85));
    sky = mix(sky, nightSky * 2.0, night);

    // Rain desaturation
    sky = mix(
        sky,
        vec3(dot(sky, vec3(0.299, 0.587, 0.114))),
        rainStrength * 0.6
    );

    // Absolute floor
    sky = max(sky, vec3(0.03));

    return sky*2.5;
}

#endif
