# VRChat Scene Probe

Purpose is to expose scene information (location, depth, lighting) from a running vrchat instance by way of a shader/material that draws the info to encoded pixels on the desktop window. The info is primarily for use in "AR over VR" overlays that need to draw 3d objects with scene lighting and occlusion (from depth), as well as fix objects in the (virtual) world even as the user moves around (with joystick or IRL). Such an overlay could of course estimate the lighting/movement from the 2d view itself (like real AR), but if we can get it directly it'll make that side easier.

Main reference is the ShaderMotion project which draws bone positions to the desktop window. I think we can largely use the same technique for location and lighting (write out light probe SH coeffiecients). The depth map I'm less sure of how to get and transfer; likely we'll just have a reduced resolution version which should be fine for AR.
