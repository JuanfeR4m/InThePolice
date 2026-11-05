class_name LuzJugador
extends SpotLight3D

@export var rango := 5.0
@export var altura := 1.2

func _ready() -> void:
	
	position = Vector3(0.0, 0.5, -1.0)
	
	
	spot_range = rango
	spot_attenuation = 2.0
	
	print("taller 4", atenuacion(1.0), " ", atenuacion(2.0), " ", atenuacion(4.0))

static func atenuacion(d: float, exponente: float = 2.0) -> float:
	return 1.0 / pow(maxf(d, 0.0001), exponente)
