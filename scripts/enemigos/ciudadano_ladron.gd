class_name CiudadanoLadron
extends Ciudadano

@export var objetivo_robo: Node3D # otro ciudadano, tienda, etc.
@export var distancia_policia := 6.0

var _robando := false


func _comportamiento_idle() -> void:
	if not is_instance_valid(objetivo_robo):
		_robando = false
		objetivo_robo = _buscar_victima()
	if objetivo_robo == null:
		_pasear()
		return
	estado = Estado.ROBANDO
	mover_hacia(objetivo_robo.global_position, velocidad_caminar)
	if global_position.distance_to(objetivo_robo.global_position) < 1.0 and not _robando:
		_robando = true
		print("%s roba a %s" % [name, objetivo_robo.name]) # TODO: señal de robo

func _buscar_victima() -> Node3D:
	var candidatos: Array[Node3D] = []
	for nodo in get_tree().get_nodes_in_group("ciudadanos"):
		var otro := nodo as Node3D
		if otro != null and otro != self and not otro is CiudadanoLadron:
			candidatos.append(otro)
	if candidatos.is_empty():
		return null
	return candidatos.pick_random()

func _reaccionar_al_jugador() -> void:
	if global_position.distance_to(jugador.global_position) < distancia_policia:
		estado = Estado.HUYENDO
		huir_de(jugador.global_position, velocidad_correr)
	else:
		_comportamiento_idle()

func reaccionar_a_evento(evento: EventoTipo, punto_evento: Vector3) -> void:
	if (evento == EventoTipo.SIRENA or evento == EventoTipo.ARRESTO) and _evento_cerca(punto_evento):
		estado = Estado.HUYENDO
		huir_de(punto_evento, velocidad_correr)

func _animacion_por_estado() -> String:
	if estado == Estado.ROBANDO and _robando and _velocidad_horizontal() < 0.1:
		return "pick-up"
	return ""
