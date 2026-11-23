extends Sprite2D
## Cronómetro dinámico del HUD (Godot 4).
## Nodo: Sprite2D con cronometro_spritesheet_128.png, Hframes = 6, Vframes = 1.
## Frames 0-2 = azul (normal), frames 3-5 = rojo (alerta).
##
## Con "tiempo_extra_al_final" activo (por defecto) y leyendo el nodo Juego:
##   - cuenta 3:00 -> 0:00 en azul (día + noche)
##   - después cuenta 15 -> 0 en ROJO (el amanecer, duracion_amanecer del Juego)
## Con "tiempo_extra_al_final" desactivado, hace una sola cuenta regresiva y se
## pone roja cuando faltan "segundos_para_alerta".
##
## Si tu script de tiempo es otro, pon su ruta en "Origen" (necesita una variable
## "tiempo_restante" o "tiempo"), o llama a mano: $Cronometro.actualizar(segundos)

const RUTA_FUENTE := "res://assets/fuentes/LilitaOne-Regular.woff2"

@export var tiempo_extra_al_final := true
@export var segundos_para_alerta := 15.0        # solo si tiempo_extra_al_final = false
@export var velocidad := 0.16                   # segundos por cuadro (normal)
@export var velocidad_alerta := 0.08            # segundos por cuadro (rojo)
@export var tamano_texto := 24
@export var fuente: Font                        # vacío = Lilita One (estilo Overcooked)
@export var color_normal := Color("#1d3b52")
@export var color_alerta := Color("#c4161c")
@export var temblor_ultimos_segundos := 5       # el reloj tiembla en los últimos N s rojos
@export var origen: NodePath                    # opcional: nodo que tiene el tiempo

# Centro de la esfera blanca en cada cuadro de la animación (respecto al centro del sprite)
const CENTROS = [Vector2(2.8, 12.2), Vector2(-4.1, 10.9), Vector2(-2.8, 12.3)]

var _t := 0.0
var _paso := 0
var alerta := false
var _texto: Label
var _fuente: Node = null
var _busqueda := 0.0
var _segundo := -1
var _escala_base := Vector2.ONE
var _tween: Tween


func _ready() -> void:
	_escala_base = scale
	if fuente == null and ResourceLoader.exists(RUTA_FUENTE):
		fuente = load(RUTA_FUENTE)

	_texto = Label.new()
	_texto.size = Vector2(70, 34)
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if fuente != null:
		_texto.add_theme_font_override("font", fuente)
	_texto.add_theme_font_size_override("font_size", tamano_texto)
	_texto.add_theme_color_override("font_color", color_normal)
	_texto.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.25))
	_texto.add_theme_constant_override("shadow_offset_x", 1)
	_texto.add_theme_constant_override("shadow_offset_y", 2)
	_texto.text = "--"
	add_child(_texto)
	_posicionar_texto()
	_fuente = _buscar_fuente()


func _process(delta: float) -> void:
	_t += delta
	if _t >= (velocidad_alerta if alerta else velocidad):
		_t = 0.0
		_paso = (_paso + 1) % 3
		frame = _paso + (3 if alerta else 0)
		_posicionar_texto()

	# Temblor de "se acaba": solo en los últimos segundos rojos
	if alerta and _segundo >= 0 and _segundo <= temblor_ultimos_segundos:
		offset = Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
	else:
		offset = Vector2.ZERO

	# Lee el tiempo de la partida automáticamente
	if _fuente == null or not is_instance_valid(_fuente):
		_busqueda -= delta
		if _busqueda <= 0.0:
			_busqueda = 0.5
			_fuente = _buscar_fuente()
		return
	_leer(_fuente)


func _leer(f: Node) -> void:
	var restante := 0.0
	if "tiempo_restante" in f:
		restante = f.tiempo_restante
	elif "tiempo" in f:
		restante = f.tiempo
	else:
		return

	var extra := 0.0
	if tiempo_extra_al_final and "duracion_amanecer" in f:
		extra = f.duracion_amanecer

	if extra > 0.0:
		if restante > extra:
			_aplicar(restante - extra, false)   # 3:00 -> 0:00 en azul
		else:
			_aplicar(restante, true)            # 15 -> 0 en rojo
	else:
		_aplicar(restante, restante <= segundos_para_alerta)


## Llámala a mano si no quieres que lea el tiempo solo.
func actualizar(tiempo_restante: float) -> void:
	_aplicar(tiempo_restante, tiempo_restante <= segundos_para_alerta)


func _aplicar(t: float, en_alerta: bool) -> void:
	var s := int(ceil(maxf(t, 0.0)))
	var cambio_alerta := en_alerta != alerta
	alerta = en_alerta
	_texto.text = _formato(s)
	_texto.add_theme_color_override("font_color", color_alerta if alerta else color_normal)

	if cambio_alerta:
		frame = _paso + (3 if alerta else 0)
		_golpe(1.35 if alerta else 1.1, 0.35)    # "pop" grande al ponerse rojo
	elif s != _segundo:
		_golpe(1.1 if alerta else 1.05, 0.18)    # latido cada segundo
	_segundo = s


# Escala el reloj de golpe y lo deja volver a su tamaño
func _golpe(factor: float, duracion: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	scale = _escala_base * factor
	_tween = create_tween()
	_tween.tween_property(self, "scale", _escala_base, duracion) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _formato(s: int) -> String:
	return "%d:%02d" % [floori(s / 60.0), s % 60]


func _posicionar_texto() -> void:
	_texto.position = CENTROS[_paso] - _texto.size / 2.0


func _buscar_fuente() -> Node:
	if origen != NodePath(""):
		return get_node_or_null(origen)
	return get_tree().get_first_node_in_group("juego")
