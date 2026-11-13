extends CanvasLayer

signal iniciar

@export var titulo: String = "InThePolice"
@export var subtitulo: String = "Mantén el orden antes de que la bomba explote"
@export var controles: String = "Policía 1: W A S D   ·   Policía 2: flechas"
@export var color_fondo: Color = Color(0.05, 0.08, 0.16, 0.9)
@export var color_boton: Color = Color("#2f5fd0")
@export var color_boton_hover: Color = Color("#ffdc00")

var boton_jugar: Button


func _ready():
	layer = 10
	add_to_group("menu_inicio")

	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_construir()
	boton_jugar.grab_focus()


func _construir():
	var fondo = ColorRect.new()
	fondo.color = color_fondo
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var centro = CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	var caja = VBoxContainer.new()
	caja.add_theme_constant_override("separation", 22)
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	centro.add_child(caja)

	var t = Label.new()
	t.text = titulo
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 78)
	t.add_theme_color_override("font_color", Color("#ffdc00"))
	t.add_theme_color_override("font_outline_color", Color.BLACK)
	t.add_theme_constant_override("outline_size", 14)
	caja.add_child(t)

	var s = Label.new()
	s.text = subtitulo
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_font_size_override("font_size", 24)
	s.add_theme_color_override("font_color", Color.WHITE)
	caja.add_child(s)

	boton_jugar = _boton("JUGAR")
	boton_jugar.pressed.connect(_on_jugar)
	caja.add_child(boton_jugar)

	var salir = _boton("SALIR")
	salir.pressed.connect(func(): get_tree().quit())
	caja.add_child(salir)

	var c = Label.new()
	c.text = controles
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_theme_font_size_override("font_size", 18)
	c.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	caja.add_child(c)


func _boton(texto: String) -> Button:
	var b = Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(280, 64)
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.BLACK)
	b.add_theme_color_override("font_focus_color", Color.BLACK)
	b.add_theme_color_override("font_pressed_color", Color.BLACK)
	b.add_theme_stylebox_override("normal", _estilo(color_boton))
	b.add_theme_stylebox_override("hover", _estilo(color_boton_hover))
	b.add_theme_stylebox_override("focus", _estilo(color_boton_hover))
	b.add_theme_stylebox_override("pressed", _estilo(color_boton_hover.darkened(0.2)))
	return b


func _estilo(color: Color) -> StyleBoxFlat:
	var e = StyleBoxFlat.new()
	e.bg_color = color
	e.set_corner_radius_all(12)
	e.set_border_width_all(4)
	e.border_color = Color.BLACK
	return e


func _on_jugar():
	get_tree().paused = false
	iniciar.emit()
	queue_free()
