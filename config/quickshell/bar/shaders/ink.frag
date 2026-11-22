// Vidrio esmerilado de la barra con Transparencia (bar/Bar.qml; antes «Barra adaptable»), en una sola pasada:
//  · Color de la tinta, uno solo para toda la barra: blanco sobre fondo de pantalla oscuro y negro sobre claro, según
//    la luz media del fondo (wallA/wallB, recortado como en la pantalla) bajo la barra entera (una rejilla de 16 × 2
//    muestras; mezclar blanco y negro en la misma barra se veía desigual). wallMix funde el fondo viejo con el nuevo
//    mientras cambia (como el fundido del fondo).
//  · Cantidad de tinta: lo claro que es cada píxel del contenido (lo oscuro con el tema claro: invert = 1), así los
//    iconos de color quedan como un grabado y el número del espacio activo se lee recortado en su píldora.
//  · Sombra suave del color contrario (8 muestras alrededor, un píxel hacia abajo) para leerse sobre cualquier fondo.
//  · Vidrio (glass = 1, como la barra de macOS): un velo del color contrario a la tinta (oscuro bajo tinta blanca, claro
//    bajo tinta negra) con la forma de la barra o de cada píldora (shape0-3, esquinas de radius px), que Hyprland
//    desenfoca (su alfa pasa el ignore_alpha de la capa), y un filo de luz de 1 px si flota (rim). Con vidrio la
//    sombra se aligera: el velo ya separa la tinta del fondo.
//  · keep: rectángulo que conserva sus colores (los iconos de la bandeja), sobre el velo.
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
    vec4 shape0;      // formas del velo: x0, y0, x1, y1 (0-1 de la barra); vacía si x1 <= x0
    vec4 shape1;
    vec4 shape2;
    vec4 shape3;
    float radius;     // esquinas del velo, en px del contenido
    float glass;      // 0 = sin fondo · 1 = vidrio
    float rim;        // 1 = filo de luz (barra flotante)
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

// Distancia con signo (px) a un rectángulo de esquinas redondeadas; muy lejos si la forma está vacía
float boxDist(vec2 p, vec4 r, vec2 size) {
    if (r.z <= r.x) return 1e4;
    vec2 a = r.xy * size, b = r.zw * size;
    vec2 c = (a + b) * 0.5, h = (b - a) * 0.5;
    float rr = min(radius, min(h.x, h.y));
    vec2 q = abs(p - c) - h + rr;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rr;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 c = texture(source, uv);

    float lw = 0.0;
    for (int i = 0; i < 16; i++) {
        for (int j = 0; j < 2; j++) {
            vec2 s = area.xy + vec2((float(i) + 0.5) / 16.0, (float(j) + 0.5) / 2.0) * area.zw;
            vec2 w = 0.5 + (s - 0.5) * crop.xy;
            lw += mix(luma(texture(wallA, w).rgb), luma(texture(wallB, w).rgb), wallMix);
        }
    }
    lw /= 32.0;
    // franja estrecha: o blanca o negra (un gris intermedio se lee mal)
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
    // más sombra si la luz media queda cerca del umbral
    float sa = sh / 8.0 * (mix(0.5, 0.35, dark) + 0.25 * (1.0 - abs(dark * 2.0 - 1.0))) * mix(1.0, 0.45, glass);

    // Velo: la unión de las formas, con 1 px de suavizado en el borde
    vec2 size = 1.0 / texel.xy;
    vec2 p = uv * size;
    float d = min(min(boxDist(p, shape0, size), boxDist(p, shape1, size)), min(boxDist(p, shape2, size), boxDist(p, shape3, size)));
    float cover = clamp(0.5 - d, 0.0, 1.0) * glass;
    float va = cover * mix(0.26, 0.34, dark);                       // más denso el claro: sobre fondo claro se lee peor
    vec4 base = vec4(vec3(dark) * va, va);
    float ra = cover * rim * (1.0 - smoothstep(0.0, 1.2, -d)) * mix(0.16, 0.38, dark);
    base = vec4(vec3(ra), ra) + base * (1.0 - ra);                  // filo de luz por dentro del borde
    base = vec4(vec3(dark) * sa, sa) + base * (1.0 - sa);
    vec4 inked = vec4(ink * k, k) + base * (1.0 - k);

    float inKeep = step(keep.x, uv.x) * step(uv.x, keep.z) * step(keep.y, uv.y) * step(uv.y, keep.w);
    inked = mix(inked, c + base * (1.0 - c.a), inKeep);
    fragColor = mix(c, inked, amount) * qt_Opacity;
}
