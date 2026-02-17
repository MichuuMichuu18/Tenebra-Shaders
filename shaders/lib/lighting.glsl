#ifndef LIGHTING_GLSL
#define LIGHTING_GLSL

// maybe not the best name for that file but eh

const float sunPathRotation = -35.0;

#define DAY_CURVE 0.4 // higher value gives us more smooth day/night transition (up to 1.0) and can make daytime and nighttime overlap too much

// Energy levels (HDR, linear space)
const vec3 blocklightColor      = vec3(4.0, 2.2, 1.0);
const vec3 skylightColor        = vec3(1.5, 2.1, 3.0);
const vec3 skylightNightColor   = vec3(0.1, 0.2, 0.3);
const vec3 sunlightColor        = vec3(18.0, 17.0, 15.0);
const vec3 moonlightColor       = vec3(0.25, 0.45, 0.6);
const vec3 ambientColor         = vec3(0.05, 0.08, 0.12);

float getDayFactor() {
	float angle = sunAngle * 2.0 * 3.14159265;

	// day factor: 1 at daytime, 0 at night
	return clamp(pow(max(0.0, sin(angle)), DAY_CURVE), 0.0, 1.0);
}

vec3 calcSunColor(float dayFactor) {
    // dayFactor: 0 = night, 1 = sun high
	vec3 daySun    = vec3(20.0, 19.0, 17.0);
	vec3 gold      = vec3(18.0, 13.0, 6.0);
	vec3 tangerine = vec3(16.0, 5.0, 3.0);
	vec3 red       = vec3(10.0, 1.5, 1.0);

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
