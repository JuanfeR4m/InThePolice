class_name GeneradorCiudadanos
extends Node

const GRUPO_CIUDADANOS := "ciudadanos"
const GRUPO_JUGADOR := "jugador"
const DISTANCIA_LIBRE := 1.5
const DISTANCIA_JUGADOR := 4.0
const INTENTOS := 15

## Cuánta gente de cada tipo sale (por nombre de escena): más peso = más seguido.
## De día hay mucho curioso y tonto (relleno gracioso) y casi no hay periodistas ni ladrones;
## de noche sube la gente rabiosa (borrachos, manifestantes, conflictivos).
const PESOS_DIA := {
	"ciudadano_curioso": 4.0, "ciudadano_tonto": 4.0, "ciudadano_borracho": 3.0,
	"ciudadano_miedoso": 3.0, "ciudadano_manifestante": 2.0, "ciudadano_conflictivo": 2.0,
	"ciudadano_ladron": 1.0, "ciudadano_periodista": 0.7,
}
const PESOS_NOCHE := {
	"ciudadano_curioso": 1.0, "ciudadano_tonto": 3.0, "ciudadano_borracho": 4.0,
	"ciudadano_miedoso": 2.0, "ciudadano_manifestante": 4.0, "ciudadano_conflictivo": 4.0,
	"ciudadano_ladron": 0.5, "ciudadano_periodista": 0.3,
}
## Máximo de ciudadanos de un tipo en la feria al mismo tiempo
const TOPE_POR_TIPO := {"ciudadano_periodista": 2, "ciudadano_ladron": 2}

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
	var ciudadano: Ciudadano = elegir_escena().instantiate()
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

## Elige el tipo de ciudadano según los pesos del día o de la noche, respetando los topes
func elegir_escena() -> PackedScene:
	var pesos: Dictionary = PESOS_NOCHE if es_de_noche() else PESOS_DIA
	var conteo := {}
	for nodo in get_tree().get_nodes_in_group(GRUPO_CIUDADANOS):
		var tipo := nodo.scene_file_path.get_file().get_basename()
		conteo[tipo] = int(conteo.get(tipo, 0)) + 1
	var pesos_validos: Array[float] = []
	var total := 0.0
	for e in escenas:
		var tipo := e.resource_path.get_file().get_basename()
		var peso: float = pesos.get(tipo, 1.0)
		if TOPE_POR_TIPO.has(tipo) and int(conteo.get(tipo, 0)) >= int(TOPE_POR_TIPO[tipo]):
			peso = 0.0
		pesos_validos.append(peso)
		total += peso
	if total <= 0.0:
		return escenas.pick_random()
	var tiro := randf() * total
	for i in escenas.size():
		tiro -= pesos_validos[i]
		if tiro <= 0.0 and pesos_validos[i] > 0.0:
			return escenas[i]
	return escenas.back()

## Misma regla de noche que GeneradorIncidentes (AmbienteNoche activo o poco tiempo en la Partida)
func es_de_noche() -> bool:
	var ambiente := get_tree().get_first_node_in_group("ambiente_noche")
	if ambiente != null and ambiente.get("activa") == true:
		return true
	var partida := get_tree().get_first_node_in_group("partida")
	if partida == null:
		return false
	var tiempo: float = partida.get("tiempo")
	var noche_en: float = partida.get("noche_en")
	return tiempo > 0.0 and tiempo < noche_en

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
