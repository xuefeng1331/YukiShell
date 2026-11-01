#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    vec2 itemSize;
    vec2 cardSize;
    float pad;
    float seed;
};

layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) { return fract(sin(dot(p + seed * 13.1, vec2(127.1, 311.7))) * 43758.5453); }

const float CELL = 2.5;

float life(float x, float h)
{
    float start = (x / cardSize.x) * 0.55 + h * 0.25;
    return clamp((progress * 1.45 - start) / 0.55, 0.0, 1.0);
}
vec2 drift(float h, float t)
{
    vec2 dir = normalize(vec2(1.0, -0.35 - h * 0.9));
    return dir * pad * (0.45 + 0.55 * h) * t * t;
}

void main()
{
    vec2 q = qt_TexCoord0 * itemSize - vec2(0.0, pad);

    vec2 src = q;
    float t = 0.0, h = 0.0;
    for (int i = 0; i < 3; i++) {
        vec2 c = floor(src / CELL);
        h = hash(c);
        t = life(src.x, h);
        src = q - drift(h, t);
    }
    if (src.x < 0.0 || src.y < 0.0 || src.x > cardSize.x || src.y > cardSize.y) { fragColor = vec4(0.0); return; }

    vec4 col = texture(source, src / cardSize);
    float keep = t <= 0.0 ? 1.0 : step(h * 0.85, 1.0 - t) * (1.0 - t);
    fragColor = col * keep * qt_Opacity;
}
