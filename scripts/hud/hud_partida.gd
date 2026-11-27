extends CanvasLayer
## HUD de la partida. La escena (escenas/hud/hud_partida.tscn) trae todo armado con nodos:
## posiciones, colores, tamaños y fuentes se cambian desde el Inspector, sin código.
## Este script solo anima: cara, barra de ira, sirena, administrativos y ambiente de bordes.
##
## Qué lee:
##   - Juego (grupo "juego"): fase (0 día, 1 noche, 2 amanecer), administrativos, mensaje
##   - La ira real llega por poner_ira(), que Partida ya llama cuando cambia la ira.
##     Para probar con las teclas I/K del Juego activa "usar_ira_de_juego".

signal ira_llena

# Hoja de la cara: 9 cuadros de 249x128
#   0 sonrisa · 1 risa · 2 alivio · 3 neutral · 4 ceño · 5 vapor · 6 dientes · 7 vena · 8 furia
const CUADROS_CARA := 9
const CARA_POR_NIVEL := [0, 3, 4, 5, 6, 7, 8]
const UMBRALES := [0.15, 0.30, 0.50, 0.65, 0.80, 0.92]
const CARA_ALIVIO := 2

@export var ira_max := 100.0
## Activa solo para probar con las teclas I/K del Juego (si no, manda Partida)
@export var usar_ira_de_juego := false
@export_group("Barra de ira")
@export var color_bajo := Color("#2ecc40")
@export var color_medio := Color("#ffdc00")
@export var color_alto := Color("#e62e2e")
@export var color_borde_calmado := Color("#ffdc00")
@export_group("Sirena")
@export var sirena_azul := Color("#2f6bff")
@export var sirena_roja := Color("#ff2a2a")
@export_group("Administrativos")
## Desde este número hacia abajo el contador se pone rojo y parpadea
@export var admins_en_peligro := 6
@export var color_admins := Color("#ffdc00")
@export var color_admins_peligro := Color("#ff3b3b")
@export_group("Ambiente de bordes")
@export var ambiente_activo := true
@export_range(0.0, 1.0) var intensidad_ambiente := 1.0

# Partida los escribe (compatibilidad con Partida.sincronizar_hud)
var tiempo_total := 180.0
var tiempo := 0.0

@onready var _ambiente: ColorRect = %Ambiente
@onready var _placa: PanelContainer = %PlacaIra
@onready var _cara: TextureRect = %Cara
@onready var _barra: TextureProgressBar = %Barra
@onready var _sirena: Panel = %Sirena
@onready var _admin_numero: Label = %AdminNumero
@onready var _mensaje: Label = %Mensaje

var _estilo_placa: StyleBoxFlat
var _estilo_sirena: StyleBoxFlat
var _atlas: AtlasTexture
var _mat: ShaderMaterial
var _ancho_cuadro := 249.0
var _alto_cuadro := 128.0

var _t := 0.0
var _ira := 0.0
var _ira_objetivo := 0.0
var _cuadro := -1
var _t_alivio := 0.0
var _pop_k := 1.0
var _tween_pop: Tween
var _tween_mensaje: Tween
var _tween_admin: Tween
var _ultimo_mensaje := ""
var _admins := -1
var _fase := 0
var _noche := 0.0
var _peligro := 0.0
var _ira_avisada := false


