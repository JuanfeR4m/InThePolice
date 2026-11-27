class_name CiudadanoBorracho
extends Ciudadano

@export var intensidad_tambaleo := 0.8
@export var tiempo_descanso := 4.0

var _direccion := Vector3.ZERO
var _proximo_cambio := 0.0
var _descansa_hasta := 0.0


func _comportamiento_idle() -> void:
	var ahora := _ahora()
	if ahora < _descansa_hasta:
		estado = Estado.IDLE # sentado en el piso
		return
	estado = Estado.CAMINANDO
	if ahora >= _proximo_cambio:
		_proximo_cambio = ahora + randf_range(2.0, 5.0)
		_direccion = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		if randf() < 0.25:
			_descansa_hasta = ahora + tiempo_descanso
	_tambalear(global_position + _direccion)

func _al_atascarse() -> void:
	super()
	_proximo_cambio = 0.0   # contra una pared: elige otra dirección ya

func _reaccionar_al_jugador() -> void:
	# Se acerca al policía a "conversar", sin entender nada
	estado = Estado.CAMINANDO
	if global_position.distance_to(jugador.global_position) > 2.5:
		_tambalear(jugador.global_position)
	else:
		mirar(jugador.global_position)

func reaccionar_a_evento(evento: EventoTipo, punto_evento: Vector3) -> void:
	# Solo le interesan las peleas
	if evento == EventoTipo.PELEA and _evento_cerca(punto_evento):
		_tambalear(punto_evento)

func _tambalear(destino: Vector3) -> void:
	var lado := global_transform.basis.x * sin(_ahora() * 3.0) * intensidad_tambaleo
	mover_hacia(destino + lado, velocidad_caminar * 0.6)

func _animacion_por_estado() -> String:
	if _ahora() < _descansa_hasta and _velocidad_horizontal() < 0.1:
		return "sit"
	return ""
