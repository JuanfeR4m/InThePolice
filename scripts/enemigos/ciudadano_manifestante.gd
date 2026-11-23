class_name CiudadanoManifestante
extends Ciudadano

@export var punto_protesta: Node3D
@export var radio_protesta := 3.0


func _comportamiento_idle() -> void:
	var punto := punto_protesta.global_position if punto_protesta != null else _ancla
	estado = Estado.PROTESTANDO
	if global_position.distance_to(punto) > radio_protesta:
		mover_hacia(punto, velocidad_caminar)

func _reaccionar_al_jugador() -> void:
	# No huye: se queda y encara al policía
	estado = Estado.PROTESTANDO
	mirar(jugador.global_position)

func reaccionar_a_evento(evento: EventoTipo, punto_evento: Vector3) -> void:
	if evento == EventoTipo.ARRESTO and _evento_cerca(punto_evento):
		mover_hacia(punto_evento, velocidad_caminar) # se agrupan contra el arresto

func _animacion_por_estado() -> String:
	if estado == Estado.PROTESTANDO and _velocidad_horizontal() < 0.1:
		return "holding-both" # sostiene la pancarta
	return ""
