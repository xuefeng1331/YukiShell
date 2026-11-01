#version 440
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    vec4 win;
    vec4 target;
};

void main()
{
    vec2 uv = qt_MultiTexCoord0;
    float p = clamp(progress, 0.0, 1.0);

    float bend = smoothstep(0.0, 0.45, p);
    float fall = smoothstep(0.25, 1.0, p);

    float rowT = clamp(fall * 1.35 - (1.0 - uv.y) * 0.35, 0.0, 1.0);
    rowT = rowT * rowT * (3.0 - 2.0 * rowT);
    float y0 = win.y + uv.y * win.w;
    float y1 = target.y + uv.y * target.w;
    float y = mix(y0, y1, rowT);

    float span = max(1.0, (target.y + target.w) - win.y);
    float k = clamp((y - win.y) / span, 0.0, 1.0);
    float squeeze = clamp(bend * smoothstep(0.0, 1.0, k) + rowT, 0.0, 1.0);
    float left = mix(win.x, target.x, squeeze);
    float right = mix(win.x + win.z, target.x + target.z, squeeze);
    float x = mix(left, right, uv.x);

    qt_TexCoord0 = uv;
    gl_Position = qt_Matrix * vec4(x, y, 0.0, 1.0);
}
