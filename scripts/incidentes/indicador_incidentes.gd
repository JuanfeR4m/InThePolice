extends CanvasLayer



const COLOR_NORMAL := Color("F2B632")
const COLOR_ALERTA := Color("D63A3A")
const COLOR_BORDE := Color("1A1A1A")
const MARGEN := 56.0
const TAMANO := 22.0
const ALTURA_AVISO := 2.8

var capa: Control


func _ready() -> void:
	layer = 10
	capa = Control.new()
	capa.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.draw.connect(_dibujar)
	add_child(capa)


func _process(_delta: float) -> void:
	capa.queue_redraw()


# Posición en pantalla del aviso y si queda fuera de la zona visible
func _proyectar(camara: Camera3D, punto: Vector3, centro: Vector2, mitad: Vector2) -> Dictionary:
	var detras := camara.is_position_behind(punto)
	var pantalla := camara.unproject_position(punto)
	var dir := pantalla - centro
	if detras:
		dir = -dir
	if dir.length() < 0.001:
		dir = Vector2.UP
	var fuera := detras or absf(dir.x) > mitad.x or absf(dir.y) > mitad.y
	var pos := pantalla
	if fuera:
		var tx := mitad.x / maxf(absf(dir.x), 0.001)
		var ty := mitad.y / maxf(absf(dir.y), 0.001)
		pos = centro + dir * minf(tx, ty)
	return {"fuera": fuera, "pos": pos, "dir": dir.normalized()}


func _dibujar() -> void:
	var camara := get_viewport().get_camera_3d()
	if camara == null:
		return
	var tam := capa.size
	var centro := tam * 0.5
	var mitad := centro - Vector2(MARGEN, MARGEN)
	var fuente := ThemeDB.fallback_font
	var pulso := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
	for inc in get_tree().get_nodes_in_group("incidentes"):
		if not (inc is IncidentePresionado) or not inc.iniciado:
			continue
		var punto: Vector3 = inc.global_position + Vector3(0, ALTURA_AVISO, 0)
		var r := _proyectar(camara, punto, centro, mitad)
		if not r["fuera"]:
			continue
		var color: Color = COLOR_ALERTA if inc.en_rojo else COLOR_NORMAL
		var escala := 1.0 + (0.18 * pulso if inc.en_rojo else 0.08 * pulso)
		var pos: Vector2 = r["pos"]
		var dir: Vector2 = r["dir"]
		_dibujar_flecha(pos, dir, color, escala)
		_dibujar_aviso(pos, color, escala, fuente)
		var metros := int(round(Vector2(inc.global_position.x, inc.global_position.z).distance_to(
			Vector2(camara.global_position.x, camara.global_position.z))))
		var texto := "%d m" % metros
		var ancho := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var lado := pos - dir * (TAMANO * 1.7)
		capa.draw_string_outline(fuente, lado + Vector2(-ancho * 0.5, 5), texto,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, COLOR_BORDE)
		capa.draw_string(fuente, lado + Vector2(-ancho * 0.5, 5), texto,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


func _dibujar_aviso(pos: Vector2, color: Color, escala: float, fuente: Font) -> void:
	var s := TAMANO * escala
	var tri := PackedVector2Array([
		pos + Vector2(0, -s), pos + Vector2(s * 0.95, s * 0.75), pos + Vector2(-s * 0.95, s * 0.75)])
	capa.draw_colored_polygon(tri, color)
	var borde := tri.duplicate()
	borde.append(tri[0])
	capa.draw_polyline(borde, COLOR_BORDE, 3.0, true)
	capa.draw_string(fuente, pos + Vector2(-5, s * 0.5), "!",
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 1.1), COLOR_BORDE)


func _dibujar_flecha(pos: Vector2, dir: Vector2, color: Color, escala: float) -> void:
	var normal := Vector2(-dir.y, dir.x)
	var base := pos + dir * TAMANO * 1.15 * escala
	var punta := base + dir * 20.0
	var tri := PackedVector2Array([punta, base + normal * 11.0, base - normal * 11.0])
	capa.draw_colored_polygon(tri, color)
	var borde := tri.duplicate()
	borde.append(tri[0])
	capa.draw_polyline(borde, COLOR_BORDE, 2.5, true)
