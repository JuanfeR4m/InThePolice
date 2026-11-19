extends CanvasLayer


signal reintentar
signal ir_al_menu

const AZUL_NOCHE := Color("1B2240")
const AMARILLO := Color("F2B632")
const VERDE := Color("5FB88B")
const ROJO := Color("D63A3A")

const ESPERA_BOTONES := 1.2

var gano := false
var motivo := ""
var salvados := -1
var total_administrativos := 10
var tiempo_usado := 0.0
var mejor_tiempo := 0.0

var boton_reintentar: Button
var boton_menu: Button
var botones_activos := false


func configurar(datos: Dictionary) -> void:
	gano = datos.get("gano", false)
	motivo = datos.get("motivo", "")
	salvados = datos.get("salvados", -1)
	total_administrativos = datos.get("total_administrativos", 10)
	tiempo_usado = datos.get("tiempo_usado", 0.0)
	mejor_tiempo = datos.get("mejor_tiempo", 0.0)


static func estrellas_por_salvados(n: int) -> int:
	if n >= 9:
		return 3
	if n >= 7:
		return 2
	if n >= 5:
		return 1
	return 0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir()
	await get_tree().create_timer(ESPERA_BOTONES, true).timeout
	botones_activos = true
	boton_reintentar.disabled = false
	boton_menu.disabled = false
	boton_reintentar.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if botones_activos and event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_R:
		reintentar.emit()


func _construir() -> void:
	var color_titulo := VERDE if gano else ROJO

	var velo := ColorRect.new()
	velo.color = Color(0.0, 0.0, 0.0, 0.65)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(velo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	var panel := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = AZUL_NOCHE
	estilo.border_color = color_titulo
	estilo.set_border_width_all(4)
	estilo.set_corner_radius_all(14)
	estilo.content_margin_left = 40
	estilo.content_margin_right = 40
	estilo.content_margin_top = 30
	estilo.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", estilo)
	centro.add_child(panel)

	var caja := VBoxContainer.new()
	caja.custom_minimum_size = Vector2(520, 0)
	caja.add_theme_constant_override("separation", 14)
	panel.add_child(caja)

	caja.add_child(_etiqueta("¡VICTORIA!" if gano else "DERROTA", 56, color_titulo))
	if motivo != "":
		var m := _etiqueta(motivo, 22, Color.WHITE)
		m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caja.add_child(m)

	caja.add_child(HSeparator.new())

	if salvados >= 0:
		caja.add_child(_etiqueta("Administrativos salvados: %d de %d" % [salvados, total_administrativos], 22, AMARILLO))
		if gano:
			caja.add_child(_etiqueta("Estrellas: %d de 3" % estrellas_por_salvados(salvados), 22, AMARILLO))
	caja.add_child(_etiqueta("Tiempo: " + _formato_tiempo(tiempo_usado), 20, Color.WHITE))
	if gano and mejor_tiempo > 0.0:
		caja.add_child(_etiqueta("Mejor tiempo: " + _formato_tiempo(mejor_tiempo), 20, Color.WHITE))

	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 20)
	caja.add_child(fila)

	boton_reintentar = _boton("Jugar de nuevo (R)")
	boton_reintentar.pressed.connect(func(): reintentar.emit())
	fila.add_child(boton_reintentar)
	boton_menu = _boton("Menú principal")
	boton_menu.pressed.connect(func(): ir_al_menu.emit())
	fila.add_child(boton_menu)


func _etiqueta(texto: String, tamano: int, color: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamano)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _boton(texto: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.disabled = true
	b.custom_minimum_size = Vector2(230, 52)
	b.add_theme_font_size_override("font_size", 22)
	return b


static func _formato_tiempo(segundos: float) -> String:
	var s := int(round(segundos))
	return "%02d:%02d" % [floori(s / 60.0), s % 60]
