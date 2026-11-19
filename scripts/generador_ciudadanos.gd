class_name GeneradorCiudadanos
extends Node

const GRUPO_CIUDADANOS := "ciudadanos"
const GRUPO_JUGADOR := "jugador"
const DISTANCIA_LIBRE := 2.0
const DISTANCIA_JUGADOR := 4.0
const INTENTOS := 40
const TOLERANCIA_MALLA := 1.0
const TOLERANCIA_RELAJADA := 6.0
const RAPIDEZ_MIN := 1.5
const RAPIDEZ_MAX := 2.5
const FRAMES_ESPERA := 180

@export var escenas: Array[PackedScene]
@export var puntos: Node3D
@export var centro: Node3D
@export var objetivo: Node3D
@export var inicial := 25
@export var maximo := 35
@export var radio_entrada := 8.0
@export var area_inicial := Vector2(15.0, 15.0)
@export var radio_deambular := 10.0
## Cuántos ciudadanos nacen como administrativos (contorno verde, los que hay que defender)
@export var administrativos := 10

var marcados := 0
var rechazos := {"malla": 0, "lista": 0, "libre": 0}

func _ready() -> void:
	if escenas.is_empty() or centro == null:
		return
	var mapa := centro.get_world_3d().navigation_map
	# Al arrancar, el mapa de navegación tarda unos cuadros en incluir la malla
	# del NavigationRegion3D: se espera a que cubra la zona de aparición.
	for i in FRAMES_ESPERA:
		if malla_lista(mapa) and malla_cubre_zona(mapa):
			break
		await get_tree().physics_frame
	if not malla_lista(mapa):
		print("Sin malla de navegación: hornee el NavigationRegion3D")
	var usados: Array[Vector3] = []
	for i in inicial:
		var posicion := posicion_inicial(mapa, usados)
		if posicion != Vector3.INF:
			usados.append(posicion)
			crear(posicion, posicion)
	print("Ciudadanos iniciales: ", usados.size(), " de ", inicial)
	if usados.size() < inicial:
		diagnosticar(mapa)

func diagnosticar(mapa: RID) -> void:
	print("Rechazos -> lejos de la malla: ", rechazos["malla"],
		" | muy juntos entre sí: ", rechazos["lista"],
		" | ocupado por ciudadano/jugador: ", rechazos["libre"])
	if not malla_lista(mapa):
		print("Diagnóstico: el mapa de navegación está vacío o no sincronizó")
		return
	var c := centro.global_position
	var cercano := NavigationServer3D.map_get_closest_point(mapa, c)
	var d := Vector2(cercano.x, cercano.z).distance_to(Vector2(c.x, c.z))
	print("Diagnóstico: centro=", c, " | malla más cercana=", cercano,
		" | distancia plana=", snappedf(d, 0.1), " m")

func _on_timer_timeout() -> void:
	if escenas.is_empty() or puntos == null or centro == null:
		return
	if get_tree().get_nodes_in_group(GRUPO_CIUDADANOS).size() >= maximo:
		return
	var punto := punto_libre()
	if punto == null:
		return
	var mapa := centro.get_world_3d().navigation_map
	crear(ajustar_a_malla(mapa, punto.global_position), entrada_al_azar())

func crear(posicion: Vector3, destino: Vector3) -> void:
	var ciudadano = escenas.pick_random().instantiate()
	ciudadano.origen = centro.global_position
	ciudadano.entrada = destino
	ciudadano.viene_de_afuera = true
	ciudadano.rapidez = randf_range(RAPIDEZ_MIN, RAPIDEZ_MAX)
	ciudadano.radio_deambular = radio_deambular
	ciudadano.objetivo = objetivo
	if marcados < administrativos:
		ciudadano.es_administrativo = true
		marcados += 1
	add_child(ciudadano)
	ciudadano.global_position = posicion

func malla_lista(mapa: RID) -> bool:
	return NavigationServer3D.map_get_iteration_id(mapa) > 0 \
		and not NavigationServer3D.map_get_regions(mapa).is_empty()

func malla_cubre_zona(mapa: RID) -> bool:
	# Hay malla de verdad si un punto de la zona (fuera del centro) cae sobre ella
	var cubiertos := 0
	for desplazamiento in [Vector3(4, 0, 4), Vector3(-4, 0, 4), Vector3(4, 0, -4), Vector3(-4, 0, -4)]:
		var crudo: Vector3 = centro.global_position + desplazamiento
		var punto := NavigationServer3D.map_get_closest_point(mapa, crudo)
		if Vector2(punto.x, punto.z).distance_to(Vector2(crudo.x, crudo.z)) <= TOLERANCIA_MALLA:
			cubiertos += 1
	return cubiertos >= 2

func ajustar_a_malla(mapa: RID, punto: Vector3) -> Vector3:
	if malla_lista(mapa):
		return NavigationServer3D.map_get_closest_point(mapa, punto)
	return punto

func posicion_inicial(mapa: RID, usados: Array[Vector3]) -> Vector3:
	for nivel in 2:
		var tolerancia := TOLERANCIA_MALLA if nivel == 0 else TOLERANCIA_RELAJADA
		for i in INTENTOS:
			var crudo := centro.global_position + Vector3(
				randf_range(-area_inicial.x * 0.5, area_inicial.x * 0.5),
				0.0,
				randf_range(-area_inicial.y * 0.5, area_inicial.y * 0.5))
			var punto := ajustar_a_malla(mapa, crudo)
			if Vector2(punto.x, punto.z).distance_to(Vector2(crudo.x, crudo.z)) > tolerancia:
				rechazos["malla"] += 1
				continue
			if cerca_de_lista(punto, usados):
				rechazos["lista"] += 1
				continue
			if not esta_libre(punto):
				rechazos["libre"] += 1
				continue
			return punto
	return Vector3.INF

func cerca_de_lista(punto: Vector3, lista: Array[Vector3]) -> bool:
	for otro in lista:
		if otro.distance_to(punto) < DISTANCIA_LIBRE:
			return true
	return false

func esta_libre(punto: Vector3) -> bool:
	return not hay_cerca(punto, GRUPO_CIUDADANOS, DISTANCIA_LIBRE) \
		and not hay_cerca(punto, GRUPO_JUGADOR, DISTANCIA_JUGADOR)

func hay_cerca(punto: Vector3, grupo: String, distancia: float) -> bool:
	for nodo in get_tree().get_nodes_in_group(grupo):
		var otro := nodo as Node3D
		if otro != null and otro.global_position.distance_to(punto) < distancia:
			return true
	return false

func punto_en_circulo(radio: float) -> Vector3:
	var angulo := randf() * TAU
	var distancia := sqrt(randf()) * radio
	return Vector3(cos(angulo), 0.0, sin(angulo)) * distancia

func punto_libre() -> Node3D:
	var libres: Array[Node3D] = []
	for hijo in puntos.get_children():
		var punto := hijo as Node3D
		if punto != null and esta_libre(punto.global_position):
			libres.append(punto)
	if libres.is_empty():
		return null
	return libres.pick_random()

func entrada_al_azar() -> Vector3:
	return centro.global_position + punto_en_circulo(radio_entrada)
