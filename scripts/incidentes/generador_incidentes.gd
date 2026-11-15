class_name GeneradorIncidentes
extends Node

signal ira_cambio(valor: int)

const IRA_MAXIMA := 100
const IRA_ESCALADO := 8
const IRA_RESUELTO := 5

@export var escena_incidente: PackedScene
@export var puntos: Node3D
@export var maximo_activos := 8

var ira := 0
var ocupados := {}

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
	incidente.resuelto.connect(_on_incidente_resuelto)
	incidente.escalado.connect(_on_incidente_escalado)
	add_child(incidente)
	incidente.global_position = elegido.global_position
	ocupados[elegido] = incidente

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
