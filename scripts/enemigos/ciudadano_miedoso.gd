class_name CiudadanoMiedoso
extends Ciudadano

@export var tiempo_panico := 5.0

var _fin_panico := 0.0


func _physics_process(delta: float) -> void:
	super(delta)
	if estado == Estado.HUYENDO and _ahora() > _fin_panico:
		estado = Estado.IDLE

func _reaccionar_al_jugador() -> void:
	_entrar_en_panico(jugador.global_position) # le teme hasta al policía

func reaccionar_a_evento(_evento: EventoTipo, punto_evento: Vector3) -> void:
	if _evento_cerca(punto_evento):
		_entrar_en_panico(punto_evento)

func _entrar_en_panico(punto_evento: Vector3) -> void:
	estado = Estado.HUYENDO
	_fin_panico = _ahora() + tiempo_panico
	huir_de(punto_evento, velocidad_correr * 1.2)

func _animacion_por_estado() -> String:
	return "sprint" if estado == Estado.HUYENDO else ""
