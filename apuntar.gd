extends Node

@export var tecla = "disparar"
@export var alcance = 20.0
@onready var pj = get_parent()
var origen = Vector3.ZERO # de dónde sale el rayo

func _physics_process(delta):
	if Input.is_action_just_pressed(tecla):
		var golpe = lanzar_rayo()
		if golpe.is_empty():
			print("no le dio a nada en ", alcance, " m")
		else:
			var d = snappedf(origen.distance_to(golpe.position), 0.01)
			print("le dio a ", golpe.collider.name, " a ", d, " m")

func lanzar_rayo():
	origen = pj.global_position + Vector3(0, 0.8, 0)
	var hacia = origen - pj.global_basis.z * alcance
	var consulta = PhysicsRayQueryParameters3D.create(origen, hacia)
	consulta.exclude = [pj.get_rid()]
	return pj.get_world_3d().direct_space_state.intersect_ray(consulta)
