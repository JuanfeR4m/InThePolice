extends Node

enum Estado { LISTA, ACTIVA, RECARGA }

@export var tecla = "fuerza"
@export var duracion = 0.4
@export var recarga = 3.0
@export var es_de_dia = true

@onready var pj = get_parent()

var estado = Estado.LISTA
var tiempo = 0.0
var marcado = false

func _physics_process(delta):
	tiempo -= delta
	match estado:
		Estado.LISTA:
			if Input.is_action_just_pressed(tecla) and puede():
				empezar()
		Estado.ACTIVA:
			if tiempo <= 0.001:
				terminar()
		Estado.RECARGA:
			if tiempo <= 0.001:
				estado = Estado.LISTA

func puede():
	return pj.is_on_floor()

func empezar():
	estado = Estado.ACTIVA
	tiempo = duracion
	pj.multiplicador = 0.0
	pj.accion = "attack-kick-right"
	if es_de_dia:
		print("+15 de Ira")
		marcado = true
	print("empieza: ", tecla)

func terminar():
	estado = Estado.RECARGA
	tiempo = recarga
	pj.multiplicador = 1.0
	pj.accion = ""
	print("termina: ", tecla)
