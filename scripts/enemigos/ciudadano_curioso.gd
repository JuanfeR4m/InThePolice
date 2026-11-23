class_name CiudadanoCurioso
extends Ciudadano

@export var distancia_observar := 4.0


func _comportamiento_idle() -> void:
	estado = Estado.IDLE

func _reaccionar_al_jugador() -> void:
	estado = Estado.OBSERVANDO
	mirar(jugador.global_position)
	if global_position.distance_to(jugador.global_position) > distancia_observar:
		mover_hacia(jugador.global_position, velocidad_caminar)

func reaccionar_a_evento(_evento: EventoTipo, punto_evento: Vector3) -> void:
	if not _evento_cerca(punto_evento):
		return
	estado = Estado.OBSERVANDO
	mover_hacia(punto_evento, velocidad_caminar) # se acerca a mirar, no huye
