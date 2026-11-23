# Transparent clouds and shadows

Made by Torr-penn (torr-penn) - www.torr-penn.bzh

Source: https://opengameart.org/content/transparent-clouds-and-shadows
License: Creative Commons Attribution 4.0 International (CC BY 4.0)
https://creativecommons.org/licenses/by/4.0/

The original author downloads original_shadow_0.png, original_shadow_3.png,
and original_shadow_5.png are preserved byte-for-byte in originals/.
Those three ground shadows are joined in Room 1 by original_cloud_0.png and original_cloud_3.png. Both cloud PNGs are original author downloads preserved byte-for-byte. The game scales and blends them at runtime.

Changes: The shadow-mask PNGs retain the original dimensions and alpha values.
Their RGB channels are replaced throughout with a single dark color (#0F1412).
The Room 1 scene applies uniform scaling, opacity, and motion at runtime.
