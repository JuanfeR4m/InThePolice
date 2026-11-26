extends CanvasLayer
## Aviso en el borde de la pantalla para las peleas que están fuera de cámara.
## La flecha apunta hacia la pelea y muestra la distancia al policía más cercano
## y los segundos que quedan antes de que escale.

const MARGEN_LADOS := 70.0
const MARGEN_ARRIBA := 130.0 # deja libre la bomba y el reloj del HUD
const MARGEN_ABAJO := 90.0
const RADIO := 24.0
const TAMANO_LETRA := 18

var lienzo := Control.new()

func _ready() -> void:
	layer = 5 # por debajo del menú de inicio (10)
	lienzo.set_anchors_preset(Control.PRESET_FULL_RECT)
	lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo.draw.connect(_dibujar)
	add_child(lienzo)

func _process(_delta: float) -> void:
	lienzo.queue_redraw()

func _dibujar() -> void:
	var camara := get_viewport().get_camera_3d()
	if camara == null:
		return
	var pantalla := lienzo.size
	for pelea in get_tree().get_nodes_in_group("incidentes"):
		if not pelea.iniciado or pelea.is_queued_for_deletion():
			continue
		var punto: Vector3 = pelea.global_position + Vector3.UP
		var detras := camara.is_position_behind(punto)
		var en_pantalla := Vector2.ZERO
		if not detras:
			en_pantalla = camara.unproject_position(punto)
			if Rect2(Vector2.ZERO, pantalla).has_point(en_pantalla):
				continue # ya se ve: basta con la alerta que tiene encima

		var centro := pantalla * 0.5
		var direccion := en_pantalla - centro
		if detras:
			var local := camara.to_local(punto)
			direccion = Vector2(local.x, -local.y)
		if direccion.is_zero_approx():
			direccion = Vector2.DOWN
		direccion = direccion.normalized()
		_dibujar_aviso(_punto_en_borde(centro, direccion, pantalla), direccion, pelea)

# Punto donde la línea del centro hacia la pelea toca el borde con margen
func _punto_en_borde(centro: Vector2, direccion: Vector2, pantalla: Vector2) -> Vector2:
	var escala := INF
	if direccion.x > 0.0:
		escala = minf(escala, (pantalla.x - MARGEN_LADOS - centro.x) / direccion.x)
	elif direccion.x < 0.0:
		escala = minf(escala, (MARGEN_LADOS - centro.x) / direccion.x)
	if direccion.y > 0.0:
		escala = minf(escala, (pantalla.y - MARGEN_ABAJO - centro.y) / direccion.y)
	elif direccion.y < 0.0:
		escala = minf(escala, (MARGEN_ARRIBA - centro.y) / direccion.y)
	return centro + direccion * escala

func _dibujar_aviso(pos: Vector2, direccion: Vector2, pelea: IncidentePresionado) -> void:
	var color := pelea.COLOR_ALERTA if pelea.en_rojo else pelea.COLOR_NORMAL
	var borde := Color("1B2240")
	var ritmo := 14.0 if pelea.en_rojo else 6.0
	var radio := RADIO * (1.0 + 0.1 * sin(Time.get_ticks_msec() * 0.001 * ritmo))

	# flecha que apunta hacia la pelea
	var lado := direccion.orthogonal()
	var flecha := PackedVector2Array([
		pos + direccion * (radio + 22.0),
		pos + direccion * (radio + 2.0) + lado * 14.0,
		pos + direccion * (radio + 2.0) - lado * 14.0,
	])
	lienzo.draw_colored_polygon(flecha, color)
	flecha.append(flecha[0])
	lienzo.draw_polyline(flecha, borde, 3.0, true)

	# círculo con signo de admiración
	lienzo.draw_circle(pos, radio + 4.0, borde)
	lienzo.draw_circle(pos, radio, color)
	lienzo.draw_rect(Rect2(pos + Vector2(-3.5, -14.0), Vector2(7.0, 17.0)), borde)
	lienzo.draw_circle(pos + Vector2(0.0, 11.0), 4.5, borde)

	# texto debajo del círculo
	var segundos := maxi(ceili(pelea.TIEMPO_LIMITE - pelea.espera), 0)
	var texto := "PELEA · %d s" % segundos
	var metros := _distancia_policia(pelea.global_position)
	if metros >= 0.0:
		texto = "PELEA a %d m · %d s" % [roundi(metros), segundos]
	var fuente := ThemeDB.fallback_font
	var ancho := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANO_LETRA).x
	var x := clampf(pos.x - ancho * 0.5, 8.0, maxf(lienzo.size.x - ancho - 8.0, 8.0))
	var base := Vector2(x, pos.y + RADIO + 28.0)
	lienzo.draw_string_outline(fuente, base, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANO_LETRA, 6, Color.BLACK)
	lienzo.draw_string(fuente, base, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANO_LETRA, Color.WHITE)

func _distancia_policia(destino: Vector3) -> float:
	var menor := INF
	for p in get_tree().get_nodes_in_group("jugador"):
		if p is Node3D:
			menor = minf(menor, p.global_position.distance_to(destino))
	return menor if menor < INF else -1.0
