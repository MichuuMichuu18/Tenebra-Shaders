#ifndef SSR_GLSL
#define SSR_GLSL

/*

Possible settings for:	low	medium	high

maxSteps		30	60	120
stepSize		2.75	1.5	0.9
stepExpansion		1.15	1.05	1.02
binarySearchSteps	0	6	16
*/

#define SSR_MAX_STEPS 50 //[10 20 30 40 50 60 70 80 90 100 110 120 130 140 150 160 170 180 190 200 210 220]
#define SSR_STEP_SIZE 2.3 //[0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0]
#define SSR_STEP_EXPANSION 0.1 //[0.0 0.01 0.02 0.05 0.08 0.1 0.12 0.15 0.18 0.2]
#define SSR_SHARPENER_STEPS 5 //[0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20]

const float thickness = 0.5; // you probably don't want to touch that, unless you want holes in reflections in e.g. caves

vec3 rayTrace(vec3 viewPos, vec3 viewDir, float dither) {
	float currentStepSize = SSR_STEP_SIZE;
	vec3 rayStep = viewDir * SSR_STEP_SIZE;
	vec3 currentPos = viewPos + rayStep * dither; 
	vec3 lastPos = viewPos;

	for(int i = 0; i < SSR_MAX_STEPS; i++) {
		vec4 projectedPos = gbufferProjection * vec4(currentPos, 1.0);
		projectedPos.xyz /= projectedPos.w;
		projectedPos.xyz = projectedPos.xyz * 0.5 + 0.5;
		
		// skip if offscreen
		if(projectedPos.x < 0.0 || projectedPos.x > 1.0 || projectedPos.y < 0.0 || projectedPos.y > 1.0) break;
		
		// skip if sky
		float sceneDepth = texture(depthtex1, projectedPos.xy).r;
		if (sceneDepth >= 1.0) break;
		
		// dynamic thickness based on distance
		float currentThickness = thickness * (1.0 + projectedPos.z * 100.0);

		if(projectedPos.z > sceneDepth && projectedPos.z < sceneDepth + (currentThickness / far)) {
			// binary search - used for increasing sharpness of reflections
			vec3 lowStep = currentPos - rayStep;
			vec3 highStep = currentPos;
			vec3 finalStep = currentPos; // placeholder for the result

			for(int j = 0; j < SSR_SHARPENER_STEPS; j++) {
				vec3 midStep = mix(lowStep, highStep, 0.5);
				vec4 pMid = gbufferProjection * vec4(midStep, 1.0);
				pMid.xyz /= pMid.w;
				pMid.xyz = pMid.xyz * 0.5 + 0.5;
				
				if(pMid.z > texture(depthtex1, pMid.xy).r) {
					highStep = midStep; // we are still inside the object, pull back
				} else {
					lowStep = midStep;  // we are in front of the object, push forward
					finalStep = midStep; // keep track of the last "valid" position
				}
			}
			
			// re-project the FINAL refined position to get the accurate UVs
			vec4 finalProj = gbufferProjection * vec4(finalStep, 1.0);
			finalProj.xyz /= finalProj.w;
			finalProj.xyz = finalProj.xyz * 0.5 + 0.5;
			
			return vec3(finalProj.xy, 1.0);
		}
		//currentPos += rayStep;
		lastPos = currentPos;
		currentPos += rayStep * currentStepSize;
		currentStepSize *= 1.0+SSR_STEP_EXPANSION; // expand the step for the next iteration
	}
	return vec3(0.0);
}

#endif
