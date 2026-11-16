extends Camera3D

@export var amplitud := 0.15
@export var velocidad := 0.6

var pos_inicial: Vector3
var t := 0.0

func _ready():
	pos_inicial = position

func _process(delta):
	t += delta * velocidad
	position = pos_inicial + Vector3(sin(t) * amplitud, cos(t * 0.7) * amplitud * 0.5, 0)
