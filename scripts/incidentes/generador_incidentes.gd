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
@export var centro_mapa := Vector3.ZERO  # Centro aproximado de tu mapa
@export var radio_aparicion := 15.0     # Radio límite desde el centro del mapa

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
	
	# Obtener una posición central segura, libre de colisiones y cerca del centro del mapa
	var pos_central = obtener_posicion_central_segura(primero.global_position, segundo.global_position)
	
	# Añadir primero a la escena para que su global_position sea válida en el árbol
	add_child(incidente)
	incidente.global_position = pos_central
	
	# Inscribir a los peleadores usando el sistema del incidente
	incidente.inscribir_peleador(primero)
	incidente.inscribir_peleador(segundo)
	
	primero.add_to_group(GRUPO_PELEA)
	segundo.add_to_group(GRUPO_PELEA)
	
	activos += 1

func obtener_posicion_central_segura(pos1: Vector3, pos2: Vector3) -> Vector3:
	var punto_medio = (pos1 + pos2) / 2.0
	var objetivo_ideal = punto_medio.lerp(centro_mapa, 0.4)
	var space_state = get_tree().root.get_viewport().get_world_3d().direct_space_state
	
	for i in range(5):
		var offset_azar = Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0))
		var prueba_pos = objetivo_ideal + offset_azar
		
		if prueba_pos.distance_to(centro_mapa) > radio_aparicion:
			prueba_pos = centro_mapa + (prueba_pos - centro_mapa).normalized() * radio_aparicion
			
		var mapas = NavigationServer3D.get_maps()
		if not mapas.is_empty():
			var mapa = mapas[0]
			if mapa.is_valid():
				prueba_pos = NavigationServer3D.map_get_closest_point(mapa, prueba_pos)
		
		var query = PhysicsRayQueryParameters3D.create(
			prueba_pos + Vector3(0, 5.0, 0), 
			prueba_pos + Vector3(0, -5.0, 0)
		)
		var resultado = space_state.intersect_ray(query)
		
		if not resultado.is_empty():
			var punto_suelo = resultado.position
			if not hay_obstaculo_en(punto_suelo, space_state):
				return punto_suelo
				
	return objetivo_ideal

func hay_obstaculo_en(pos: Vector3, space_state) -> bool:
	var query = PhysicsShapeQueryParameters3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.6
	query.shape = shape
	query.transform = Transform3D(Basis(), pos + Vector3(0, 0.5, 0))
	var resultado = space_state.intersect_shape(query, 1)
	return not resultado.is_empty()

# === NOTA: Asegúrate de tener algo similar a esto en tu script de IncidentePresionado ===
# para que los curiosos se agrupen en un radio pequeño (ej. entre 1.5 y 3 metros):
# func obtener_puesto_curioso() -> Vector3:
#     var angulo = randf() * TAU
#     var distancia = randf_range(1.5, 3.0) # Radio pequeño y compacto
#     return global_position + Vector3(cos(angulo), 0, sin(angulo)) * distancia

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
	if is_instance_valid(incidente):
		for ciudadano in incidente.peleadores_activos():
			if is_instance_valid(ciudadano):
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
