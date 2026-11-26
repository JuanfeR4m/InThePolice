class_name GeneradorCiudadanos
extends Node

const GRUPO_CIUDADANOS := "ciudadanos"
const GRUPO_JUGADOR := "jugador"
const DISTANCIA_LIBRE := 1.5
const DISTANCIA_JUGADOR := 4.0
const INTENTOS := 15

const ANGULO_DORADO := 2.39996323
const RAPIDEZ_MIN := 1.5
const RAPIDEZ_MAX := 2.5

@export var escenas: Array[PackedScene]
@export var puntos: Node3D
@export var centro: Node3D
@export var objetivo: Node3D
@export var inicial := 25
@export var maximo := 30

@export var lado_feria := 13.0

var hay_malla := false
var creados := 0
var _alcanzable_cache := {}   # id del marcador -> ¿tiene camino hasta el centro de la feria?
var rumbo_base := randf() * TAU

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
	crear(ajustar_a_malla(mapa, punto.global_position), ajustar_a_malla(mapa, entrada_al_azar()))

func crear(posicion: Vector3, destino: Vector3) -> void:
	var ciudadano: Ciudadano = escenas.pick_random().instantiate()
	ciudadano.origen = centro.global_position
	ciudadano.centro_feria = centro.global_position
	ciudadano.limite_feria = lado_feria
	ciudadano.entrada = destino
	ciudadano.viene_de_afuera = true
	ciudadano.rapidez = randf_range(RAPIDEZ_MIN, RAPIDEZ_MAX)
	ciudadano.objetivo = objetivo
	ciudadano.rumbo = fmod(rumbo_base + creados * ANGULO_DORADO, TAU)
	creados += 1
	add_child(ciudadano)
	ciudadano.global_position = posicion

func ajustar_a_malla(mapa: RID, punto: Vector3) -> Vector3:
	if hay_malla:
		return NavigationServer3D.map_get_closest_point(mapa, punto)
	return punto

func posicion_inicial(mapa: RID) -> Vector3:
	for i in INTENTOS:
		var punto := centro.global_position + punto_en_feria()
		punto = ajustar_a_malla(mapa, punto)
		if esta_libre(punto) and es_alcanzable(mapa, punto):
			return punto
	return Vector3.INF

## ¿Hay camino desde `punto` hasta el centro de la feria? Descarta las islas aisladas de la malla:
## quien aparece en una isla no puede salir y se queda trabado para siempre.
func es_alcanzable(mapa: RID, punto: Vector3) -> bool:
	if not hay_malla:
		return true
	var meta := NavigationServer3D.map_get_closest_point(mapa, centro.global_position)
	var ruta := NavigationServer3D.map_get_path(mapa, punto, meta, true)
	if ruta.is_empty():
		return false
	var fin := ruta[ruta.size() - 1]
	return Vector2(fin.x - meta.x, fin.z - meta.z).length() < 2.0

func marcador_alcanzable(marcador: Node3D) -> bool:
	var id := marcador.get_instance_id()
	if not _alcanzable_cache.has(id):
		var mapa := centro.get_world_3d().navigation_map
		var ok := es_alcanzable(mapa, ajustar_a_malla(mapa, marcador.global_position))
		_alcanzable_cache[id] = ok
		if not ok:
			push_warning("%s cae en una isla aislada de la malla: no aparecerán ciudadanos ahí (muévelo)" % marcador.name)
	return _alcanzable_cache[id]

func esta_libre(punto: Vector3) -> bool:
	return not hay_cerca(punto, GRUPO_CIUDADANOS, DISTANCIA_LIBRE) \
		and not hay_cerca(punto, GRUPO_JUGADOR, DISTANCIA_JUGADOR)

func hay_cerca(punto: Vector3, grupo: String, distancia: float) -> bool:
	for nodo in get_tree().get_nodes_in_group(grupo):
		var otro := nodo as Node3D
		if otro != null and otro.global_position.distance_to(punto) < distancia:
			return true
	return false

func punto_en_feria() -> Vector3:
	return Vector3(randf_range(-lado_feria, lado_feria), 0.0, randf_range(-lado_feria, lado_feria))

func punto_libre() -> Node3D:
	var libres: Array[Node3D] = []
	for hijo in puntos.get_children():
		var punto := hijo as Node3D
		if punto != null and esta_libre(punto.global_position) and marcador_alcanzable(punto):
			libres.append(punto)
	if libres.is_empty():
		return null
	return libres.pick_random()

func entrada_al_azar() -> Vector3:
	return centro.global_position + punto_en_feria()
