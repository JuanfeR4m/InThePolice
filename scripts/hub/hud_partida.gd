extends CanvasLayer

signal tiempo_agotado
signal ira_llena

@export var tiempo_total: float = 120.0
## Opcional: si lo dejas vacío, el HUD dibuja su propia bomba
@export var icono_bomba: Texture2D
@export var ira_max: float = 100.0
## Cuánta ira suma cada incidente sin resolver
@export var ira_por_incidente: float = 10.0
## Ira que sube sola por segundo (0 = no sube sola)
@export var ira_por_segundo: float = 0.0
@export var color_bajo: Color = Color("#2ecc40")    # verde
@export var color_medio: Color = Color("#ffdc00")   # amarillo
@export var color_alto: Color = Color("#e62e2e")    # rojo
@export var color_fondo: Color = Color("#1f1f1f")

var tiempo: float = 0.0
var corriendo: bool = true
var etiqueta_tiempo: Label
var barra: ProgressBar
var icono: TextureRect
var relleno: StyleBoxFlat
var _t: float = 0.0
var cronometro: Node = null
var etiqueta_admins: Label
var etiqueta_mensaje: Label
var _ultimo_mensaje: String = ""
var _t_mensaje: float = 0.0
var _ira_avisada: bool = false

const RUTAS_CRONOMETRO = [
	"res://escenas/escenario/cronometro_hud.tscn",
	"res://escenas/entorno/cronometro_hud.tscn",
	"res://cronometro.tscn",
]

const PALETA = {
	"k": Color("#160a24"), "d": Color("#461e6e"), "m": Color("#6e32a0"),
	"l": Color("#a064d2"), "g": Color("#787882"), "G": Color("#50505a"),
	"b": Color("#78461e"), "o": Color("#ff961e"), "y": Color("#ffe650"),
	"w": Color("#f5f5f5"),
}

const ARTE_BOMBA = [
	"..............yy",
	".............yoy",
	"............byo.",
	"...........bb.o.",
	"......GGGGGb....",
	".....GggggG.....",
	"....kkGggGkk....",
	"..kkkddddddkkk..",
	".kddmmmmmmmmddk.",
	".kdmmllmmmmmmdk.",
	"kdmmllmmmmmmmmdk",
	"kdmmlmmmmmmmmmdk",
	"kdmmmmmmmmmmmddk",
	"kddmmmmmmmmmmddk",
	".kddmmmmmmmmddk.",
	".kdddmmmmmmdddk.",
	"..kdddddddddddk.",
	"...kkdddddddkk..",
	".....kkkkkkk....",
	"................",
]

const ARTE_RELOJ = [
	"....kkkkkk....",
	"..kkwwwwwwkk..",
	".kwwwwwwwwwwk.",
	".kwwwwkwwwwwk.",
	"kwwwwwkwwwwwwk",
	"kwwwwwkwwwwwwk",
	"kwwwwwkkkkwwwk",
	"kwwwwwwwwwwwwk",
	"kwwwwwwwwwwwwk",
	".kwwwwwwwwwwk.",
	".kwwwwwwwwwwk.",
	"..kkwwwwwwkk..",
	"....kkkkkk....",
	"..............",
]


func _ready():
	add_to_group("hud")
	tiempo = tiempo_total
	if icono_bomba == null and ResourceLoader.exists("res://assets/hud/bomba.png"):
		icono_bomba = load("res://assets/hud/bomba.png")
	if icono_bomba == null:
		icono_bomba = _textura(ARTE_BOMBA)
	_construir()
	_actualizar_tiempo()
	_actualizar_color()


func _textura(filas: Array) -> ImageTexture:
	var h = filas.size()
	var w = filas[0].length()
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c = filas[y][x]
			img.set_pixel(x, y, PALETA[c] if PALETA.has(c) else Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


func _construir():
	var raiz = Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)

	# --- Bomba + medidor de ira (arriba a la izquierda) ---
	var caja = HBoxContainer.new()
	caja.position = Vector2(20, 16)
	caja.add_theme_constant_override("separation", 10)
	raiz.add_child(caja)

	icono = TextureRect.new()
	icono.texture = icono_bomba
	icono.custom_minimum_size = Vector2(56, 56)
	icono.pivot_offset = Vector2(28, 28)
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	caja.add_child(icono)

	barra = ProgressBar.new()
	barra.custom_minimum_size = Vector2(240, 28)
	barra.max_value = ira_max
	barra.value = 0.0
	barra.show_percentage = false
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fondo = StyleBoxFlat.new()
	fondo.bg_color = color_fondo
	fondo.set_corner_radius_all(6)
	fondo.set_border_width_all(3)
	fondo.border_color = Color.BLACK
	relleno = StyleBoxFlat.new()
	relleno.bg_color = color_bajo
	relleno.set_corner_radius_all(6)
	barra.add_theme_stylebox_override("background", fondo)
	barra.add_theme_stylebox_override("fill", relleno)
	caja.add_child(barra)

	# --- Administrativos (debajo de la barra) ---
	etiqueta_admins = Label.new()
	etiqueta_admins.position = Vector2(24, 82)
	etiqueta_admins.add_theme_font_size_override("font_size", 22)
	etiqueta_admins.add_theme_color_override("font_outline_color", Color.BLACK)
	etiqueta_admins.add_theme_constant_override("outline_size", 6)
	etiqueta_admins.text = ""
	raiz.add_child(etiqueta_admins)

	# --- Mensaje central (Cae la noche, Amanece...) ---
	etiqueta_mensaje = Label.new()
	etiqueta_mensaje.anchor_left = 0.0
	etiqueta_mensaje.anchor_right = 1.0
	etiqueta_mensaje.offset_top = 130
	etiqueta_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta_mensaje.add_theme_font_size_override("font_size", 44)
	etiqueta_mensaje.add_theme_color_override("font_outline_color", Color.BLACK)
	etiqueta_mensaje.add_theme_constant_override("outline_size", 10)
	etiqueta_mensaje.modulate.a = 0.0
	raiz.add_child(etiqueta_mensaje)

	# --- Tiempo: cronómetro animado si existe, o reloj simple si no ---
	var ruta_crono = ""
	for r in RUTAS_CRONOMETRO:
		if ResourceLoader.exists(r):
			ruta_crono = r
			break
	if ruta_crono != "":
		var anclaje = Control.new()
		anclaje.anchor_left = 1.0
		anclaje.anchor_right = 1.0
		anclaje.anchor_top = 0.0
		anclaje.anchor_bottom = 0.0
		anclaje.offset_left = -80
		anclaje.offset_right = -80
		anclaje.offset_top = 80
		anclaje.offset_bottom = 80
		anclaje.mouse_filter = Control.MOUSE_FILTER_IGNORE
		raiz.add_child(anclaje)
		cronometro = load(ruta_crono).instantiate()
		anclaje.add_child(cronometro)
		return

	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_top = 16
	panel.offset_right = -20
	var estilo = StyleBoxFlat.new()
	estilo.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	estilo.set_corner_radius_all(8)
	estilo.set_border_width_all(3)
	estilo.border_color = Color.BLACK
	estilo.content_margin_left = 12
	estilo.content_margin_right = 14
	estilo.content_margin_top = 6
	estilo.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", estilo)
	raiz.add_child(panel)

	var fila = HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	panel.add_child(fila)

	var reloj = TextureRect.new()
	reloj.texture = _textura(ARTE_RELOJ)
	reloj.custom_minimum_size = Vector2(38, 38)
	reloj.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reloj.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reloj.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	reloj.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(reloj)

	etiqueta_tiempo = Label.new()
	etiqueta_tiempo.add_theme_font_size_override("font_size", 34)
	etiqueta_tiempo.add_theme_color_override("font_outline_color", Color.BLACK)
	etiqueta_tiempo.add_theme_constant_override("outline_size", 6)
	fila.add_child(etiqueta_tiempo)


