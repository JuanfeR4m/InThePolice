shader_type canvas_item;
// Ambiente del HUD: solo toca los BORDES de la pantalla, el centro queda limpio.
//  - Día:   viñeta suave + sirena azul/roja muy tenue arriba (policial, calmado)
//  - Noche: viñeta oscura + brasas abajo; el fuego crece con "peligro"
//  - Alerta: pulso rojo en los bordes cuando "peligro" se acerca a 1

uniform float noche : hint_range(0.0, 1.0) = 0.0;
uniform float peligro : hint_range(0.0, 1.0) = 0.0;
uniform float intensidad : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * ruido(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

// Pone "arriba" sobre "abajo" respetando la transparencia
vec4 sobre(vec4 arriba, vec4 abajo) {
	float a = arriba.a + abajo.a * (1.0 - arriba.a);
	vec3 c = (arriba.rgb * arriba.a + abajo.rgb * abajo.a * (1.0 - arriba.a)) / max(a, 0.0001);
	return vec4(c, a);
}

void fragment() {
	vec2 uv = UV;
	float d_lado = min(uv.x, 1.0 - uv.x);
	float d_abajo = 1.0 - uv.y;
	float d = min(d_lado, min(uv.y, d_abajo));
	float vineta = 1.0 - smoothstep(0.0, 0.26, d);   // 1 en el borde, 0 hacia el centro

	// ---- DÍA: sirena azul/roja suave en las esquinas de arriba
	float pa = 0.5 + 0.5 * sin(TIME * 1.4);
	float pb = 0.5 + 0.5 * sin(TIME * 1.4 + 3.14159);
	vec3 azul = vec3(0.15, 0.42, 1.0);
	vec3 rojo = vec3(1.0, 0.18, 0.18);
	float arriba = 1.0 - smoothstep(0.0, 0.45, uv.y);
	vec3 c_sirena = azul * (1.0 - uv.x) * pa + rojo * uv.x * pb;
	float fuerza = max(max(c_sirena.r, c_sirena.g), c_sirena.b);
	float a_sirena = vineta * arriba * 0.18 * fuerza;
	vec4 dia = vec4(c_sirena / max(fuerza, 0.001), a_sirena * (1.0 - noche));
	vec4 dia_vineta = vec4(0.05, 0.1, 0.2, vineta * 0.14 * (1.0 - noche));
	dia = sobre(dia, dia_vineta);

	// ---- NOCHE: viñeta oscura
	vec4 oscuro = vec4(0.02, 0.02, 0.08, vineta * 0.38 * noche);

	// ---- FUEGO en los bordes (abajo fuerte, a los lados más bajo)
	float altura = mix(0.035, 0.2, peligro);
	float f_abajo = fbm(vec2(uv.x * 7.0, uv.y * 3.0 - TIME * 1.5));
	float llama_abajo = 1.0 - smoothstep(0.0, altura * (0.35 + f_abajo * 1.3), d_abajo);
	float f_lado = fbm(vec2(uv.y * 6.0, d_lado * 3.0 - TIME * 1.2 + 9.0));
	float llama_lado = 1.0 - smoothstep(0.0, altura * 0.55 * (0.3 + f_lado * 1.3), d_lado);
	float llama = max(llama_abajo, llama_lado * smoothstep(0.15, 0.6, peligro));
	vec3 c_fuego = mix(vec3(1.0, 0.22, 0.02), vec3(1.0, 0.72, 0.15), llama * llama);
	float a_fuego = llama * (0.12 + 0.48 * peligro) * noche;
	vec4 fuego = vec4(c_fuego, a_fuego);

	// ---- ALERTA: pulso rojo en el borde cuando la ira está casi llena
	float alerta = smoothstep(0.7, 1.0, peligro);
	float pulso = 0.5 + 0.5 * sin(TIME * (4.0 + 5.0 * alerta));
	vec4 aviso = vec4(1.0, 0.1, 0.1, vineta * alerta * (0.12 + 0.28 * pulso));

	vec4 r = sobre(aviso, sobre(fuego, sobre(oscuro, dia)));
	r.a = clamp(r.a * intensidad, 0.0, 0.7);   // tope: nunca tapa el juego
	COLOR = r;
}
