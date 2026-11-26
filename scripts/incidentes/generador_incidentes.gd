class_name GeneradorIncidentes
extends Node

signal ira_cambio(valor: int)

const IRA_MAXIMA := 100
const IRA_ESCALADO := 8
const IRA_RESUELTO := 5

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

const DISTANCIA_ENTRE_INCIDENTES := 8.0

@export var escena_incidente: PackedScene
@export var puntos: Node3D
@export var maximo_activos := 8

@export var modos_cooperativos := true

@export var intervalo_robo := 30.0

@export var tiempo_huida := 20.0
@export_group("Conflictos espontáneos")

@export var conflictos_espontaneos := true

@export var distancia_pareja := 20.0

@export_group("Ataque nocturno")

@export var intervalo_ataque_calmo := 7.0
@export var intervalo_ataque_furioso := 1.5
@export var atacantes_calmo := 1
@export var atacantes_furioso := 8

var ira := 0
var reloj_ataque := 4.0
var ocupados := {}
var reloj_robo := 30.0
var ladron: Ciudadano = null
var _contador := 0
var _era_noche := false


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


func procesar_ataques(delta: float) -> void:
	reloj_ataque -= delta
	if reloj_ataque > 0.0:
		return
	var furia := clampf(float(ira) / float(IRA_MAXIMA), 0.0, 1.0)
	reloj_ataque = lerpf(intervalo_ataque_calmo, intervalo_ataque_furioso, furia)
	var tope := roundi(lerpf(float(atacantes_calmo), float(atacantes_furioso), furia))
	var atacando := 0
	var candidatos: Array[Ciudadano] = []
	for nodo in get_tree().get_nodes_in_group("ciudadanos"):
		var c := nodo as Ciudadano
		if c == null:
			continue
		if c.es_atacante():
			atacando += 1
		elif c.puede_atacar():
			candidatos.append(c)
	if atacando >= tope or candidatos.is_empty():
		return
	var atacante: Ciudadano = candidatos.pick_random()
	var objetivo: Ciudadano = null
	var menor := INF
	for nodo in get_tree().get_nodes_in_group("administrativos"):
		var admin := nodo as Ciudadano
		if admin == null or admin.caido:
			continue
		var d := atacante.global_position.distance_to(admin.global_position)
		if d < menor:
			menor = d
			objetivo = admin
	if objetivo != null:
		atacante.atacar_administrativo(objetivo)


func cancelar_incidentes() -> void:
	for llave in ocupados.keys():
		var incidente = ocupados[llave]
		if is_instance_valid(incidente) and not incidente.is_queued_for_deletion():
			incidente.queue_free()
	ocupados.clear()

func _process(delta: float) -> void:
	
	var noche := es_de_noche()
	if noche and not _era_noche:
		cancelar_incidentes()
		reloj_ataque = 4.0
	_era_noche = noche
	if noche:
		procesar_ataques(delta)
		return
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
	if _era_noche:
		return
	limpiar_ocupados()
	if ocupados.size() >= maximo_activos:
		return

	if conflictos_espontaneos:
		var posicion := posicion_espontanea()
		if posicion != Vector3.INF:
			crear_incidente(posicion, _contador)
			_contador += 1
			return
	
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
