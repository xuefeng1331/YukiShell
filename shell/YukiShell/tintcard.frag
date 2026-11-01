#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float radius;
    vec2 center;
    float spreadR;
    float soft;
    vec4 colOld;
    vec4 colNew;
    float alpha;
};
float roundBox(vec2 q, vec2 hs, float r) { vec2 d = abs(q) - (hs - r); return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r; }
void main()
{
    vec2 p = qt_TexCoord0 * itemSize;
    float cov = clamp(0.5 - roundBox(p - itemSize * 0.5, itemSize * 0.5, radius), 0.0, 1.0);
    float t = 1.0 - smoothstep(spreadR - soft, spreadR + soft, length(p - center));
    vec3 c = mix(colOld.rgb, colNew.rgb, t);
    fragColor = vec4(c * alpha, alpha) * cov * qt_Opacity;
}
