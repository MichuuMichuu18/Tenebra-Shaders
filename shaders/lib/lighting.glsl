#ifndef LIGHTING_GLSL
#define LIGHTING_GLSL

// maybe not the best name for that file but eh

const float sunPathRotation = -35.0;

#define DAY_CURVE 0.333 // higher value gives us more smooth day/night transition (up to 1.0) and can make daytime and nighttime overlap too much

const vec3 blocklightColor = vec3(1.0, 0.55, 0.2)*1.3;
const vec3 skylightColor = vec3(0.25, 0.3, 0.35);
const vec3 skylightNightColor = vec3(0.04, 0.07, 0.09);
const vec3 sunlightColor = vec3(1.0, 0.95, 0.9)*1.2;
const vec3 moonlightColor = vec3(0.09, 0.16, 0.24);
const vec3 ambientColor = vec3(0.01, 0.02, 0.05);

float getDayFactor() {
	float angle = sunAngle * 2.0 * 3.14159265;

	// day factor: 1 at daytime, 0 at night
	return clamp(pow(max(0.0, sin(angle)), DAY_CURVE), 0.0, 1.0);
}

vec3 calcSunColor(float dayFactor) {
    // dayFactor: 0 = night, 1 = sun high
    vec3 daySun    = vec3(1.0, 0.97, 0.9);  // midday sun
    vec3 gold      = vec3(1.1, 0.85, 0.4);
    vec3 tangerine = vec3(1.2, 0.35, 0.2);
    vec3 red       = vec3(0.8, 0.1, 0.1);

    float horizon = 1.0 - clamp(dayFactor, 0.0, 1.0);

    // Smooth curve for gold → tangerine → red
    float goldPhase = smoothstep(0.2, 0.5, horizon);
    float tangerinePhase = smoothstep(0.3, 0.7, horizon);
    float redPhase = smoothstep(0.6, 1.0, horizon);

    vec3 sunsetColor = daySun * (1.0 - goldPhase)
                     + gold * (goldPhase - tangerinePhase)
                     + tangerine * (tangerinePhase - redPhase)
                     + red * redPhase;

    return sunsetColor;
}


#endif
