class_name CiudadanoConflictivo
extends Ciudadano

@export var rango_ataque := 1.5
@export var cooldown_ataque := 2.0

var _proximo_ataque := 0.0


func _comportamiento_idle() -> void:
	_pasear()   # antes se quedaba quieto para siempre

func _reaccionar_al_jugador() -> void:
	estado = Estado.ATACANDO
	var dist := global_position.distance_to(jugador.global_position)
	if dist > rango_ataque:
		mover_hacia(jugador.global_position, velocidad_correr)
	else:
		mirar(jugador.global_position)
		if _ahora() >= _proximo_ataque:
			_proximo_ataque = _ahora() + cooldown_ataque
			_atacar()

func _atacar() -> void:
	print("%s ataca al jugador" % name) # TODO: daño al jugador

func reaccionar_a_evento(evento: EventoTipo, punto_evento: Vector3) -> void:
	if evento == EventoTipo.PELEA and _evento_cerca(punto_evento):
		mover_hacia(punto_evento, velocidad_correr) # se mete a la pelea

func _animacion_por_estado() -> String:
	if estado == Estado.ATACANDO and _velocidad_horizontal() < 0.1:
		return "attack-melee-right"
	return ""
