#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float seed;
    float amount;
    float aspect;
};
layout(binding = 1) uniform sampler2D source;

void main()
{
    vec2 uv = qt_TexCoord0;
    vec2 p = vec2(uv.x * aspect, uv.y) * 3.0;
    float s = seed * 40.0;
    vec2 d = vec2(0.0);
    float f = 1.0, a = 1.0;
    for (int i = 0; i < 4; i++) {
        vec2 q = p * f + d * 1.5 + vec2(s * 1.7 + float(i) * 3.1, s * 2.3 - float(i) * 1.9);
        d += a * vec2(sin(q.y * 1.3 + q.x * 0.7), cos(q.x * 1.1 - q.y * 0.9));
        f *= 1.85;
        a *= 0.55;
    }
    vec2 uv2 = uv + d * amount * vec2(1.0 / aspect, 1.0);
    uv2 = 1.0 - abs(1.0 - mod(uv2, 2.0));
    vec4 c = texture(source, uv2);
    float crest = smoothstep(0.9, 2.2, length(d));
    c.rgb += c.a * crest * 0.06;
    fragColor = c * qt_Opacity;
}
