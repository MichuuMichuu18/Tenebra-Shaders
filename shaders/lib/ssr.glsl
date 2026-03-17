#ifndef SSR_GLSL
#define SSR_GLSL

const float thickness = 0.5; 

vec3 rayTrace(vec3 viewPos, vec3 viewDir, float dither) {
    // setup step vector
    vec3 rayStep = viewDir * SSR_STEP_SIZE;
    // apply jitter
    vec3 currentPos = viewPos + rayStep * dither; 

    for(int i = 0; i < SSR_MAX_STEPS; i++) {
        vec4 projectedPos = gbufferProjection * vec4(currentPos, 1.0);
        projectedPos.xyz /= projectedPos.w;
        projectedPos.xyz = projectedPos.xyz * 0.5 + 0.5;
        
        // if the ray leaves the screen, break
        if(any(greaterThan(projectedPos.xy, vec2(1.0))) || any(lessThan(projectedPos.xy, vec2(0.0)))) break;
        
        float sceneDepth = texture(depthtex1, projectedPos.xy).r;
        if (sceneDepth >= 1.0) {
            currentPos += rayStep;
            rayStep *= (1.0 + SSR_STEP_EXPANSION);
            continue; 
        }

        float rayDepth = projectedPos.z;

        float currentThickness = (thickness * 0.001) + (length(rayStep) * 0.05);

        if(rayDepth > sceneDepth && rayDepth < sceneDepth + currentThickness) {
            
            // binary search
            #if SSR_SHARPENER_STEPS > 0
            vec3 lowStep = currentPos - rayStep;
            vec3 highStep = currentPos;

            for(int j = 0; j < SSR_SHARPENER_STEPS; j++) {
                vec3 midStep = mix(lowStep, highStep, 0.5);
                vec4 pMid = gbufferProjection * vec4(midStep, 1.0);
                pMid.xyz /= pMid.w;
                pMid.xyz = pMid.xyz * 0.5 + 0.5;
                
                // checking if the midpoint is still "behind" the scene
                if(pMid.z > texture(depthtex1, pMid.xy).r) {
                    highStep = midStep;
                } else {
                    lowStep = midStep;
                }
            }
            
            // return the refined uv and hit depth
            vec4 finalProj = gbufferProjection * vec4(lowStep, 1.0);
            return vec3((finalProj.xyz / finalProj.w) * 0.5 + 0.5);
            #else
            return vec3(projectedPos.xy, 1.0);
            #endif
        }

        // advance ray
        currentPos += rayStep;
        rayStep *= (1.0 + SSR_STEP_EXPANSION);
    }
    
    return vec3(0.0); // missed everything
}

#endif
