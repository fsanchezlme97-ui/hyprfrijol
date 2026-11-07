#version 300 es
// hyprfrijol · filtro de color: escala de grises (Ajustes › Accesibilidad)
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;
void main() {
    vec4 c = texture(tex, v_texcoord);
    float y = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
    fragColor = vec4(vec3(y), c.a);
}
