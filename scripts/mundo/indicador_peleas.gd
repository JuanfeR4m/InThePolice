class_name IndicadorPeleas
extends CanvasLayer
## Muestra una flecha en el borde de la pantalla por cada pelea que NO se ve en cámara,
## con la distancia (en metros) hasta el policía más cercano.
## Amarillo = pelea normal, rojo y latiendo rápido = a punto de escalar.

@export var margen_borde := 56.0
@export var radio_icono := 24.0
@export var altura_objetivo := 1.0
@export var color_normal := Color("F2B632")
@export var color_alerta := Color("D63A3A")
@export var mostrar_distancia := true

var lienzo: Control
var tiempo := 0.0


func _ready() -> void:
	layer = 5
	lienzo = Control.new()
	lienzo.set_anchors_preset(Control.PRESET_FULL_RECT)
	lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo.draw.connect(_dibujar)
	add_child(lienzo)


func _process(delta: float) -> void:
	tiempo += delta
	lienzo.queue_redraw()


func _dibujar() -> void:
	var camara := get_viewport().get_camera_3d()
	if camara == null:
		return
	var pantalla := get_viewport().get_visible_rect().size
	var centro := pantalla * 0.5
	var limite := centro - Vector2.ONE * margen_borde
	for nodo in get_tree().get_nodes_in_group("incidentes"):
		if not (nodo is Node3D) or not nodo.get("iniciado"):
			continue
		var punto: Vector3 = nodo.global_position + Vector3.UP * altura_objetivo
		var detras := camara.is_position_behind(punto)
		var dir := camara.unproject_position(punto) - centro
		if detras:
			dir = -dir
		# Si está dentro de la pantalla, ya se ve: no hace falta aviso
		if not detras and absf(dir.x) < centro.x - 8.0 and absf(dir.y) < centro.y - 8.0:
			continue
		if dir.length() < 0.001:
			dir = Vector2.UP
		var escala := minf(limite.x / maxf(absf(dir.x), 0.001), limite.y / maxf(absf(dir.y), 0.001))
		var pos := centro + dir * escala
		var urgente: bool = nodo.get("en_rojo") == true
		_dibujar_flecha(pos, dir.normalized(), urgente, distancia_jugador(punto))


func _dibujar_flecha(pos: Vector2, fwd: Vector2, urgente: bool, metros: float) -> void:
	var color := color_alerta if urgente else color_normal
	var pulso := 1.0 + 0.12 * sin(tiempo * (12.0 if urgente else 4.0))
	var r := radio_icono * pulso
	var fondo := Color(0.08, 0.08, 0.12, 0.88)

	# Círculo con signo de admiración
	lienzo.draw_circle(pos, r + 3.0, Color.BLACK)
	lienzo.draw_circle(pos, r, fondo)
	lienzo.draw_arc(pos, r, 0.0, TAU, 32, color, 3.0, true)
	var fuente := ThemeDB.fallback_font
	lienzo.draw_string(fuente, pos + Vector2(-r, 10.0), "!", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 30, color)

	# Triángulo que apunta hacia la pelea
	var lado := fwd.orthogonal()
	var base := pos + fwd * (r + 4.0)
	var triangulo := PackedVector2Array([base + fwd * 14.0, base + lado * 10.0, base - lado * 10.0])
	lienzo.draw_colored_polygon(triangulo, color)
	lienzo.draw_polyline(PackedVector2Array([triangulo[0], triangulo[1], triangulo[2], triangulo[0]]), Color.BLACK, 2.0, true)

	# Distancia, del lado del centro de la pantalla para que no se salga
	if mostrar_distancia and metros < INF:
		var texto := "%d m" % int(round(metros))
		var origen := pos - fwd * (r + 18.0) + Vector2(-40.0, 6.0)
		lienzo.draw_string_outline(fuente, origen, texto, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 18, 5, Color.BLACK)
		lienzo.draw_string(fuente, origen, texto, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 18, Color.WHITE)


func distancia_jugador(punto: Vector3) -> float:
	var mejor := INF
	for j in get_tree().get_nodes_in_group("jugador"):
		if j is Node3D:
			mejor = minf(mejor, j.global_position.distance_to(punto))
	return mejor
