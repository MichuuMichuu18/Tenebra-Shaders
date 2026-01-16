#ifndef SHADOWSETTINGS_GLSL
#define SHADOWSETTINGS_GLSL

// disable shadow filtering
//const bool shadowtex0Nearest = true;
//const bool shadowtex1Nearest = true;
//const bool shadowcolor0Nearest = true;

const int shadowMapResolution = 2048;
const float shadowDistanceRenderMul = 1.0;
const float ambientOcclusionLevel = 0.5;

// maximum samples amount to use for PCSS blurring (Vogel disc samples)
#define SHADOW_SAMPLES 16 // 64 = very soft, 32 = okay, 16 = trying to look okay

// penumbra distance and blur detection settings, can be left on low values as it is
const int BLOCKER_SAMPLES = 8;
const float BLOCKER_RADIUS = 32.0; // in shadow map texels

#define LIGHT_RADIUS 128.0
#define MAX_DISTANCE 384.0 // scale PCSS samples from SHADOW_SAMPLES down to 16.0 based on distance

#endif
