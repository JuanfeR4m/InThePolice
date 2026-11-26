extends CanvasLayer

signal terminada

const RUTA_SPRITESHEET = "res://assets/spritesheet_anochecer_horizontal_12x1.png"
const FRAMES = 12

@export var recursos: Array[String] = [
	"res://escenas/entorno/ambiente_noche.tscn",
	"res://shaders/contorno_defender.gdshader",
	"res://shaders/alerta.gdshader",
	"res://shaders/indicador.gdshader",
]
@export var segundo_activacion := 80.0
@export var duracion_transicion := 3.0
@export var pausar_juego := false
@export var capa := 100

var _raiz: Control
var _imagen: TextureRect
var _atlas: AtlasTexture = null
var _ancho_cuadro := 414.0
var _alto_cuadro := 308.0

var _tiempo_partida := 0.0
var _reloj_busqueda := 0.0
var _duracion_activa := 3.0
var _ultimo_tick_ms := 0
var _activa := false
var _ya_mostrada := false
var _terminando := false
var _progreso := 0.0
var _pausa_previa := false
var _pendientes: Array = []
var _cache := {}


func _ready() -> void:
	layer = capa
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir()
	_raiz.visible = false
	_preparar_recursos()


func _construir() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	_imagen = TextureRect.new()
	_imagen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_imagen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_raiz.add_child(_imagen)

	if ResourceLoader.exists(RUTA_SPRITESHEET):
		var tex: Texture2D = load(RUTA_SPRITESHEET)
		_ancho_cuadro = tex.get_width() / float(FRAMES)
		_alto_cuadro = float(tex.get_height())
		_atlas = AtlasTexture.new()
		_atlas.atlas = tex
		_atlas.region = Rect2(0.0, 0.0, _ancho_cuadro, _alto_cuadro)
		_imagen.texture = _atlas
	else:
		push_warning("PantallaNoche: falta " + RUTA_SPRITESHEET)


func _preparar_recursos() -> void:
	_pendientes.clear()
	for r in recursos:
		if ResourceLoader.exists(r) and not _cache.has(r):
			if ResourceLoader.load_threaded_request(r) == OK:
				_pendientes.append(r)


func _actualizar_carga_silenciosa() -> void:
	for r in _pendientes.duplicate():
		var estado = ResourceLoader.load_threaded_get_status(r)
		if estado == ResourceLoader.THREAD_LOAD_LOADED:
			_cache[r] = ResourceLoader.load_threaded_get(r)
			_pendientes.erase(r)
		elif estado != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			push_warning("PantallaNoche: no se pudo cargar " + r)
			_pendientes.erase(r)


func _process(delta: float) -> void:
	if not _pendientes.is_empty():
		_actualizar_carga_silenciosa()

	if _ya_mostrada and not _activa:
		return

	if not _activa:
		if not get_tree().paused:
			_tiempo_partida += delta
		if _debe_activarse(delta):
			mostrar(duracion_transicion)
		return

	if _terminando:
		return

	var ahora_ms := Time.get_ticks_msec()
	var dt := clampf((ahora_ms - _ultimo_tick_ms) / 1000.0, 0.0, 0.25)
	_ultimo_tick_ms = ahora_ms
	if dt <= 0.0:
		dt = clampf(delta, 0.0, 0.25)

	var dur := maxf(_duracion_activa, 3.0)
	_progreso = clampf(_progreso + (dt / dur), 0.0, 1.0)
	_actualizar_cuadro(_progreso)

	if _progreso >= 1.0:
		_terminar()


func _debe_activarse(delta: float) -> bool:
	if _ya_mostrada:
		return false

	_reloj_busqueda -= delta
	if _reloj_busqueda <= 0.0:
		_reloj_busqueda = 0.1
		var j = get_tree().get_first_node_in_group("juego")
		if j != null and "_t" in j:
			return float(j.get("_t")) >= segundo_activacion

	return _tiempo_partida >= segundo_activacion


func mostrar(duracion: float = 3.0) -> void:
	if _activa or _ya_mostrada:
		return
	_ya_mostrada = true
	_activa = true
	_terminando = false
	_progreso = 0.0
	_duracion_activa = maxf(duracion, 3.0)
	_ultimo_tick_ms = Time.get_ticks_msec()
	_pausa_previa = get_tree().paused
	if pausar_juego:
		get_tree().paused = true
	_actualizar_cuadro(0.0)
	_raiz.modulate.a = 0.0
	_raiz.visible = true

	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(_raiz, "modulate:a", 1.0, 0.25)


func _actualizar_cuadro(t: float) -> void:
	if _atlas == null:
		return
	var p := clampf(t, 0.0, 1.0)
	var idx := clampi(int(p * float(FRAMES)), 0, FRAMES - 1)
	_atlas.region = Rect2(float(idx) * _ancho_cuadro, 0.0, _ancho_cuadro, _alto_cuadro)


func _terminar() -> void:
	if _terminando:
		return
	_terminando = true
	_actualizar_cuadro(1.0)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_raiz, "modulate:a", 0.0, 0.45)
	tw.tween_callback(_cerrar)


func _cerrar() -> void:
	_raiz.visible = false
	_activa = false
	_terminando = false
	if pausar_juego:
		var menu = get_tree().get_first_node_in_group("menu_inicio")
		if menu != null and is_instance_valid(menu):
			get_tree().paused = true
		else:
			get_tree().paused = _pausa_previa
	terminada.emit()


func recurso(ruta: String):
	return _cache.get(ruta, null)
