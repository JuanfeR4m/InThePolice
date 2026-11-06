extends CharacterBody3D

@onready var anim = $Modelo/AnimationPlayer

func _ready():
	add_to_group("oyentes")

func _physics_process(delta):
	velocity += get_gravity() * delta
	anim.play("idle")
	move_and_slide()

func oir(punto):
	var d = global_position.distance_to(punto)
	print(name, " oyó algo a ", snappedf(d, 0.01), " m")
