shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 color_relleno : source_color = vec4(0.949, 0.714, 0.196, 1.0);
uniform vec4 color_borde : source_color = vec4(0.106, 0.133, 0.251, 1.0);
uniform float velocidad = 4.0;
uniform float altura_salto = 0.08;
uniform float escala_pulso = 0.06;

bool en_triangulo(vec2 p) {
	float ancho = 0.46 * (p.y + 0.42) / 0.76;
	return p.y > -0.42 && p.y < 0.34 && abs(p.x) < ancho;
}

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX.y += sin(TIME * velocidad) * altura_salto;
}

void fragment() {
	float pulso = 1.0 + sin(TIME * velocidad * 2.0) * escala_pulso;
	vec2 p = (UV - vec2(0.5)) / pulso;
	vec2 centro = vec2(0.0, 0.087);
	vec2 q = (p - centro) * 1.3 + centro;
	vec4 color = vec4(0.0);
	if (en_triangulo(p)) {
		color = color_borde;
	}
	if (en_triangulo(q)) {
		color = color_relleno;
		bool palo = abs(p.x) < 0.035 && p.y > -0.12 && p.y < 0.09;
		bool punto = length(p - vec2(0.0, 0.19)) < 0.045;
		if (palo || punto) {
			color = color_borde;
		}
	}
	ALBEDO = color.rgb;
	ALPHA = color.a;
}