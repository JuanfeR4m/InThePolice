extends Node

@export var tecla = "interactuar1"
@export var alcance = 1.5
@onready var pj = get_parent()


@export var tiempo_necesario = 1.5
var progreso = 0.0
var actual = null
var agarrado: Ciudadano = null

func _physics_process(delta):
	if pj.desmayado:
		soltar()
		return
	if agarrado != null:
		llevar_agarrado()
		return
	var obj = mas_cercano()
	if not Input.is_action_pressed(tecla) or obj == null:
		progreso = 0.0
		actual = null
		intentar_agarrar()
		return
	if obj != actual:
		actual = obj
		progreso = 0.0
	var antes = progreso
	progreso += delta / tiempo_necesario
	if int(progreso * 4) > int(antes * 4) and progreso < 0.999:
		print(obj.name, ": ", int(progreso * 4) * 25, " %")
	if progreso >= 0.999:
		print("completado: ", obj.name)
		if obj.has_method("usar"):
			obj.usar()
		progreso = 0.0

func mas_cercano():
	var mejor = null
	for obj in get_tree().get_nodes_in_group("interactivos"):
		var d = distancia_a(obj)
		if d <= alcance and (mejor == null or d < distancia_a(mejor)):
			mejor = obj
	return mejor

func distancia_a(obj):
	var a = Vector2(pj.global_position.x, pj.global_position.z)
	var b = Vector2(obj.global_position.x, obj.global_position.z)
	return a.distance_to(b)

func intentar_agarrar():
	if not Input.is_action_pressed(tecla) or cerca_de_incidente() or companero_caido_cerca():
		return
	var c = ciudadano_mas_cercano()
	if c == null:
		return
	agarrado = c
	c.ser_agarrado(pj)
	pj.agarrando = true

func llevar_agarrado():
	if not Input.is_action_pressed(tecla) or cerca_de_incidente() \
			or not is_instance_valid(agarrado) or agarrado.agarrado_por != pj:
		soltar()

func soltar():
	if is_instance_valid(agarrado) and agarrado.agarrado_por == pj:
		agarrado.soltar()
	agarrado = null
	pj.agarrando = false

func ciudadano_mas_cercano():
	var mejor = null
	for nodo in get_tree().get_nodes_in_group("ciudadanos"):
		var c = nodo as Ciudadano
		if c == null or not c.puede_ser_agarrado():
			continue
		var d = distancia_a(c)
		if d <= alcance and (mejor == null or d < distancia_a(mejor)):
			mejor = c
	return mejor

func cerca_de_incidente():
	for inc in get_tree().get_nodes_in_group("incidentes"):
		var cerca = inc.jugador2_cerca if pj.sufijo == "2" else inc.jugador1_cerca
		if cerca:
			return true
	return false

func companero_caido_cerca():
	for nodo in get_tree().get_nodes_in_group("jugador"):
		if nodo != pj and nodo.desmayado and distancia_a(nodo) <= pj.RADIO_AYUDA:
			return true
	return false
