#ifndef SHADOWSETTINGS_GLSL
#define SHADOWSETTINGS_GLSL

const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;
const bool shadowcolor0Nearest = true;

const int shadowMapResolution = 2048;

// maximum samples amount to use for PCSS blurring (Vogel disc samples)
#define SHADOW_SAMPLES 16   // 12 = minimum, 16 = cheap, 32 = good, 64 = very soft

// penumbra distance and blur detection settings, can be left on low values as it is
const int BLOCKER_SAMPLES = 12;
const float BLOCKER_RADIUS = 16.0; // in shadow map texels

#define LIGHT_RADIUS 128.0
#define MAX_DISTANCE 128.0 // probably needs tweaking

#endif
