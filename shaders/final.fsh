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

void main() {
	color = texture(colortex0, texcoord);
	// convert colors to logarithmic scale cuz we ended our work and we want to display in sRGB (gamma correction)
	color.rgb = pow(color.rgb, vec3(1.0 / 2.2));
	//color.rgb = uncharted2_filmic(color.rgb); // it's giving me nostalgia feelings
	//color.rgb = pow(color.rgb, vec3(2.2)); // convert colors to linear scale cuz we work with lighting
	//float grayscale = dot(color.rgb, vec3(1.0/3.0));
	//color.rgb = vec3(grayscale);
}
