class_name CiudadanoTonto
extends Ciudadano

@export var tiempo_cambio_direccion := 2.0

var _direccion := Vector3.ZERO
var _proximo_cambio := 0.0


func _comportamiento_idle() -> void:
	if _ahora() >= _proximo_cambio:
		_proximo_cambio = _ahora() + randf_range(1.0, tiempo_cambio_direccion)
		_direccion = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	mover_hacia(global_position + _direccion, velocidad_caminar * 0.7)

func _reaccionar_al_jugador() -> void:
	_comportamiento_idle() # ignora al policía por completo

func _al_atascarse() -> void:
	super()
	_proximo_cambio = 0.0   # contra una pared: elige otra dirección ya

func reaccionar_a_evento(_evento: EventoTipo, punto_evento: Vector3) -> void:
	if randf() > 0.5:
		mover_hacia(punto_evento, velocidad_caminar) # se acerca al peligro sin entender
