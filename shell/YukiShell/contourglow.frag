#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec2 mouse;
    float pad;
    float cornerR;
    float amount;
    float spread;
    vec4 tint;
};

float sdRoundRect(vec2 p, vec2 halfSize, float r)
{
    vec2 q = abs(p) - halfSize + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main()
{
    vec2 p = qt_TexCoord0 * itemSize;
    vec2 c = itemSize * 0.5;
    float d = sdRoundRect(p - c, c - pad, cornerR);

    float inside = 1.0 - smoothstep(-0.3, 0.6, d);
    float line = exp(-max(-d, 0.0) / 1.0) * inside;
    float halo = exp(min(d, 0.0) / 5.0) * 0.14 * inside;

    float near = exp(-length(p - (mouse + pad)) / spread);
    float a = (line * 0.95 + halo) * mix(0.18, 1.0, near) * amount;

    fragColor = vec4(tint.rgb * a, a) * qt_Opacity;
}
