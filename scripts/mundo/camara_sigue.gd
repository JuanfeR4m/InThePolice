extends Camera3D

@export var objetivos: Array[Node3D] = []
@export var direccion = Vector3(0, 9, 4)
@export var suavizado = 3.0

@export var limite_min = Vector2(-15, -15)
@export var limite_max = Vector2(15, 15)
@export var margen_vista = 1.0

@export var zoom_min = 1.0
@export var zoom_max = 2.2
@export var separacion_min = 6.0
@export var separacion_max = 30.0
@export var suavizado_zoom = 2.0

var zoom_actual = 1.0

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
	var foco = _calcular_foco()
	look_at_from_position(foco + direccion, foco)

func _calcular_foco() -> Vector3:
	var suma = Vector3.ZERO
	var n = 0
	for o in objetivos:
		if o != null:
			suma += o.global_position
			n += 1
	return suma / n if n > 0 else Vector3.ZERO

func _calcular_separacion() -> float:
	if objetivos.size() < 2 or objetivos[0] == null or objetivos[1] == null:
		return 0.0
	var a = objetivos[0].global_position
	var b = objetivos[1].global_position
	return Vector2(a.x - b.x, a.z - b.z).length()

func _extension_visible(zoom: float) -> Vector2:
	var dist = direccion.length() * zoom
	var mitad_alto = dist * tan(deg_to_rad(fov) * 0.5)
	var vp = get_viewport().get_visible_rect().size
	var aspecto = vp.x / vp.y
	var elevacion = atan2(direccion.y, Vector2(direccion.x, direccion.z).length())
	return Vector2(mitad_alto * aspecto, mitad_alto / sin(elevacion)) * margen_vista

func _zoom_tope() -> float:
	var ext1 = _extension_visible(1.0)
	var mitad_mapa = (limite_max - limite_min) * 0.5
	var tope = min(mitad_mapa.x / ext1.x, mitad_mapa.y / ext1.y)
	return max(tope, zoom_min)

func _physics_process(delta):
	var foco = _calcular_foco()

	var tope = _zoom_tope()
	var t = clamp(inverse_lerp(separacion_min, separacion_max, _calcular_separacion()), 0.0, 1.0)
	var zoom_objetivo = min(lerp(zoom_min, zoom_max, t), tope)
	zoom_actual = lerp(zoom_actual, zoom_objetivo, suavizado_zoom * delta)
	zoom_actual = min(zoom_actual, tope)

	var ext = _extension_visible(zoom_actual)
	var centro = (limite_min + limite_max) * 0.5

	var min_x = limite_min.x + ext.x
	var max_x = limite_max.x - ext.x
	foco.x = clamp(foco.x, min_x, max_x) if min_x <= max_x else centro.x

	var min_z = limite_min.y + ext.y
	var max_z = limite_max.y - ext.y
	foco.z = clamp(foco.z, min_z, max_z) if min_z <= max_z else centro.y

	var destino = foco + direccion * zoom_actual
	global_position = global_position.lerp(destino, suavizado * delta)
