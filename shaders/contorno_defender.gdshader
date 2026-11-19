shader_type spatial;
// Contorno verde brillante (casco invertido): se usa como material_overlay
// en las mallas de los ciudadanos que hay que defender.
render_mode unshaded, cull_front;

uniform vec4 color_contorno : source_color = vec4(0.373, 0.929, 0.545, 1.0);
uniform float grosor = 0.018;
uniform float velocidad_pulso = 3.0;
uniform float intensidad_pulso = 0.25;

void vertex() {
	VERTEX += NORMAL * grosor;
}

void fragment() {
	float pulso = 1.0 + sin(TIME * velocidad_pulso) * intensidad_pulso;
	ALBEDO = color_contorno.rgb * pulso;
}
