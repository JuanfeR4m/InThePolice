extends Node

enum Estado { LISTA, ACTIVA, RECARGA }

@export var tecla = "fuerza"
@export var duracion = 0.4
@export var recarga = 3.0
@export var es_de_dia = true   # ya no se usa: ahora se pregunta a AmbienteNoche
@export var radio_patada = 2.5
@export var ira_por_patada = 15
@export_group("Empujar a otros")
## De noche la patada también alcanza a los administrativos (les quita 1 golpe de vida)
@export var empujar_administrativos = true
## La patada también empuja al otro jugador (de día solo lo empuja; de noche además le quita vida)
@export var empujar_companero = true
@export var danio_empujon_noche = 1
@export var fuerza_empuje_companero = 9.0
@export var tiempo_empuje_companero = 0.8

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


## De noche: empuja a TODO el que esté cerca; cada empujón lo tumba y le resta vida.
## De día: patear a un ciudadano sube la Ira.
## En ambos casos empuja también al otro jugador si está cerca.
func _aplicar_patada():
	var ambiente = get_tree().get_first_node_in_group("ambiente_noche")
	var es_noche = ambiente != null and ambiente.get("activa") == true
	var pateo_a_alguien = false
	for nodo in get_tree().get_nodes_in_group("ciudadanos"):
		var c = nodo as Ciudadano
		if c == null:
			continue
		if c.es_administrativo and not (es_noche and empujar_administrativos):
			continue
		var d = Vector2(c.global_position.x - pj.global_position.x,
				c.global_position.z - pj.global_position.z).length()
		if d > radio_patada:
			continue
		if es_noche:
			# Cada patada tumba al ciudadano y le resta vida (ver ciudadano.recibir_empujon_nocturno)
			c.recibir_empujon_nocturno(pj.global_position)
		elif c.recibir_empujon(pj.global_position):
			pateo_a_alguien = true
	_empujar_companero(es_noche)
	if pateo_a_alguien:
		marcado = true
		var generador = pj.get_parent().get_node_or_null("GeneradorIncidentes")
		if generador != null:
			generador.cambiar_ira(ira_por_patada)


func _empujar_companero(es_noche):
	if not empujar_companero:
		return
	for nodo in get_tree().get_nodes_in_group("jugador"):
		var otro = nodo
		# El desmayado no se empuja: lo están reanimando
		if otro == pj or otro.desmayado:
			continue
		var d = Vector2(otro.global_position.x - pj.global_position.x,
				otro.global_position.z - pj.global_position.z).length()
		if d > radio_patada:
			continue
		var dir = otro.global_position - pj.global_position
		dir.y = 0.0
		otro.empujar(dir, fuerza_empuje_companero, tiempo_empuje_companero)
		if es_noche:
			var salud = otro.get_node_or_null("Salud")
			if salud != null:
				salud.recibir_golpe(danio_empujon_noche)
