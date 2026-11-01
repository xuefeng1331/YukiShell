#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float fadeLeft;
    float fadeRight;
};
layout(binding = 1) uniform sampler2D source;
void main()
{
    float x = qt_TexCoord0.x;
    float a = smoothstep(0.0, max(fadeLeft, 1e-4), x) * smoothstep(0.0, max(fadeRight, 1e-4), 1.0 - x);
    fragColor = texture(source, qt_TexCoord0) * (a * qt_Opacity);
}
