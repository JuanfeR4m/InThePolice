extends CanvasLayer
## HUD de la partida: cara + barra de ira, administrativos, mensajes y ambiente de bordes.
## El reloj va aparte (cronometro_hud.tscn, ya está en "capacronometro" de nivel_1).
##
## Qué lee:
##   - Juego (grupo "juego"): fase (0 día, 1 noche, 2 amanecer), administrativos, mensaje
##   - La ira real llega por poner_ira(), que ya llama Partida cuando cambia la ira
##     del GeneradorIncidentes. Para probar con las teclas I/K del Juego, activa
##     "usar_ira_de_juego".

signal ira_llena

const RUTA_FUENTE := "res://assets/fuentes/LilitaOne-Regular.woff2"
const RUTA_CARA := "res://assets/hub/cara_ira_spritesheet.png"
const RUTA_SHADER := "res://shaders/hud_ambiente.gdshader"

# Hoja de la cara: 9 cuadros de 249x128
#   0 sonrisa · 1 risa · 2 alivio (destellos) · 3 neutral · 4 ceño
#   5 vapor · 6 dientes · 7 vena · 8 furia (rojo)
const CUADROS_CARA := 9
const CARA_POR_NIVEL := [0, 3, 4, 5, 6, 7, 8]
const UMBRALES := [0.15, 0.30, 0.50, 0.65, 0.80, 0.92]
const CARA_ALIVIO := 2

@export var ira_max := 100.0
## Activa solo para probar con las teclas I/K del Juego (si no, manda Partida)
@export var usar_ira_de_juego := false
@export var tamano_cara := Vector2(150, 77)
@export var color_bajo := Color("#2ecc40")
@export var color_medio := Color("#ffdc00")
@export var color_alto := Color("#e62e2e")
@export var color_fondo := Color("#1f1f1f")
@export_group("Ambiente de bordes")
@export var ambiente_activo := true
@export_range(0.0, 1.0) var intensidad_ambiente := 1.0

# Partida los escribe (compatibilidad con Partida.sincronizar_hud)
var tiempo_total := 180.0
var tiempo := 0.0

var _fuente: Font
var _barra: ProgressBar
var _relleno: StyleBoxFlat
var _cara: TextureRect
var _atlas: AtlasTexture
var _ancho_cuadro := 249.0
var _alto_cuadro := 128.0
var _etiqueta_admins: Label
var _etiqueta_mensaje: Label
var _mat: ShaderMaterial

var _t := 0.0
var _ira := 0.0
var _ira_objetivo := 0.0
var _cuadro := -1
var _t_alivio := 0.0
var _pop_k := 1.0
var _tween_pop: Tween
var _tween_mensaje: Tween
var _ultimo_mensaje := ""
var _fase := 0
var _noche := 0.0
var _peligro := 0.0
var _ira_avisada := false


func _ready() -> void:
	add_to_group("hud")
	if ResourceLoader.exists(RUTA_FUENTE):
		_fuente = load(RUTA_FUENTE)
	_construir()


func _construir() -> void:
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)
	_construir_ambiente(raiz)
	_construir_ira(raiz)
	_construir_textos(raiz)


func _construir_ambiente(raiz: Control) -> void:
	if not ambiente_activo or not ResourceLoader.exists(RUTA_SHADER):
		return
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load(RUTA_SHADER)
	_mat.set_shader_parameter("intensidad", intensidad_ambiente)
	rect.material = _mat
	raiz.add_child(rect)


