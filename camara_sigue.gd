extends Camera3D
@export var objetivo: Node3D
@export var distancia = Vector3(0, 12, 4)
@export var suavizado = 6.0
func _ready():
	top_level = true
	# Se orienta UNA vez, mirando al objetivo.
	look_at_from_position(objetivo.global_position + distancia,
	objetivo.global_position)
	
func _physics_process(delta):
	var destino = objetivo.global_position +distancia
	global_position = global_position.lerp(destino, suavizado * delta)
