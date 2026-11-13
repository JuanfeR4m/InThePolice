shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float progreso : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color_fondo : source_color = vec4(0.106, 0.133, 0.251, 1.0);
uniform vec4 color_progreso : source_color = vec4(0.373, 0.722, 0.545, 1.0);
uniform vec4 color_centro : source_color = vec4(0.949, 0.714, 0.196, 1.0);
uniform vec4 color_flecha : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float radio_centro = 0.3;
uniform float radio_exterior = 0.45;
uniform float velocidad_flecha = 6.0;
uniform float salto_flecha = 0.04;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1.0, 2.0);
	float r = length(p);
	float giro = atan(p.x, -p.y) / TAU;
	if (giro < 0.0) {
		giro += 1.0;
	}
	vec4 color = vec4(0.0);
	if (r < radio_centro) {
		color = color_centro;
	} else if (r < radio_exterior) {
		color = color_fondo;
		if (giro < progreso) {
			color = color_progreso;
		}
	}
	float y = p.y - sin(TIME * velocidad_flecha) * salto_flecha;
	float ancho = 0.22 * (-0.52 - y) / 0.4;
	if (y > -0.92 && y < -0.52 && abs(p.x) < ancho) {
		color = color_flecha;
	}
	ALBEDO = color.rgb;
	ALPHA = color.a;
}