extends Node

enum Estado { LISTA, ACTIVA, RECARGA }

@export var tecla = "fuerza"
@export var duracion = 0.4
@export var recarga = 3.0
@export var es_de_dia = true   # ya no se usa: ahora se pregunta a AmbienteNoche
@export var radio_patada = 2.5
@export var ira_por_patada = 15

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
	return pj.is_on_floor() and not pj.desmayado

func empezar():
	estado = Estado.ACTIVA
	tiempo = duracion
	pj.multiplicador = 0.0
	pj.accion = "attack-kick-right"
	_aplicar_patada()
	print("empieza: ", tecla)

func terminar():
	estado = Estado.RECARGA
	tiempo = recarga
	pj.multiplicador = 1.0
	pj.accion = ""
	print("termina: ", tecla)


## De noche: calma a los atacantes que estén cerca (defiende a los verdes).
## De día: patear a un ciudadano sube la Ira.
func _aplicar_patada():
	var ambiente = get_tree().get_first_node_in_group("ambiente_noche")
	var es_noche = ambiente != null and ambiente.get("activa") == true
	var pateo_a_alguien = false
	for nodo in get_tree().get_nodes_in_group("ciudadanos"):
		var c = nodo as Ciudadano
		if c == null or c.es_administrativo:
			continue
		var d = Vector2(c.global_position.x - pj.global_position.x,
				c.global_position.z - pj.global_position.z).length()
		if d > radio_patada:
			continue
		if es_noche:
			if c.es_atacante():
				c.calmar(pj)
		elif c.recibir_empujon(pj.global_position):
			pateo_a_alguien = true
	if pateo_a_alguien:
		marcado = true
		var generador = pj.get_parent().get_node_or_null("GeneradorIncidentes")
		if generador != null:
			generador.cambiar_ira(ira_por_patada)
