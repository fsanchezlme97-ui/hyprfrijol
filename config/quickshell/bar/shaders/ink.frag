// Tinta de la barra adaptable (barAdaptive, bar/Bar.qml), en una sola pasada:
//  · Color de la tinta por píxel: blanco sobre fondo de pantalla oscuro y negro sobre claro, mirando el propio fondo
//    (wallA/wallB, recortado como en la pantalla) justo debajo de ese punto; con un degradado suave donde el fondo
//    pasa de claro a oscuro. wallMix funde el fondo viejo con el nuevo mientras cambia (como el fundido del fondo).
//  · Cantidad de tinta: lo claro que es cada píxel del contenido (lo oscuro con el tema claro: invert = 1), así los
//    iconos de color quedan como un grabado y el número del espacio activo se lee recortado en su píldora.
//  · Sombra suave del color contrario (8 muestras alrededor, un píxel hacia abajo) para leerse sobre cualquier fondo.
//  · keep: rectángulo que conserva sus colores (los iconos de la bandeja).
//  · amount: 0 = colores normales, 1 = tinta (la transición al activar o quitar el ajuste).
// Compilado (se sube el .qsb, no hace falta qsb para instalar):
//   /usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o ink.frag.qsb ink.frag
#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 area;        // la barra en la pantalla: x, y, ancho, alto (0-1)
    vec4 crop;        // escala u, v del recorte del fondo (centrado, como PreserveAspectCrop)
    vec4 keep;        // x0, y0, x1, y1 (0-1 de la barra) sin tinta
    vec4 texel;       // tamaño de un píxel del contenido (1/ancho, 1/alto); textureSize no existe en GLSL ES 100
    float amount;
    float invert;
    float wallMix;
    float threshold;
};
layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D wallA;
layout(binding = 3) uniform sampler2D wallB;

float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// Cantidad de tinta de un punto del contenido
float inkAt(vec2 uv) {
    vec4 t = texture(source, uv);
    vec3 rgb = t.a > 0.0 ? t.rgb / t.a : vec3(0.0);
    float l = luma(rgb);
    l = mix(l, 1.0 - l, invert);
    return t.a * smoothstep(0.08, 0.72, l);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 c = texture(source, uv);

    vec2 s = area.xy + uv * area.zw;
    vec2 w = 0.5 + (s - 0.5) * crop.xy;
    float lw = mix(luma(texture(wallA, w).rgb), luma(texture(wallB, w).rgb), wallMix);
    // franja estrecha: o blanca o negra (un gris intermedio se lee mal); el degradado lo pone la distancia, no el tono
    float dark = smoothstep(threshold - 0.035, threshold + 0.035, lw);   // 0 = tinta blanca · 1 = negra
    vec3 ink = vec3(1.0 - dark);

    float k = inkAt(uv);
    vec2 px = texel.xy;
    vec2 o = uv - vec2(0.0, px.y);                 // la sombra cae un píxel hacia abajo
    float sh = 0.0;
    sh += inkAt(o + vec2( 1.5,  0.0) * px);
    sh += inkAt(o + vec2(-1.5,  0.0) * px);
    sh += inkAt(o + vec2( 0.0,  1.5) * px);
    sh += inkAt(o + vec2( 0.0, -1.5) * px);
    sh += inkAt(o + vec2( 1.1,  1.1) * px);
    sh += inkAt(o + vec2(-1.1,  1.1) * px);
    sh += inkAt(o + vec2( 1.1, -1.1) * px);
    sh += inkAt(o + vec2(-1.1, -1.1) * px);
    // más sombra donde la tinta duda entre blanco y negro
    float sa = sh / 8.0 * (mix(0.5, 0.35, dark) + 0.25 * (1.0 - abs(dark * 2.0 - 1.0)));
    vec4 inked = vec4(ink * k, k) + vec4(vec3(dark) * sa, sa) * (1.0 - k);

    float inKeep = step(keep.x, uv.x) * step(uv.x, keep.z) * step(keep.y, uv.y) * step(uv.y, keep.w);
    inked = mix(inked, c, inKeep);
    fragColor = mix(c, inked, amount) * qt_Opacity;
}
