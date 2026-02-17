#ifndef SHADOWSETTINGS_GLSL
#define SHADOWSETTINGS_GLSL

const bool shadowHardwareFiltering0 = true;
const bool shadowtex0Mipmap = false; // turning on mipmaps makes shadows blocky/glitchy!!!
const bool shadowtex0Nearest = false;
const bool shadowtex1Mipmap = false;
const bool shadowtex1Nearest = false;
const bool shadowcolor0Mipmap = false;
const bool shadowcolor0Nearest = false;

const int shadowMapResolution = 1024; // [512 768 1024 2048 4096]
const float shadowDistanceRenderMul = 1.0;
const float ambientOcclusionLevel = 0.5;

#define SHADOW_PCSS_FILTERING

// maximum samples amount to use for PCSS blurring (Vogel disc samples)
#define SHADOW_SAMPLES 16 // [8 16 24 32 48 64]

// penumbra distance and blur detection settings, can be left on low values as it is
const int BLOCKER_SAMPLES = 8;
const float BLOCKER_RADIUS = 32.0; // in shadow map texels

#define LIGHT_RADIUS 128.0
#define MAX_DISTANCE 384.0 // scale PCSS samples from SHADOW_SAMPLES down to 16.0 based on distance

#endif
