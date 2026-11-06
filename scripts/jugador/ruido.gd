extends Node

@export var tecla = "hacer_ruido"
@export var radio = 8.0
@onready var pj = get_parent()

func _physics_process(_delta):
	if Input.is_action_just_pressed(tecla):
		sonar()

func sonar():
	var cuantos = 0
	for n in get_tree().get_nodes_in_group("oyentes"):
		if pj.global_position.distance_to(n.global_position) <= radio:
			n.oir(pj.global_position)
			cuantos += 1
	print("ruido de ", radio, "m: lo oyen ", cuantos)
