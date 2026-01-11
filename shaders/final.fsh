#version 330 compatibility

uniform sampler2D colortex0;

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

/*
const int colortex0Format = RGB16;
*/

float luminance(vec3 color) {
    return dot(color, vec3(0.2125, 0.7153, 0.0721));
}

vec3 uncharted2_tonemap_partial(vec3 x)
{
    float A = 0.15f;
    float B = 0.50f;
    float C = 0.10f;
    float D = 0.20f;
    float E = 0.02f;
    float F = 0.30f;
    return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

vec3 uncharted2_filmic(vec3 v)
{
    float exposure_bias = 8.0f; // original value was 2.0
    vec3 curr = uncharted2_tonemap_partial(v * exposure_bias);

    vec3 W = vec3(11.2f);
    vec3 white_scale = vec3(1.0f) / uncharted2_tonemap_partial(W);
    return curr * white_scale;
}

vec3 tonemapLottes(vec3 x) {
    const float a = 1.6;
    const float d = 0.977;
    const float hdrMax = 8.0;
    const float midIn = 0.18;
    const float midOut = 0.267;

    float b = (-pow(midIn, a) + pow(hdrMax, a) * midOut) /
              ((pow(hdrMax, a) - pow(midIn, a)) * midOut);
    float c = (pow(hdrMax, a) * pow(midIn, a) - pow(hdrMax, a) * midOut * pow(midIn, a)) /
              ((pow(hdrMax, a) - pow(midIn, a)) * midOut);

    return pow(x, vec3(a)) / (pow(x, vec3(a)) + vec3(b)) + c;
}

vec3 tonemapACES(vec3 x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;

    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

vec3 tonemapSoft(vec3 x) {
    x = max(vec3(0.0), x);
    return x * (1.0 + x / 2.0) / (1.0 + x);
}

vec3 tonemapFilmic(vec3 x) {
    return x / (1.0 + x);
}

void main() {
	color = texture(colortex0, texcoord);
	// convert colors to logarithmic scale cuz we ended our work and we want to display in sRGB (gamma correction)
	//color.rgb = pow(color.rgb, vec3(1.0 / 2.2));
	color.rgb = tonemapFilmic(color.rgb*4.0);
}