func _construir_ira(raiz: Control) -> void:
	var caja := HBoxContainer.new()
	caja.position = Vector2(16, 12)
	caja.add_theme_constant_override("separation", 6)
	raiz.add_child(caja)

	if ResourceLoader.exists(RUTA_CARA):
		var hoja: Texture2D = load(RUTA_CARA)
		_ancho_cuadro = float(hoja.get_width()) / CUADROS_CARA
		_alto_cuadro = float(hoja.get_height())
		_atlas = AtlasTexture.new()
		_atlas.atlas = hoja
		_atlas.region = Rect2(0.0, 0.0, _ancho_cuadro, _alto_cuadro)
		_cara = TextureRect.new()
		_cara.texture = _atlas
		_cara.custom_minimum_size = tamano_cara
		_cara.pivot_offset = tamano_cara / 2.0
		_cara.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_cara.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_cara.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		caja.add_child(_cara)

	_barra = ProgressBar.new()
	_barra.custom_minimum_size = Vector2(250, 30)
	_barra.max_value = ira_max
	_barra.value = 0.0
	_barra.show_percentage = false
	_barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = color_fondo
	fondo.set_corner_radius_all(8)
	fondo.set_border_width_all(4)
	fondo.border_color = Color.BLACK
	_relleno = StyleBoxFlat.new()
	_relleno.bg_color = color_bajo
	_relleno.set_corner_radius_all(6)
	_barra.add_theme_stylebox_override("background", fondo)
	_barra.add_theme_stylebox_override("fill", _relleno)
	caja.add_child(_barra)

	var rotulo := Label.new()
	rotulo.text = "IRA"
	rotulo.set_anchors_preset(Control.PRESET_FULL_RECT)
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_estilo(rotulo, 18, 5)
	_barra.add_child(rotulo)


func _construir_textos(raiz: Control) -> void:
	_etiqueta_admins = Label.new()
	_etiqueta_admins.position = Vector2(22, 96)
	_estilo(_etiqueta_admins, 22, 6)
	raiz.add_child(_etiqueta_admins)

	_etiqueta_mensaje = Label.new()
	_etiqueta_mensaje.anchor_left = 0.0
	_etiqueta_mensaje.anchor_right = 1.0
	_etiqueta_mensaje.offset_top = 130
	_etiqueta_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_estilo(_etiqueta_mensaje, 54, 12)
	_etiqueta_mensaje.add_theme_color_override("font_color", Color("#ffe27a"))
	_etiqueta_mensaje.modulate.a = 0.0
	raiz.add_child(_etiqueta_mensaje)


func _estilo(l: Label, tam: int, contorno: int) -> void:
	if _fuente != null:
		l.add_theme_font_override("font", _fuente)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_outline_color", Color("#1a1030"))
	l.add_theme_constant_override("outline_size", contorno)


func _process(delta: float) -> void:
	_t += delta
	var juego := get_tree().get_first_node_in_group("juego")
	if juego != null:
		_leer_juego(juego)
	_actualizar_ira(delta)
	_actualizar_ambiente(delta)


func _leer_juego(juego: Node) -> void:
	if usar_ira_de_juego and "ira" in juego:
		poner_ira(juego.ira)
	if "administrativos" in juego:
		_etiqueta_admins.text = "Administrativos: " + str(juego.administrativos)
	if "fase" in juego:
		_fase = int(juego.fase)
	if "mensaje" in juego and juego.mensaje != _ultimo_mensaje:
		_ultimo_mensaje = juego.mensaje
		if _ultimo_mensaje != "":
			_mostrar_mensaje(_ultimo_mensaje)


