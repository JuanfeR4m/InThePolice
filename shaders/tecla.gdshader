shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never;

uniform vec4 color_borde : source_color = vec4(0.106, 0.133, 0.251, 1.0);
uniform vec4 color_tecla : source_color = vec4(0.98, 0.96, 0.88, 1.0);
uniform vec4 color_apagado : source_color = vec4(0.45, 0.47, 0.56, 1.0);
uniform vec4 color_resalte : source_color = vec4(0.949, 0.714, 0.196, 1.0);
uniform bool resaltada = true;
uniform vec2 tamano = vec2(0.9, 0.9);
uniform float radio = 0.18;
uniform float grosor = 0.07;
uniform float velocidad = 8.0;

float distancia_caja(vec2 p, vec2 mitad, float r) {
	vec2 q = abs(p) - mitad + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * tamano;
	float d = distancia_caja(p, tamano * 0.5, radio);
	vec4 color = color_apagado;
	if (resaltada) {
		float pulso = 0.5 + 0.5 * sin(TIME * velocidad);
		color = mix(color_tecla, color_resalte, pulso);
	}
	if (d > -grosor) {
		color = color_borde;
	}
	ALBEDO = color.rgb;
	ALPHA = 1.0 - smoothstep(-0.01, 0.01, d);
}
