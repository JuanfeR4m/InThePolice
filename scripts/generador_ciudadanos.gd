class_name GeneradorCiudadanos
extends Node

const GRUPO_CIUDADANOS := "ciudadanos"
const GRUPO_JUGADOR := "jugador"
const DISTANCIA_LIBRE := 1.5
const DISTANCIA_JUGADOR := 4.0
const INTENTOS := 15
const RAPIDEZ_MIN := 1.5
const RAPIDEZ_MAX := 2.5

@export var escenas: Array[PackedScene]
@export var puntos: Node3D
@export var centro: Node3D
@export var objetivo: Node3D
@export var inicial := 25
@export var maximo := 30
@export var radio_entrada := 8.0
@export var radio_inicial := 15.0

var hay_malla := false

func _ready() -> void:
	if escenas.is_empty() or centro == null:
		return
	var mapa := centro.get_world_3d().navigation_map
	NavigationServer3D.map_force_update(mapa)
	hay_malla = not NavigationServer3D.map_get_regions(mapa).is_empty()
	if not hay_malla:
		print("Sin malla de navegación: hornee el NavigationRegion3D")
	for i in inicial:
		var posicion := posicion_inicial(mapa)
		if posicion != Vector3.INF:
			crear(posicion, posicion)

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
	var ciudadano: Ciudadano = escenas.pick_random().instantiate()
	ciudadano.origen = centro.global_position
	ciudadano.entrada = destino
	ciudadano.viene_de_afuera = true
	ciudadano.rapidez = randf_range(RAPIDEZ_MIN, RAPIDEZ_MAX)
	ciudadano.objetivo = objetivo
	add_child(ciudadano)
	ciudadano.global_position = posicion

func ajustar_a_malla(mapa: RID, punto: Vector3) -> Vector3:
	if hay_malla:
		return NavigationServer3D.map_get_closest_point(mapa, punto)
	return punto

func posicion_inicial(mapa: RID) -> Vector3:
	for i in INTENTOS:
		var punto := centro.global_position + punto_en_circulo(radio_inicial)
		punto = ajustar_a_malla(mapa, punto)
		if esta_libre(punto):
			return punto
	return Vector3.INF

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
