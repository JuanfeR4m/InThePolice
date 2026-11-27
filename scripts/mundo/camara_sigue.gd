extends Camera3D


@export var objetivos: Array[Node3D] = []
@export var direccion = Vector3(0, 9, 4)
@export var suavizado = 5.0

@export var limite_min = Vector2(-140, -140)
@export var limite_max = Vector2(140, 140)

@export var zoom_min = 1.0
@export var zoom_max = 5.0

@export_range(0.0, 0.5) var margen_pantalla = 0.18

@export var velocidad_alejar = 5.0
@export var velocidad_acercar = 1.5

var zoom_actual = 1.0
var foco_actual = Vector3.ZERO


func _ready():
	top_level = true
	if objetivos.is_empty():
		for nombre in ["Personaje", "Personaje2"]:
			var p = get_parent().get_node_or_null(nombre)
			if p is Node3D:
				objetivos.append(p)
	if objetivos.is_empty():
		push_warning("Camara: no se encontraron los jugadores")
		set_physics_process(false)
		return
	foco_actual = _limitar_foco(_calcular_foco())
	zoom_actual = _zoom_necesario(foco_actual)
	look_at_from_position(foco_actual + direccion * zoom_actual, foco_actual)


func _calcular_foco() -> Vector3:
	var suma = Vector3.ZERO
	var n = 0
	for o in objetivos:
		if o != null:
			suma += o.global_position
			n += 1
	return suma / n if n > 0 else Vector3.ZERO


func _limitar_foco(foco: Vector3) -> Vector3:
	foco.x = clamp(foco.x, limite_min.x, limite_max.x)
	foco.z = clamp(foco.z, limite_min.y, limite_max.y)
	return foco


func _en_pantalla(punto: Vector3, foco: Vector3, zoom: float) -> Vector2:
	var vista = Transform3D.IDENTITY.looking_at(-direccion, Vector3.UP)
	vista.origin = foco + direccion * zoom
	var local = vista.affine_inverse() * punto
	if local.z >= -0.01:
		return Vector2(INF, INF)
	var vp = get_viewport().get_visible_rect().size
	var aspecto = vp.x / vp.y
	var t = tan(deg_to_rad(fov) * 0.5)
	var prof = -local.z
	if keep_aspect == Camera3D.KEEP_WIDTH:
		return Vector2(local.x / prof / t, local.y / prof / t * aspecto)
	return Vector2(local.x / prof / (t * aspecto), local.y / prof / t)


func _caben_todos(foco: Vector3, zoom: float) -> bool:
	var limite = 1.0 - margen_pantalla
	for o in objetivos:
		if o == null:
			continue
		var p = _en_pantalla(o.global_position + Vector3(0, 1.0, 0), foco, zoom)
		if abs(p.x) > limite or abs(p.y) > limite:
			return false
	return true



func _zoom_necesario(foco: Vector3) -> float:
	if _caben_todos(foco, zoom_min):
		return zoom_min
	if not _caben_todos(foco, zoom_max):
		return zoom_max
	var bajo = zoom_min
	var alto = zoom_max
	for i in 14:
		var medio = (bajo + alto) * 0.5
		if _caben_todos(foco, medio):
			alto = medio
		else:
			bajo = medio
	return alto


func _physics_process(delta):
	var foco_objetivo = _limitar_foco(_calcular_foco())
	foco_actual = foco_actual.lerp(foco_objetivo, clamp(suavizado * delta, 0.0, 1.0))

	
	var zoom_objetivo = _zoom_necesario(foco_actual)
	var velocidad = velocidad_alejar if zoom_objetivo > zoom_actual else velocidad_acercar
	zoom_actual = lerp(zoom_actual, zoom_objetivo, clamp(velocidad * delta, 0.0, 1.0))

	if not _caben_todos(foco_actual, zoom_actual):
		zoom_actual = max(zoom_actual, zoom_objetivo)

	global_position = foco_actual + direccion * zoom_actual
