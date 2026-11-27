class_name CiudadanoPeriodista
extends Ciudadano
## Sigue al policía y a los eventos a distancia, tomando fotos.
## Conecta la señal foto_tomada a tu sistema de reputación.

signal foto_tomada(posicion: Vector3)

@export var distancia_maxima := 6.0
@export var distancia_minima := 4.0
@export var intervalo_foto := 5.0

var _proxima_foto := 0.0
var _foco := Vector3.ZERO
var _foco_hasta := 0.0


func _comportamiento_idle() -> void:
	if _ahora() < _foco_hasta:
		_observar(_foco)
	else:
		_pasear()   # en busca de algo que fotografiar

func _reaccionar_al_jugador() -> void:
	_observar(jugador.global_position)

func reaccionar_a_evento(_evento: EventoTipo, punto_evento: Vector3) -> void:
	if _evento_cerca(punto_evento):
		_foco = punto_evento
		_foco_hasta = _ahora() + 8.0

func _observar(blanco: Vector3) -> void:
	estado = Estado.OBSERVANDO
	var dist := global_position.distance_to(blanco)
	if dist > distancia_maxima:
		mover_hacia(blanco, velocidad_correr * 0.6)
	elif dist < distancia_minima:
		huir_de(blanco, velocidad_caminar)
	else:
		mirar(blanco)
		if _ahora() >= _proxima_foto:
			_proxima_foto = _ahora() + intervalo_foto
			foto_tomada.emit(blanco)

func _animacion_por_estado() -> String:
	if estado == Estado.OBSERVANDO and _velocidad_horizontal() < 0.1:
		return "holding-both" # apuntando la cámara
	return ""
