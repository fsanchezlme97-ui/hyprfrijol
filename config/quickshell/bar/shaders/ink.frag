// Tinta de la barra adaptable (barAdaptive, bar/Bar.qml): pinta el contenido de un solo color (ink) y la cantidad de
// tinta de cada píxel sale de lo claro que es (lo oscuro si el tema es claro: invert = 1). Así los iconos de color
// (bandeja, apps) quedan como un grabado y no como manchas, y el número del espacio activo se lee recortado en su
// píldora. Compilado (se sube el .qsb, no hace falta qsb para instalar):
//   /usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o ink.frag.qsb ink.frag
#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 ink;
    float invert;
};
layout(binding = 1) uniform sampler2D source;
void main() {
    vec4 c = texture(source, qt_TexCoord0);
    vec3 rgb = c.a > 0.0 ? c.rgb / c.a : vec3(0.0);
    float l = dot(rgb, vec3(0.299, 0.587, 0.114));
    l = mix(l, 1.0 - l, invert);
    float k = c.a * smoothstep(0.1, 0.8, l);
    fragColor = vec4(ink.rgb * k, k) * qt_Opacity;
}
