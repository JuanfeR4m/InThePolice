extends Sprite2D
## Cronómetro animado para el HUD (Godot 4) con los números del tiempo en la esfera.
## Nodo: Sprite2D con cronometro_spritesheet_128.png, Hframes = 6, Vframes = 1.
## Frames 0-2 = azul (normal), frames 3-5 = rojo (alerta).
##
## Lee solo el tiempo restante del nodo del grupo "juego" (Juego.tiempo_restante).
## Si tu script de tiempo es otro, pon su ruta en "Origen" (necesita una variable
## "tiempo_restante" o "tiempo"), o llama a mano: $Cronometro.actualizar(segundos)

@export var segundos_para_alerta: float = 10.0  # cuándo se pone rojo
@export var velocidad: float = 0.16             # segundos por cuadro de animación
@export var tamano_texto: int = 18
@export var color_normal: Color = Color("#1d3b52")
@export var color_alerta: Color = Color("#8f1d1d")
@export var origen: NodePath                    # opcional: nodo que tiene el tiempo

# Centro de la esfera blanca en cada cuadro de la animación (respecto al centro del sprite)
const CENTROS = [Vector2(2.8, 12.2), Vector2(-4.1, 10.9), Vector2(-2.8, 12.3)]

var _t := 0.0
var _paso := 0
var alerta := false
var _texto: Label
var _fuente: Node = null
var _busqueda := 0.0


func _ready() -> void:
	_texto = Label.new()
	_texto.size = Vector2(60, 30)
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto.add_theme_font_size_override("font_size", tamano_texto)
	_texto.add_theme_color_override("font_color", color_normal)
	_texto.text = "--"
	add_child(_texto)
	_posicionar_texto()
	_fuente = _buscar_fuente()


func _process(delta: float) -> void:
	_t += delta
	if _t >= velocidad:
		_t = 0.0
		_paso = (_paso + 1) % 3
		frame = _paso + (3 if alerta else 0)
		_posicionar_texto()

	# Lee el tiempo de la partida automáticamente
	if _fuente == null or not is_instance_valid(_fuente):
		_busqueda -= delta
		if _busqueda <= 0.0:
			_busqueda = 0.5
			_fuente = _buscar_fuente()
		return
	if "tiempo_restante" in _fuente:
		actualizar(_fuente.tiempo_restante)
	elif "tiempo" in _fuente:
		actualizar(_fuente.tiempo)


## Llámala a mano si no quieres que lea el tiempo solo.
func actualizar(tiempo_restante: float) -> void:
	alerta = tiempo_restante <= segundos_para_alerta
	_texto.text = _formato(tiempo_restante)
	_texto.add_theme_color_override("font_color", color_alerta if alerta else color_normal)


func _formato(t: float) -> String:
	var s = int(ceil(maxf(t, 0.0)))
	if s >= 60:
		return "%d:%02d" % [floori(s / 60.0), s % 60]
	return str(s)


func _posicionar_texto() -> void:
	_texto.position = CENTROS[_paso] - _texto.size / 2.0


func _buscar_fuente() -> Node:
	if origen != NodePath(""):
		return get_node_or_null(origen)
	return get_tree().get_first_node_in_group("juego")
