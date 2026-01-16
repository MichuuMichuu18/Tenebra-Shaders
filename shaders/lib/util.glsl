#ifndef UTIL_GLSL
#define UTIL_GLSL

#define GOLDEN_ANGLE 2.39996323
#define EPSILON 1e-3

float luminance(vec3 color) {
    return dot(color, vec3(0.2125, 0.7153, 0.0721));
}

float saturate(float x) {
    return clamp(x, 0.0, 1.0);
}

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position){
  vec4 homPos = projectionMatrix * vec4(position, 1.0);
  return homPos.xyz / homPos.w;
}

vec4 getNoise(vec2 coord){
  ivec2 screenCoord = ivec2(coord * vec2(viewWidth, viewHeight)); 
  return texelFetch(noisetex, screenCoord % 64, 0);
}

// Interleaved Gradient Noise (MAD Optimized)
float interleavedGradientNoise(vec2 pixel) {
    float dotResult = dot(pixel, vec2(0.06711056, 0.00583715));
    return fract(52.9829189 * fract(dotResult));
}

// Vogel disk sampling
vec2 vogelDiskSample(int i, int n, float rand) {
    float r = sqrt((float(i) + rand) / float(n));
    float theta = float(i) * GOLDEN_ANGLE + rand; 
    
    return r * vec2(cos(theta), sin(theta));
}

// Converts a screen-space position (with depth) into view-space coordinates.
vec3 screenToView(vec3 screenPos) {
    vec4 ndcPos = vec4(screenPos * 2.0 - 1.0, 1.0);
    vec4 tmp = gbufferProjectionInverse * ndcPos;
    return tmp.xyz / tmp.w;
}

#endif