func _ready() -> void:
	add_to_group("hud")

	# Copias propias de los estilos para poder cambiarles el color en vivo
	_estilo_placa = (_placa.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	_placa.add_theme_stylebox_override("panel", _estilo_placa)
	_estilo_sirena = (_sirena.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	_sirena.add_theme_stylebox_override("panel", _estilo_sirena)

	_barra.max_value = ira_max
	_barra.value = 0.0

	_atlas = (_cara.texture as AtlasTexture).duplicate()
	_cara.texture = _atlas
	_ancho_cuadro = float(_atlas.atlas.get_width()) / CUADROS_CARA
	_alto_cuadro = float(_atlas.atlas.get_height())
	_cara.pivot_offset = _cara.custom_minimum_size / 2.0

	_mat = _ambiente.material as ShaderMaterial
	if ambiente_activo and _mat != null:
		_mat.set_shader_parameter("intensidad", intensidad_ambiente)
	else:
		_ambiente.visible = false


func _process(delta: float) -> void:
	_t += delta
	var juego := get_tree().get_first_node_in_group("juego")
	if juego != null:
		_leer_juego(juego)
	_actualizar_ira(delta)
	_actualizar_sirena()
	_actualizar_admins()
	_actualizar_ambiente(delta)


func _leer_juego(juego: Node) -> void:
	if usar_ira_de_juego and "ira" in juego:
		poner_ira(juego.ira)
	if "administrativos" in juego:
		var n := int(juego.administrativos)
		if n != _admins:
			if _admins != -1:
				_pop_admin()
			_admins = n
			_admin_numero.text = str(n)
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

	# Relleno: verde -> amarillo -> rojo
	var c := color_bajo.lerp(color_medio, r / 0.5) if r < 0.5 \
		else color_medio.lerp(color_alto, (r - 0.5) / 0.5)
	_barra.tint_progress = c

	# Borde de la placa: amarillo policial, y desde 60% vira a rojo palpitando
	var k := clampf((ro - 0.6) / 0.4, 0.0, 1.0)
	var pulso := 0.5 + 0.5 * sin(_t * lerpf(6.0, 14.0, k))
	_estilo_placa.border_color = color_borde_calmado.lerp(color_alto, k * (0.4 + 0.6 * pulso))

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
		_atlas.region = Rect2(cuadro * _ancho_cuadro, 0.0, _ancho_cuadro, _alto_cuadro)
		_pop(1.22)

	# Energía: respira tranquila, y desde 60% late y tiembla más rápido
	var vel := 2.0
	var amp := 0.02
	if ro >= 0.6:
		vel = lerpf(6.0, 16.0, (ro - 0.6) / 0.4)
		amp = 0.07
	var s := (1.0 + amp * sin(_t * vel)) * _pop_k
	_cara.scale = Vector2(s, s)
	var temblor := clampf((ro - 0.8) / 0.2, 0.0, 1.0)
	_cara.rotation = deg_to_rad(sin(_t * 45.0) * 3.0 * temblor)

	# La barra parpadea más clara cuando está casi llena
	if ro >= 0.8:
		var f := 0.5 + 0.5 * sin(_t * lerpf(8.0, 16.0, (ro - 0.8) / 0.2))
		_barra.modulate = Color.WHITE.lerp(Color(1.35, 1.1, 1.1), f)
	else:
		_barra.modulate = Color.WHITE


# Luz de patrulla: azul tranquila; desde 60% de ira alterna azul/rojo cada vez más rápido
func _actualizar_sirena() -> void:
	var ro := clampf(_ira_objetivo / ira_max, 0.0, 1.0)
	var col: Color
	if ro >= 0.6:
		var vel := lerpf(6.0, 14.0, (ro - 0.6) / 0.4)
		col = sirena_roja if sin(_t * vel) > 0.0 else sirena_azul
	else:
		col = sirena_azul.darkened(0.5).lerp(sirena_azul, 0.5 + 0.5 * sin(_t * 2.0))
	_estilo_sirena.bg_color = col
	_estilo_sirena.shadow_color = Color(col, 0.6)


# Contador de administrativos: amarillo; rojo parpadeante cuando quedan pocos
func _actualizar_admins() -> void:
	var col := color_admins
	if _admins != -1 and _admins <= admins_en_peligro:
		col = color_admins_peligro.lerp(Color.WHITE, 0.35 * (0.5 + 0.5 * sin(_t * 9.0)))
	_admin_numero.add_theme_color_override("font_color", col)


func _actualizar_ambiente(delta: float) -> void:
	if _mat == null or not ambiente_activo:
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


# Golpe al contador cuando baja un administrativo
func _pop_admin() -> void:
	if _tween_admin != null and _tween_admin.is_valid():
		_tween_admin.kill()
	_admin_numero.pivot_offset = _admin_numero.size / 2.0
	_admin_numero.scale = Vector2(1.5, 1.5)
	_tween_admin = create_tween()
	_tween_admin.tween_property(_admin_numero, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Mensaje grande (Cae la noche / Amanece): entra con rebote, se queda y se desvanece
func _mostrar_mensaje(texto: String) -> void:
	_mensaje.text = texto
	_mensaje.pivot_offset = _mensaje.size / 2.0
	if _tween_mensaje != null and _tween_mensaje.is_valid():
		_tween_mensaje.kill()
	_mensaje.modulate.a = 1.0
	_mensaje.scale = Vector2(0.6, 0.6)
	_tween_mensaje = create_tween()
	_tween_mensaje.tween_property(_mensaje, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_mensaje.tween_interval(1.8)
	_tween_mensaje.tween_property(_mensaje, "modulate:a", 0.0, 0.5)


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
