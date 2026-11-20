class_name GeneradorIncidentes
extends Node

signal ira_cambio(valor: int)

const IRA_MAXIMA := 100
const IRA_ESCALADO := 8
const IRA_RESUELTO := 5
const RADIO_ROBO := 12.0
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

@export var escena_incidente: PackedScene
@export var puntos: Node3D
@export var maximo_activos := 8
## Desmarcalo para probar con UN solo jugador: solo salen incidentes que uno puede resolver solo
@export var modos_cooperativos := true
## Cada cuantos segundos aparece un ladron (si no hay uno activo)
@export var intervalo_robo := 30.0
## Segundos que tiene el ladron para escapar antes de que lo atrapen
@export var tiempo_huida := 20.0

var ira := 0
var ocupados := {}
var reloj_robo := 30.0
var ladron: Ciudadano = null

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
	var centro := Vector3.ZERO
	for j in jugadores:
		centro += (j as Node3D).global_position
	centro /= jugadores.size()
	var candidatos: Array[Ciudadano] = []
	for nodo in get_tree().get_nodes_in_group("ciudadanos"):
		var c := nodo as Ciudadano
		if c != null and c.disponible() and c.global_position.distance_to(centro) <= RADIO_ROBO:
			candidatos.append(c)
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
	var libres: Array[Node] = []
	for hijo in puntos.get_children():
		if not ocupados.has(hijo):
			libres.append(hijo)
	if libres.is_empty():
		return
	var elegido := libres.pick_random() as Node3D
	var incidente: IncidentePresionado = escena_incidente.instantiate()
	incidente.modo = elegir_modo()
	incidente.resuelto.connect(_on_incidente_resuelto)
	incidente.escalado.connect(_on_incidente_escalado)
	add_child(incidente)
	incidente.global_position = elegido.global_position
	ocupados[elegido] = incidente

func elegir_modo() -> IncidentePresionado.Modo:
	var modos: Array = MODOS_FACILES.duplicate()
	if ira >= IRA_DIFICIL:
		modos.append_array(MODOS_DIFICILES)
	if not modos_cooperativos:
		modos = modos.filter(func(m): return not MODOS_COOPERATIVOS.has(m))
	return modos.pick_random()

func limpiar_ocupados() -> void:
	for punto in ocupados.keys():
		var incidente = ocupados[punto]
		if not is_instance_valid(incidente) or incidente.is_queued_for_deletion():
			ocupados.erase(punto)

func _on_incidente_resuelto(_incidente: IncidentePresionado) -> void:
	cambiar_ira(-IRA_RESUELTO)

func _on_incidente_escalado(_incidente: IncidentePresionado) -> void:
	cambiar_ira(IRA_ESCALADO)

func cambiar_ira(cantidad: int) -> void:
	ira = clampi(ira + cantidad, 0, IRA_MAXIMA)
	ira_cambio.emit(ira)
	print("Ira: ", ira)
