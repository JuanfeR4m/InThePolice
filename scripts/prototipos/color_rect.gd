extends ColorRect

@export var jugador: Node3D   # Arrastra aquí tu nodo Personaje (3D)
@export var ciudadano: Node3D # Arrastra aquí tu nodo ciudadano (3D)
@export var distancia_activacion: float = 12.0 # Distancia máxima para ver el destello

var tiempo := 0.0

func _process(delta: float) -> void:
	if not jugador or not ciudadano:
		modulate.a = 0.0
		return
	
	# Calculamos la distancia real en 3D entre el jugador y el ciudadano
	var distancia = jugador.global_position.distance_to(ciudadano.global_position)
	
	if distancia > distancia_activacion:
		# Si está lejos, el destello se queda quieto y apagado
		modulate.a = 0.0
		tiempo = 0.0
	else:
		# Si está cerca, se activa el efecto de destello
		tiempo += delta * 5.0
		modulate.a = (sin(tiempo) + 1.0) / 2.0 * 0.8 + 0.2
