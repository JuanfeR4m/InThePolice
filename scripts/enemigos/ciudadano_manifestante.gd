class_name CiudadanoManifestante
extends Ciudadano

@export var punto_protesta: Node3D
@export var radio_protesta := 3.0

var _puesto_protesta := Vector3.INF


func _comportamiento_idle() -> void:
	estado = Estado.PROTESTANDO
	if _puesto_protesta == Vector3.INF:
		if not _hay_malla():
			return
		# Cada manifestante toma su propio sitio alrededor del punto. Antes todos iban al mismo
		# centro y quedaban amontonados (los ciudadanos no chocan entre sí). `rumbo` ya viene
		# repartido por el generador.
		var centro := punto_protesta.global_position if punto_protesta != null else _ancla
		var r := radio_protesta * (0.4 + 0.6 * randf())
		_puesto_protesta = _sobre_malla(centro + Vector3(cos(rumbo), 0.0, sin(rumbo)) * r)
	if _distancia_plana(_puesto_protesta) > 0.8:
		mover_hacia(_puesto_protesta, velocidad_caminar)

func _al_atascarse() -> void:
	super()
	_puesto_protesta = Vector3.INF   # elige otro sitio

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
