class_name IndicadorIncidentes
extends Control
## Dibuja un marcador "!" sobre cada incidente visible y una flecha grande
## en el borde de la pantalla para los que estan fuera de la vista.

@export var color_facil := Color(1.0, 0.75, 0.1)
@export var color_dificil := Color(1.0, 0.2, 0.15)
@export var margen := 70.0
@export var altura := 2.5
@export var mostrar_distancia := true
@export var tamano_flecha := 2.0       # 1.0 = pequena, 2.0 = grande, 3.0 = enorme
@export var tamano_marcador := 1.5     # tamano del circulo con "!"
@export var tamano_texto := 22
@export var radio_llegada := 4.0     # si un jugador esta a esta distancia, se oculta

var _incidentes: Array[Node3D] = []
var _reloj_busqueda := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	if not is_inside_tree():
		return
	_reloj_busqueda -= delta
	if _reloj_busqueda <= 0.0:
		_reloj_busqueda = 0.3
		_incidentes.clear()
		var raiz := get_tree().current_scene
		if raiz != null and is_instance_valid(raiz) and not raiz.is_queued_for_deletion():
			_recolectar(raiz)
	queue_redraw()

# Busca los incidentes en la escena sin necesitar grupos
func _recolectar(nodo: Node) -> void:
	if nodo == null or not is_instance_valid(nodo) or nodo.is_queued_for_deletion():
		return
	if nodo is IncidentePresionado:
		var inc_3d := nodo as Node3D
		if inc_3d != null:
			_incidentes.append(inc_3d)
		return
	for hijo in nodo.get_children():
		_recolectar(hijo)

func _hay_jugador_cerca(incidente: Node3D) -> bool:
	if incidente == null or not is_instance_valid(incidente) or incidente.is_queued_for_deletion():
		return false
	if not is_inside_tree():
		return false
	for j in get_tree().get_nodes_in_group("jugador"):
		if j == null or not is_instance_valid(j) or j.is_queued_for_deletion():
			continue
		var jugador := j as Node3D
		if jugador == null:
			continue
		var a := Vector2(jugador.global_position.x, jugador.global_position.z)
		var b := Vector2(incidente.global_position.x, incidente.global_position.z)
		if a.distance_to(b) <= radio_llegada:
			return true
	return false

func _color_de(incidente: Node) -> Color:
	if incidente == null or not is_instance_valid(incidente) or incidente.is_queued_for_deletion():
		return color_facil
	var modo = incidente.get("modo")
	if modo != null and GeneradorIncidentes.MODOS_DIFICILES.has(modo):
		return color_dificil
	return color_facil

func _triangulo(centro: Vector2, ang: float, escala: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(24, 0).rotated(ang) * escala + centro,
		Vector2(-14, -20).rotated(ang) * escala + centro,
		Vector2(-6, 0).rotated(ang) * escala + centro,
		Vector2(-14, 20).rotated(ang) * escala + centro,
	])

func _draw() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport()
	if vp == null:
		return
	var cam := vp.get_camera_3d()
	if cam == null or not is_instance_valid(cam):
		return
	var tam := get_viewport_rect().size
	var centro := tam * 0.5
	var area := Rect2(Vector2(margen, margen), tam - Vector2(margen, margen) * 2.0)
	var reloj := Time.get_ticks_msec() / 150.0
	var pulso := 0.9 + 0.15 * sin(reloj)
	var fuente := ThemeDB.fallback_font

	for nodo in _incidentes:
		if nodo == null or not is_instance_valid(nodo) or nodo.is_queued_for_deletion():
			continue
		var n := nodo as Node3D
		if n == null:
			continue
		if _hay_jugador_cerca(n):
			continue
		var color := _color_de(n)
		var pos := n.global_position + Vector3.UP * altura
		var detras := cam.is_position_behind(pos)
		var p := cam.unproject_position(pos)
		var distancia := cam.global_position.distance_to(n.global_position)

		if not detras and area.has_point(p):
			# Incidente visible: circulo grande pulsante con "!"
			var r := 20.0 * tamano_marcador * pulso
			draw_circle(p, r + 5.0, Color.BLACK)
			draw_circle(p, r + 2.5, Color.WHITE)
			draw_circle(p, r, color)
			draw_string_outline(fuente, p + Vector2(-20, 14), "!",
				HORIZONTAL_ALIGNMENT_CENTER, 40, 42, 6, Color.BLACK)
			draw_string(fuente, p + Vector2(-20, 14), "!",
				HORIZONTAL_ALIGNMENT_CENTER, 40, 42, Color.WHITE)
		else:
			# Incidente fuera de pantalla: flecha grande en el borde
			var dir := p - centro
			if detras:
				dir = -dir
			if dir.length() < 0.001:
				dir = Vector2.UP
			dir = dir.normalized()
			var escala := minf(
				(tam.x * 0.5 - margen) / maxf(absf(dir.x), 0.001),
				(tam.y * 0.5 - margen) / maxf(absf(dir.y), 0.001))
			var borde := centro + dir * escala
			var ang := dir.angle()
			var s := tamano_flecha * pulso

			# Contorno negro, borde blanco y relleno de color
			draw_colored_polygon(_triangulo(borde, ang, s * 1.35), Color.BLACK)
			draw_colored_polygon(_triangulo(borde, ang, s * 1.18), Color.WHITE)
			draw_colored_polygon(_triangulo(borde, ang, s), color)

			if mostrar_distancia:
				var texto := str(int(distancia)) + " m"
				var pos_texto := borde - dir * (40.0 * tamano_flecha) + Vector2(-35, 8)
				draw_string_outline(fuente, pos_texto, texto,
					HORIZONTAL_ALIGNMENT_CENTER, 70, tamano_texto, 6, Color.BLACK)
				draw_string(fuente, pos_texto, texto,
					HORIZONTAL_ALIGNMENT_CENTER, 70, tamano_texto, Color.WHITE)
