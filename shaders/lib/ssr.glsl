#ifndef SSR_GLSL
#define SSR_GLSL

const float thickness = 0.5; 

vec3 rayTrace(vec3 viewPos, vec3 viewDir, float dither) {
    vec3 rayStep = viewDir * SSR_STEP_SIZE;
    vec3 currentPos = viewPos + rayStep * dither;

    for(int i = 0; i < SSR_MAX_STEPS; i++) {
        vec4 projectedPos;
        projectedPos.x = currentPos.x * gbufferProjection[0][0] + currentPos.z * gbufferProjection[2][0];
        projectedPos.y = currentPos.y * gbufferProjection[1][1] + currentPos.z * gbufferProjection[2][1];
        projectedPos.z = currentPos.z * gbufferProjection[2][2] + gbufferProjection[3][2];
        projectedPos.w = -currentPos.z;

        projectedPos.xyz /= projectedPos.w;
        projectedPos.xyz = projectedPos.xyz * 0.5 + 0.5;
        
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
            
            #if SSR_SHARPENER_STEPS > 0
            vec3 lowStep = currentPos - rayStep;
            vec3 highStep = currentPos;

            for(int j = 0; j < SSR_SHARPENER_STEPS; j++) {
                vec3 midStep = mix(lowStep, highStep, 0.5);
                
                // Optimized projection inside binary search
                vec4 pMid;
                pMid.x = midStep.x * gbufferProjection[0][0] + midStep.z * gbufferProjection[2][0];
                pMid.y = midStep.y * gbufferProjection[1][1] + midStep.z * gbufferProjection[2][1];
                pMid.z = midStep.z * gbufferProjection[2][2] + gbufferProjection[3][2];
                pMid.w = -midStep.z;

                pMid.xyz /= pMid.w;
                pMid.xyz = pMid.xyz * 0.5 + 0.5;
                
                if(pMid.z > texture(depthtex1, pMid.xy).r) {
                    highStep = midStep;
                } else {
                    lowStep = midStep;
                }
            }
            
            vec4 finalProj;
            finalProj.x = lowStep.x * gbufferProjection[0][0] + lowStep.z * gbufferProjection[2][0];
            finalProj.y = lowStep.y * gbufferProjection[1][1] + lowStep.z * gbufferProjection[2][1];
            finalProj.z = lowStep.z * gbufferProjection[2][2] + gbufferProjection[3][2];
            finalProj.w = -lowStep.z;

            return vec3((finalProj.xyz / finalProj.w) * 0.5 + 0.5);
            #else
            // FIX: Return actual scene depth component instead of a hardcoded 1.0
            return vec3(projectedPos.xy, projectedPos.z); 
            #endif
        }

        currentPos += rayStep;
        rayStep *= (1.0 + SSR_STEP_EXPANSION);
    }
    return vec3(0.0);
}

#endif
