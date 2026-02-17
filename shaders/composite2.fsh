#version 330 compatibility

/*

composite2.fsh

Bloom 1st pass - high resolution unfortunately

*/

uniform sampler2D colortex0;

uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

#define BLOOM

#define BLUR_RADIUS 10.0
#define BLUR_STRENGTH 0.8
#define BLOOM_CAP 20.0

#include "/lib/util.glsl"

/* RENDERTARGETS: 5 */
layout(location = 0) out vec4 color;

vec3 softLimit(vec3 x) {
    return x / (1.0 + x / BLOOM_CAP);
}

void main() {
    vec2 texel = vec2(1.0 / viewWidth, 0.0);
    vec2 uv = texcoord;

    vec3 sum = vec3(0.0);

    #ifdef BLOOM

        vec3 s;

        // Center
        s = texture(colortex0, uv).rgb;
        sum += softLimit(s) * 0.227027;

        // Near taps
        s = texture(colortex0, uv + texel * 1.0 * BLUR_RADIUS).rgb;
        sum += softLimit(s) * 0.1945946;

        s = texture(colortex0, uv - texel * 1.0 * BLUR_RADIUS).rgb;
        sum += softLimit(s) * 0.1945946;

        // Mid taps
        s = texture(colortex0, uv + texel * 1.7 * BLUR_RADIUS).rgb;
        sum += softLimit(s) * 0.1216216;

        s = texture(colortex0, uv - texel * 1.7 * BLUR_RADIUS).rgb;
        sum += softLimit(s) * 0.1216216;

        // Far taps
        s = texture(colortex0, uv + texel * 3.0 * BLUR_RADIUS).rgb;
        sum += softLimit(s) * 0.054054;

        s = texture(colortex0, uv - texel * 3.0 * BLUR_RADIUS).rgb;
        sum += softLimit(s) * 0.054054;
        
        // Ultra-far taps (very low energy)
        s = texture(colortex0, uv + texel * 5.0 * BLUR_RADIUS).rgb;
        sum += softLimit(s) * 0.020;

        s = texture(colortex0, uv - texel * 5.0 * BLUR_RADIUS).rgb;
        sum += softLimit(s) * 0.020;

        color = vec4(sum * BLUR_STRENGTH, 1.0);

    #else
        color = texture(colortex0, uv);
    #endif
}

