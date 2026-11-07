#version 300 es
// hyprfrijol · filtro de color: corrección para protanopia (daltonización) · Ajustes › Accesibilidad
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;
void main() {
    vec4 c = texture(tex, v_texcoord);
    mat3 rgb2lms = mat3(17.8824, 3.45565, 0.0299566, 43.5161, 27.1554, 0.184309, 4.11935, 3.86714, 1.46709);
    mat3 lms2rgb = mat3(0.0809444479, -0.0102485335, -0.000365296938, -0.130504409, 0.0540193266, -0.00412161469, 0.116721066, -0.113614708, 0.693511405);
    mat3 sim = transpose(mat3(0.0, 2.02344, -2.52581, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0));
    vec3 lms = rgb2lms * c.rgb;
    vec3 simRgb = lms2rgb * (sim * lms);
    vec3 err = c.rgb - simRgb;
    vec3 shift = vec3(0.0, err.r * 0.7 + err.g, err.r * 0.7 + err.b);
    fragColor = vec4(clamp(c.rgb + shift, 0.0, 1.0), c.a);
}
