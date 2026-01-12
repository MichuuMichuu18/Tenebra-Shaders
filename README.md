# Tenebra Shaders
A new Minecraft shaderpack focused on mood, simplicity, and restraint.

Designed for **Minecraft 1.17+**. Always tested on the latest version with Iris — backward compatibility (including OptiFine) is not a priority.

This project emphasizes **clarity and intention**, rather than stacking effects “just because”.

## Features
- Realistic shadow rendering  
  (transparency handling, variable penumbra filtering, etc.)
- Custom sky

## Planned
- 2D Clouds
- Bloom  
  (minimal, toned down compared to my previous project)
- Reflections
- Post-processing  
  (TAA + sharpening, DOF, motion blur)
- Multiple performance profiles  
  (Low / Medium / High)
- Volumetric light / god rays

## Known issues
- Shadow filtering darkens sun/moon light  
  *(this may haunt me forever)*
- Translucent objects can be brigter in some scenarios
- PCSS shadows are costly when faraway geometry (e.g., mountains) casts shadow

