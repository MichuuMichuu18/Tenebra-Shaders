#ifndef LIGHTING_GLSL
#define LIGHTING_GLSL

const float sunPathRotation = -35.0;

#define DAY_CURVE 0.33

// Energy levels
const vec3 blocklightColor      = vec3(4.0, 1.5, 0.3) * 4.0; 

const vec3 skylightColor        = vec3(0.9, 1.2, 1.6); 
const vec3 skylightNightColor   = vec3(0.01, 0.015, 0.02); 

const vec3 sunlightColor        = vec3(12.0, 11.5, 10.5); 
const vec3 moonlightColor       = vec3(0.35, 0.45, 0.5);

const vec3 ambientColor         = vec3(0.002, 0.002, 0.004);

float getDayFactor() {
    float angle = sunAngle * 2.0 * 3.14159265;
    return clamp(pow(max(0.0, sin(angle)), DAY_CURVE), 0.0, 1.0);
}

vec3 calcSunColor(float dayFactor) {
    vec3 daySun    = vec3(16.0, 15.0, 14.5);
    vec3 gold      = vec3(12.0, 6.0, 2.0);   
    vec3 tangerine = vec3(8.0, 2.0, 1.0);   
    vec3 red       = vec3(4.0, 0.5, 0.2);   

    float horizon = 1.0 - clamp(dayFactor, 0.0, 1.0);

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
