class_name GeneradorIncidentes
extends Node

signal ira_cambio(valor: int)

const IRA_MAXIMA := 100
const IRA_ESCALADO := 8
const IRA_RESUELTO := 5
## El ladrón sale de entre los ciudadanos que estén a esta distancia (m) de algún policía
const RADIO_ROBO := 18.0
const IRA_DIFICIL := 40
const MODOS_FACILES := [
	IncidentePresionado.Modo.MANTENER,
	IncidentePresionado.Modo.ESPICHAR,
	IncidentePresionado.Modo.ALTERNAR,
]
const MODOS_DIFICILES := [
	IncidentePresionado.Modo.JUNTOS,
	IncidentePresionado.Modo.ESPICHAR_JUNTOS,
	IncidentePresionado.Modo.SECUENCIA,
]
# Estos modos necesitan a los DOS jugadores: con uno solo no avanzan
const MODOS_COOPERATIVOS := [
	IncidentePresionado.Modo.JUNTOS,
	IncidentePresionado.Modo.ESPICHAR_JUNTOS,
	IncidentePresionado.Modo.ALTERNAR,
	IncidentePresionado.Modo.SECUENCIA,
]
## Distancia mínima entre dos conflictos para que no se encimen
const DISTANCIA_ENTRE_INCIDENTES := 8.0

@export var escena_incidente: PackedScene
@export var puntos: Node3D
@export var maximo_activos := 8
## Desmarcalo para probar con UN solo jugador: solo salen incidentes que uno puede resolver solo
@export var modos_cooperativos := true
## Cada cuantos segundos aparece un ladron (si no hay uno activo)
@export var intervalo_robo := 30.0
## Segundos que tiene el ladron para escapar antes de que lo atrapen
@export var tiempo_huida := 20.0
@export_group("Conflictos espontáneos")
## Si está activo, el conflicto nace entre dos ciudadanos cercanos (de cualquier tipo, en cualquier
## parte del mapa). Si no encuentra pareja, usa los puntos fijos como antes.
@export var conflictos_espontaneos := true
## Distancia máxima entre los dos ciudadanos que se pelean
@export var distancia_pareja := 20.0

var ira := 0
var ocupados := {}
var reloj_robo := 30.0
var ladron: Ciudadano = null
var _contador := 0

func _process(delta: float) -> void:
	reloj_robo -= delta
	if reloj_robo > 0.0:
		return
	reloj_robo = intervalo_robo
	if is_instance_valid(ladron):
		return
	elegir_ladron()

func elegir_ladron() -> void:
	var jugadores := get_tree().get_nodes_in_group("jugador")
	if jugadores.is_empty():
		return
	var candidatos: Array[Ciudadano] = []
	for nodo in get_tree().get_nodes_in_group("ciudadanos"):
		var c := nodo as Ciudadano
		if c == null or not c.disponible():
			continue
		# Cerca de CUALQUIER policía (con el punto medio entre los dos podía no haber nadie)
		for j in jugadores:
			if c.global_position.distance_to((j as Node3D).global_position) <= RADIO_ROBO:
				candidatos.append(c)
				break
	if candidatos.is_empty():
		return
	ladron = candidatos.pick_random()
	ladron.ladron_atrapado.connect(_on_ladron_atrapado)
	ladron.ladron_escapo.connect(_on_ladron_escapo)
	ladron.volverse_ladron(tiempo_huida)

func _on_ladron_atrapado(_ciudadano: Ciudadano) -> void:
	cambiar_ira(-IRA_RESUELTO)

func _on_ladron_escapo(_ciudadano: Ciudadano) -> void:
	cambiar_ira(IRA_ESCALADO)

func _on_timer_timeout() -> void:
	limpiar_ocupados()
	if ocupados.size() >= maximo_activos:
		return
	# 1) Conflicto espontáneo entre dos ciudadanos libres cercanos
	if conflictos_espontaneos:
		var posicion := posicion_espontanea()
		if posicion != Vector3.INF:
			crear_incidente(posicion, _contador)
			_contador += 1
			return
	# 2) Si no hay pareja, usa los puntos fijos del mapa
	if puntos == null:
		return
	var libres: Array[Node] = []
	for hijo in puntos.get_children():
		if not ocupados.has(hijo):
			libres.append(hijo)
	if libres.is_empty():
		return
	var elegido := libres.pick_random() as Node3D
	crear_incidente(elegido.global_position, elegido)

## Corre el punto a la zona caminable más cercana: si cae dentro de un puesto o un edificio,
## los peleadores no pueden llegar y el incidente se cancela solo.
func sobre_malla(posicion: Vector3) -> Vector3:
	var mapa := get_viewport().find_world_3d().navigation_map
	if NavigationServer3D.map_get_regions(mapa).is_empty():
		return posicion
	var cercano := NavigationServer3D.map_get_closest_point(mapa, posicion)
	return Vector3(cercano.x, posicion.y, cercano.z)

func crear_incidente(posicion: Vector3, llave: Variant) -> void:
	posicion = sobre_malla(posicion)
	var incidente: IncidentePresionado = escena_incidente.instantiate()
	incidente.modo = elegir_modo()
	incidente.resuelto.connect(_on_incidente_resuelto)
	incidente.escalado.connect(_on_incidente_escalado)
	add_child(incidente)
	incidente.global_position = posicion
	ocupados[llave] = incidente

## Punto medio entre dos ciudadanos libres que están cerca entre sí (Vector3.INF si no hay)
func posicion_espontanea() -> Vector3:
	var libres: Array[Ciudadano] = []
	for nodo in get_tree().get_nodes_in_group("ciudadanos"):
		var c := nodo as Ciudadano
		if c != null and c.disponible():
			libres.append(c)
	if libres.size() < 2:
		return Vector3.INF
	libres.shuffle()
	for a in libres:
		var pareja: Ciudadano = null
		var menor := distancia_pareja
		for b in libres:
			if b == a:
				continue
			var d := a.global_position.distance_to(b.global_position)
			if d < menor:
				menor = d
				pareja = b
		if pareja == null:
			continue
		var medio := (a.global_position + pareja.global_position) * 0.5
		if lejos_de_incidentes(medio):
			return medio
	return Vector3.INF

func lejos_de_incidentes(posicion: Vector3) -> bool:
	for incidente in ocupados.values():
		if is_instance_valid(incidente) \
		and incidente.global_position.distance_to(posicion) < DISTANCIA_ENTRE_INCIDENTES:
			return false
	return true

func elegir_modo() -> IncidentePresionado.Modo:
	var modos: Array = MODOS_FACILES.duplicate()
	if ira >= IRA_DIFICIL:
		modos.append_array(MODOS_DIFICILES)
	if not modos_cooperativos:
		modos = modos.filter(func(m): return not MODOS_COOPERATIVOS.has(m))
	return modos.pick_random()

func limpiar_ocupados() -> void:
	for llave in ocupados.keys():
		var incidente = ocupados[llave]
		if not is_instance_valid(incidente) or incidente.is_queued_for_deletion():
			ocupados.erase(llave)

func _on_incidente_resuelto(_incidente: IncidentePresionado) -> void:
	cambiar_ira(-IRA_RESUELTO)

func _on_incidente_escalado(_incidente: IncidentePresionado) -> void:
	cambiar_ira(IRA_ESCALADO)

func cambiar_ira(cantidad: int) -> void:
	ira = clampi(ira + cantidad, 0, IRA_MAXIMA)
	ira_cambio.emit(ira)
	print("Ira: ", ira)
