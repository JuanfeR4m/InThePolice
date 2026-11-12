class_name GeneradorIncidentes
extends Node

signal ira_cambio(valor: int)

const IRA_MAXIMA := 100
const IRA_ESCALADO := 8
const IRA_RESUELTO := 5
const GRUPO_CIUDADANOS := "ciudadanos"
const GRUPO_PELEA := "en_pelea"

@export var escena_incidente: PackedScene
@export var maximo_activos := 5

var ira := 0
var activos := 0

func _on_timer_timeout() -> void:
	if activos >= maximo_activos:
		return
	var libres := ciudadanos_libres()
	if libres.size() < 2:
		return
	var primero: Node3D = libres.pick_random()
	var segundo := mas_cercano(primero, libres)
	var incidente: IncidentePresionado = escena_incidente.instantiate()
	incidente.peleadores = [primero, segundo]
	incidente.resuelto.connect(_on_incidente_resuelto)
	incidente.escalado.connect(_on_incidente_escalado)
	primero.add_to_group(GRUPO_PELEA)
	segundo.add_to_group(GRUPO_PELEA)
	add_child(incidente)
	incidente.global_position = (primero.global_position + segundo.global_position) / 2.0
	activos += 1

func ciudadanos_libres() -> Array[Node3D]:
	var libres: Array[Node3D] = []
	for nodo in get_tree().get_nodes_in_group(GRUPO_CIUDADANOS):
		var ciudadano := nodo as Node3D
		if ciudadano != null and not ciudadano.is_in_group(GRUPO_PELEA):
			libres.append(ciudadano)
	return libres

func mas_cercano(origen: Node3D, lista: Array[Node3D]) -> Node3D:
	var elegido: Node3D = null
	var menor := INF
	for ciudadano in lista:
		if ciudadano == origen:
			continue
		var distancia := origen.global_position.distance_to(ciudadano.global_position)
		if distancia < menor:
			menor = distancia
			elegido = ciudadano
	return elegido

func liberar(incidente: IncidentePresionado) -> void:
	for ciudadano in incidente.peleadores:
		ciudadano.remove_from_group(GRUPO_PELEA)
	activos -= 1

func _on_incidente_resuelto(incidente: IncidentePresionado) -> void:
	liberar(incidente)
	cambiar_ira(-IRA_RESUELTO)

func _on_incidente_escalado(incidente: IncidentePresionado) -> void:
	liberar(incidente)
	cambiar_ira(IRA_ESCALADO)

func cambiar_ira(cantidad: int) -> void:
	ira = clampi(ira + cantidad, 0, IRA_MAXIMA)
	ira_cambio.emit(ira)
	print("Ira: ", ira)
