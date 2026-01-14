#ifndef UTIL_GLSL
#define UTIL_GLSL

// Golden angle in radians
#define GOLDEN_ANGLE 2.39996323; // pi * (3 - sqrt(5))

#define EPSILON 1e-3

float luminance(vec3 color) {
    return dot(color, vec3(0.2125, 0.7153, 0.0721));
}

float saturate(float x) {
	return clamp(x, 0.0, 1.0);
}

// this function applies a projection matrix and then divides by the w component, skipping clip space.
vec3 projectAndDivide(mat4 projectionMatrix, vec3 position){
  vec4 homPos = projectionMatrix * vec4(position, 1.0);
  return homPos.xyz / homPos.w;
}

vec4 getNoise(vec2 coord){
  ivec2 screenCoord = ivec2(coord * vec2(viewWidth, viewHeight)); // exact pixel coordinate onscreen
  ivec2 noiseCoord = screenCoord % 64; // wrap to range of noiseTextureResolution
  return texelFetch(noisetex, noiseCoord, 0);
}

// Interleaved Gradient Noise (Jorge Jimenez)
float interleavedGradientNoise(vec2 pixel) {
    return fract(52.9829189 * fract(0.06711056 * pixel.x + 0.00583715 * pixel.y));
}

// Vogel disk sampling
vec2 vogelDiskSample(int i, int n, float rand) {
    float r = sqrt((float(i) + rand) / float(n));
    float theta = float(i) * GOLDEN_ANGLE;
	theta += rand;
    return r * vec2(cos(theta), sin(theta));
}

// Converts a screen-space position (with depth) into view-space coordinates.
vec3 screenToView(vec3 screenPos) {
	vec4 ndcPos = vec4(screenPos, 1.0) * 2.0 - 1.0;
	vec4 tmp = gbufferProjectionInverse * ndcPos;
	return tmp.xyz / tmp.w;
}

#endif