func _actualizar_ira(delta: float) -> void:
	# La barra "persigue" el valor: sube con empuje, baja con calma
	_ira = lerpf(_ira, _ira_objetivo, 1.0 - exp(-8.0 * delta))
	_barra.value = _ira
	var r := clampf(_ira / ira_max, 0.0, 1.0)
	var ro := clampf(_ira_objetivo / ira_max, 0.0, 1.0)

	# Verde -> amarillo -> rojo
	if r < 0.5:
		_relleno.bg_color = color_bajo.lerp(color_medio, r / 0.5)
	else:
		_relleno.bg_color = color_medio.lerp(color_alto, (r - 0.5) / 0.5)

	# Cara: el cuadro depende del nivel de ira (reacciona al valor real, sin suavizar)
	var nivel := 0
	for u in UMBRALES:
		if ro >= u:
			nivel += 1
	var cuadro: int = CARA_POR_NIVEL[nivel]
	if _t_alivio > 0.0:
		_t_alivio -= delta
		cuadro = CARA_ALIVIO
	if cuadro != _cuadro:
		_cuadro = cuadro
		if _atlas != null:
			_atlas.region = Rect2(cuadro * _ancho_cuadro, 0.0, _ancho_cuadro, _alto_cuadro)
		_pop(1.22)

	# Energía: respira tranquila, y desde 60% late y tiembla más rápido
	var vel := 2.0
	var amp := 0.02
	if ro >= 0.6:
		vel = lerpf(6.0, 16.0, (ro - 0.6) / 0.4)
		amp = 0.07
	if _cara != null:
		var s := (1.0 + amp * sin(_t * vel)) * _pop_k
		_cara.scale = Vector2(s, s)
		var temblor := clampf((ro - 0.8) / 0.2, 0.0, 1.0)
		_cara.rotation = deg_to_rad(sin(_t * 45.0) * 3.0 * temblor)
	# La barra parpadea más clara cuando está casi llena
	if ro >= 0.8:
		var k := 0.5 + 0.5 * sin(_t * lerpf(8.0, 16.0, (ro - 0.8) / 0.2))
		_barra.modulate = Color.WHITE.lerp(Color(1.35, 1.1, 1.1), k)
	else:
		_barra.modulate = Color.WHITE


func _actualizar_ambiente(delta: float) -> void:
	if _mat == null:
		return
	# Noche solo en la fase NOCHE; el amanecer vuelve a la vibra tranquila
	var meta := 1.0 if _fase == 1 else 0.0
	_noche = move_toward(_noche, meta, delta / 2.5)
	_peligro = lerpf(_peligro, clampf(_ira / ira_max, 0.0, 1.0), 1.0 - exp(-3.0 * delta))
	_mat.set_shader_parameter("noche", _noche)
	_mat.set_shader_parameter("peligro", _peligro)


# Rebote rápido de la cara (cuando cambia de expresión)
func _pop(factor: float) -> void:
	if _tween_pop != null and _tween_pop.is_valid():
		_tween_pop.kill()
	_pop_k = factor
	_tween_pop = create_tween()
	_tween_pop.tween_property(self, "_pop_k", 1.0, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Mensaje grande (Cae la noche / Amanece): entra con rebote, se queda y se desvanece
func _mostrar_mensaje(texto: String) -> void:
	_etiqueta_mensaje.text = texto
	_etiqueta_mensaje.pivot_offset = _etiqueta_mensaje.size / 2.0
	if _tween_mensaje != null and _tween_mensaje.is_valid():
		_tween_mensaje.kill()
	_etiqueta_mensaje.modulate.a = 1.0
	_etiqueta_mensaje.scale = Vector2(0.6, 0.6)
	_tween_mensaje = create_tween()
	_tween_mensaje.tween_property(_etiqueta_mensaje, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_mensaje.tween_interval(1.8)
	_tween_mensaje.tween_property(_etiqueta_mensaje, "modulate:a", 0.0, 0.5)


# --- Funciones que llaman las misiones / Partida ---

func aumentar_ira(cantidad: float) -> void:
	poner_ira(_ira_objetivo + cantidad)


func bajar_ira(cantidad: float) -> void:
	poner_ira(_ira_objetivo - cantidad)


func poner_ira(valor: float, _animar: bool = true) -> void:
	valor = clampf(valor, 0.0, ira_max)
	# Si la ira baja de golpe (incidente resuelto), la cara se alivia un momento
	if valor < _ira_objetivo - 2.0:
		_t_alivio = 0.9
	_ira_objetivo = valor
	if valor >= ira_max and not _ira_avisada:
		_ira_avisada = true
		ira_llena.emit()
	elif valor < ira_max:
		_ira_avisada = false