func _process(delta):
	_t += delta
	_actualizar_color()
	_animar_bomba()

	var juego = get_tree().get_first_node_in_group("juego")
	if juego != null:
		_leer_juego(juego, delta)

	if not corriendo:
		return
	if ira_por_segundo > 0.0:
		poner_ira(barra.value + ira_por_segundo * delta, false)
	if juego != null and "tiempo_restante" in juego:
		tiempo = juego.tiempo_restante
	else:
		tiempo = maxf(tiempo - delta, 0.0)
	_actualizar_tiempo()
	if tiempo <= 0.0:
		corriendo = false
		tiempo_agotado.emit()


# Toma ira, administrativos y mensajes del nodo Juego
func _leer_juego(juego: Node, delta: float):
	if "ira" in juego:
		barra.value = clampf(juego.ira, 0.0, ira_max)
		if barra.value >= ira_max and not _ira_avisada:
			_ira_avisada = true
			ira_llena.emit()
		elif barra.value < ira_max:
			_ira_avisada = false
	if "administrativos" in juego:
		etiqueta_admins.text = "Administrativos: " + str(juego.administrativos)
	if "mensaje" in juego and juego.mensaje != _ultimo_mensaje:
		_ultimo_mensaje = juego.mensaje
		etiqueta_mensaje.text = _ultimo_mensaje
		_t_mensaje = 3.0
	_t_mensaje = maxf(_t_mensaje - delta, 0.0)
	etiqueta_mensaje.modulate.a = clampf(_t_mensaje, 0.0, 1.0)


func _actualizar_tiempo():
	if cronometro != null:
		cronometro.actualizar(tiempo)
	if etiqueta_tiempo == null:
		return
	var seg = int(ceil(tiempo))
	etiqueta_tiempo.text = "%02d:%02d" % [seg / 60, seg % 60]
	if tiempo <= 10.0:
		etiqueta_tiempo.add_theme_color_override("font_color", Color("#ff4d4d"))
	else:
		etiqueta_tiempo.add_theme_color_override("font_color", Color.WHITE)


# Verde (0%) -> amarillo (50%) -> rojo (100%)
func _actualizar_color():
	var r = barra.value / ira_max
	if r < 0.5:
		relleno.bg_color = color_bajo.lerp(color_medio, r / 0.5)
	else:
		relleno.bg_color = color_medio.lerp(color_alto, (r - 0.5) / 0.5)


# La bomba late más rápido cuanta más ira hay
func _animar_bomba():
	var r = barra.value / ira_max
	if r < 0.6:
		icono.scale = Vector2.ONE
		return
	var vel = lerpf(6.0, 16.0, (r - 0.6) / 0.4)
	var s = 1.0 + 0.12 * sin(_t * vel)
	icono.scale = Vector2(s, s)


# --- Funciones que llaman las misiones ---

## Llámala cuando un incidente NO se resuelve
func incidente_sin_resolver():
	aumentar_ira(ira_por_incidente)


func aumentar_ira(cantidad: float):
	poner_ira(barra.value + cantidad)


## Llámala cuando se resuelve un incidente
func bajar_ira(cantidad: float):
	poner_ira(barra.value - cantidad)


func poner_ira(valor: float, animar: bool = true):
	valor = clampf(valor, 0.0, ira_max)
	if animar:
		var tw = create_tween()
		tw.tween_property(barra, "value", valor, 0.25)
	else:
		barra.value = valor
	if valor >= ira_max:
		ira_llena.emit()


func detener_tiempo():
	corriendo = false


func reiniciar_tiempo():
	tiempo = tiempo_total
	corriendo = true
